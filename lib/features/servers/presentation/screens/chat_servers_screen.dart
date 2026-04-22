import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
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
  UnsubscribeFunc? _unsub;

  @override
  void initState() {
    super.initState();
    _fetchServers();
    _setupSubscription();
  }

  @override
  void dispose() {
    _unsub?.call();
    super.dispose();
  }

  void _setupSubscription() async {
    _unsub = await ChatServerService().subscribeToServers((RecordSubscriptionEvent e) {
      if (e.action == 'create') {
        final newServer = ChatServer.fromRecord(e.record!);
        if (mounted) {
          setState(() {
            _servers.insert(0, newServer);
          });
        }
      } else if (e.action == 'delete') {
        if (mounted) {
          setState(() {
            _servers.removeWhere((s) => s.id == e.record!.id);
          });
        }
      } else if (e.action == 'update') {
        final updatedServer = ChatServer.fromRecord(e.record!);
        if (mounted) {
          setState(() {
            final index = _servers.indexWhere((s) => s.id == updatedServer.id);
            if (index != -1) {
              _servers[index] = updatedServer;
            }
          });
        }
      }
    });
  }

  Future<void> _fetchServers() async {
    try {
      final servers = await ChatServerService().getServers().timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _servers = servers;
          _cachedServers = servers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppLogger.instance.error('Sunucular yüklenirken hata: $e');
        setState(() => _isLoading = false);
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
                // Şifre kontrolü
                if (server.password != null && server.password!.isNotEmpty) {
                  final passwordConfirmed = await _showPasswordDialog(server.password!);
                  if (!passwordConfirmed) return;
                }

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

  Future<bool> _showPasswordDialog(String correctPassword) async {
    final passwordController = TextEditingController();
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sunucu Şifreli'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu sunucuya girmek için şifre gereklidir.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              if (passwordController.text.trim() == correctPassword) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hatalı şifre!')));
              }
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
