import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/features/admin/presentation/screens/user_detail_screen.dart';
import 'package:intl/intl.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final AdminService _adminService = AdminService();
  List<RecordModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _adminService.getAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  void _showUserDetails(RecordModel user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserDetailScreen(user: user)),
    );
    if (result == true) {
      _loadUsers();
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
        title: const Text('Kayıtlı Kullanıcılar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Hiç kullanıcı bulunamadı.'))
              : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final pbName = user.getStringValue('full_name').isEmpty 
                        ? user.getStringValue('name') 
                        : user.getStringValue('full_name');
                    final username = pbName.isNotEmpty ? pbName : (user.getStringValue('username').isEmpty ? 'İsimsiz Kullanıcı' : user.getStringValue('username'));
                    final email = user.getStringValue('email');
                    final displayEmail = email.isNotEmpty ? email : 'Gizli (PocketBase)';
                    final created = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(user.created).toLocal());
                    final role = user.getStringValue('role') == '0' ? 'Yönetici' : 'Kullanıcı';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _showUserDetails(user),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade700,
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(username.isEmpty ? 'İsimsiz Kullanıcı' : username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayEmail, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            Text('Kayıt: $created', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: role == 'Yönetici' ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 10,
                              color: role == 'Yönetici' ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
