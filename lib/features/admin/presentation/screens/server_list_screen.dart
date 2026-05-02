import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:intl/intl.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  final AdminService _adminService = AdminService();
  List<RecordModel> _servers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    final servers = await _adminService.getAllServers();
    if (mounted) {
      setState(() {
        _servers = servers;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_adminService.isAdmin()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erişim Engellendi')),
        body: const Center(child: Text('Bu sayfayı görüntülemek için yetkiniz yok.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıtlı Sunucular'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadServers,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _servers.isEmpty
              ? const Center(child: Text('Hiç sunucu bulunamadı.'))
              : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _servers.length,
                  itemBuilder: (context, index) {
                    final server = _servers[index];
                    final name = server.getStringValue('name');
                    final description = server.getStringValue('description');
                    final created = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(server.created).toLocal());
                    final roomId = server.getStringValue('room_id');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade700,
                          child: const Icon(Icons.dns, color: Colors.white),
                        ),
                        title: Text(name.isEmpty ? 'İsimsiz Sunucu' : name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            Text('Oluşturma: $created', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Text(
                          'ID: ${server.id.substring(0, 4)}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
