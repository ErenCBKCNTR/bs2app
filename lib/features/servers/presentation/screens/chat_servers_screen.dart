import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
    ChatServerService().cleanupGhostUsers();
    _fetchServers();
    _setupSubscription();
  }

  @override
  void dispose() {
    _unsub?.call();
    super.dispose();
  }

  void _setupSubscription() async {
    final sub = await ChatServerService().subscribeToServers((RecordSubscriptionEvent e) {
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
    if (!mounted) {
      sub.call();
      return;
    }
    _unsub = sub;
  }

  Future<void> _fetchServers() async {
    try {
      if (_servers.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedServersStr = prefs.getString('cached_chat_servers_list');
          if (cachedServersStr != null) {
            final List<dynamic> decoded = jsonDecode(cachedServersStr);
            if (mounted) {
              setState(() {
                _servers = decoded.map<ChatServer>((e) => ChatServer.fromJson(e as Map<String, dynamic>)).toList();
                _cachedServers = _servers;
                _isLoading = false;
              });
            }
          }
        } catch (e) {
          debugPrint('Sunucu önbelleği okuma hatası: $e');
        }
      }

      final servers = await ChatServerService().getServers().timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _servers = servers;
          _cachedServers = servers;
          _isLoading = false;
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          final encoded = jsonEncode(servers.map((e) => e.toJson()).toList());
          prefs.setString('cached_chat_servers_list', encoded);
        } catch (e) {
          debugPrint('Sunucu önbelleği yazma hatası: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        AppLogger.instance.error('Sunucular yüklenirken hata: $e');
        setState(() => _isLoading = false);
        if (_servers.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text('Lütfen internet bağlantınızı kontrol edin.'),
           ));
        }
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
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _servers.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, index) {
          final server = _servers[index];
          final serverName = ProfanityFilter.filter(server.name);
          final description = ProfanityFilter.filter(server.description.isEmpty ? 'Hoş geldiniz!' : server.description);
          final hasPassword = server.password != null && server.password!.isNotEmpty;
          final capacityStr = '${server.capacity}';
          final encryptedText = hasPassword ? 'şifreli ' : '';

          return FutureBuilder<int>(
            future: ChatServerService().getOnlineMemberCount(server.id),
            builder: (context, snapshot) {
              final onlineCount = snapshot.data ?? 0;
              final semanticLabel = 'Sunucu adı $serverName. Sunucu açıklaması $description. $capacityStr kişilik $encryptedText sunucu. Şu anda sunucuda $onlineCount kişi var.';

              return Semantics(
                label: semanticLabel,
                onTapHint: 'Sunucuya katılmak için çift tıklayın',
                excludeSemantics: true,
                button: true,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      try {
                        // Check if banned
                        final isBanned = await ChatServerService().isBanned(server.id);
                        if (isBanned) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu sunucuya giriş yapamazsınız. Sunucudan yasaklandınız.')));
                          }
                          return;
                        }

                        // Check capacity
                        if (onlineCount >= server.capacity) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu kapasitesi dolu, giriş yapılamaz.')));
                          }
                          return;
                        }

                        // Join if not a member, then navigate
                        final isMember = await ChatServerService().isMember(server.id);
                        if (!isMember) {
                          // Şifre kontrolü
                          if (server.password != null && server.password!.isNotEmpty) {
                            final passwordConfirmed = await _showPasswordDialog(server.password!);
                            if (!passwordConfirmed) return;
                          }

                          await ChatServerService().joinServer(server.id);
                        }
                        
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatServerRoomsScreen(server: server),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen internet bağlantınızı kontrol edin.')));
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: const Icon(Icons.dns, size: 20),
                              ),
                              if (hasPassword)
                                const Icon(Icons.lock, size: 18, color: Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            serverName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              description,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$onlineCount / $capacityStr',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
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
