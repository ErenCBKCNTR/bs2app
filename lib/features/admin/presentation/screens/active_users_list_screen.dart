import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';

class ActiveUsersListScreen extends StatefulWidget {
  const ActiveUsersListScreen({super.key});

  @override
  State<ActiveUsersListScreen> createState() => _ActiveUsersListScreenState();
}

class _ActiveUsersListScreenState extends State<ActiveUsersListScreen> {
  final List<RecordModel> _users = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadActiveUsers();
  }

  Future<void> _loadActiveUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24)).toUtc().toIso8601String().replaceFirst('T', ' '); 
      
      // We will order by last_seen
      final records = await PocketBaseService.client.collection('users').getList(
        page: 1,
        perPage: 100,
        sort: '-last_seen,-updated',
        filter: 'last_seen >= "$last24Hours" || is_online = true',
      );

      if (mounted) {
        setState(() {
          _users.addAll(records.items);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kullanıcılar yüklenirken bir hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Son 24 Satte Aktif Olanlar'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? Center(child: Text(_error))
                : _users.isEmpty
                    ? const Center(child: Text('Son 24 saat içinde aktif olan kullanıcı bulunamadı.'))
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final username = user.getStringValue('username');
                          final email = user.getStringValue('email');
                          final isOnline = user.getBoolValue('is_online');
                          final lastSeenRaw = user.getStringValue('last_seen');
                          
                          String lastSeenText = "Bilinmiyor";
                          if (isOnline) {
                            lastSeenText = "Şu an aktif";
                          } else if (lastSeenRaw.isNotEmpty) {
                            try {
                              final lastSeenDate = DateTime.parse(lastSeenRaw).toLocal();
                              lastSeenText = DateFormat('dd.MM.yyyy HH:mm').format(lastSeenDate);
                            } catch (_) {}
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isOnline ? Colors.green : Colors.grey,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(username.isNotEmpty ? username : 'İsimsiz'),
                              subtitle: Text(email.isNotEmpty ? email : 'E-posta yok'),
                              trailing: Text(
                                lastSeenText,
                                style: TextStyle(
                                  color: isOnline ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
