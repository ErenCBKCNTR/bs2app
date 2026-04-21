import 'package:flutter/material.dart';
import 'package:blind_social/features/servers/data/services/chat_server_service.dart';
import 'package:blind_social/features/servers/data/models/chat_server.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'dart:async';
import 'package:blind_social/core/utils/logger.dart';
import 'chat_server_rooms_screen.dart';

class ChatServersScreen extends StatefulWidget {
  const ChatServersScreen({super.key});

  @override
  State<ChatServersScreen> createState() => _ChatServersScreenState();
}

class _ChatServersScreenState extends State<ChatServersScreen> {
  static List<ChatServer>? _cachedServers;
  
  List<ChatServer> _servers = _cachedServers ?? [];
  bool _isLoading = _cachedServers == null;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchServers();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchServers(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchServers({bool isBackground = false}) async {
    try {
      final servers = await ChatServerService().getServers();
          
      if (mounted) {
        setState(() {
          _servers = servers;
          _cachedServers = servers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!isBackground) {
        AppLogger.instance.error('Sunucular yüklenirken hata: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_servers.isEmpty) {
      return const Center(
        child: SafeArea(
          child: Text(
            'Şu an aktif bir sohbet sunucusu bulunmuyor.\nYeni bir sunucu oluşturabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView.separated(
        itemCount: _servers.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final server = _servers[index];
          final serverName = ProfanityFilter.filter(server.name);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: const Icon(Icons.dns),
            ),
            title: Text(
              serverName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              ProfanityFilter.filter(server.description.isEmpty ? 'Hoş geldiniz!' : server.description),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('${server.capacity} Kişilik'),
            onTap: () async {
              // Join if not a member, then navigate
              final isMember = await ChatServerService().isMember(server.id);
              if (!isMember) {
                try {
                  await ChatServerService().joinServer(server.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Katılma hatası: $e')));
                  }
                  return;
                }
              }
              
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatServerRoomsScreen(server: server),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
