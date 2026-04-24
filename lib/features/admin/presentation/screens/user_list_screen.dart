import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
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

  void _showUserDetails(RecordModel user) {
    final username = user.getStringValue('username').isEmpty 
        ? user.getStringValue('name') 
        : user.getStringValue('username');
    final email = user.getStringValue('email');
    final created = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(user.created).toLocal());
    final lastIp = user.getStringValue('last_ip');
    final lastLocation = user.getStringValue('last_location');
    final role = user.getStringValue('role') == '0' ? 'Yönetici' : 'Kullanıcı';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Kullanıcı Detayları', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _detailRow('İsim / Kullanıcı Adı:', username.isEmpty ? 'Belirtilmemiş' : username),
                _detailRow('E-Posta Adresi:', email),
                _detailRow('Kayıt Tarihi:', created),
                _detailRow('Son IP Adresi:', lastIp.isEmpty ? 'Bilinmiyor' : lastIp),
                _detailRow('Son Konum:', lastLocation.isEmpty ? 'Bilinmiyor' : lastLocation),
                _detailRow('Kullanıcı Tipi:', role),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _confirmDeleteUser(user),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('KULLANICIYI SİL (TÜM VERİLER DAHİL)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  void _confirmDeleteUser(RecordModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DİKKAT: Kullanıcıyı Sil'),
        content: const Text(
            'Bu kullanıcıyı silmek istediğinize emin misiniz?\n\n'
            'Bu işlem geri alınamaz. Kullanıcının kurduğu sunucular, attığı mesajlar, mikroblok gönderileri ve tüm veritabanı kayıtları tamamen silinecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İPTAL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close bottom sheet
              
              setState(() => _isLoading = true);
              try {
                await _adminService.deleteUserCascade(user.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı ve verileri veritabanından silindi.')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silme hatası: $e')));
                }
              }
              _loadUsers();
            },
            child: const Text('EVET, TAMAMEN SİL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                  padding: const EdgeInsets.all(8),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final username = user.getStringValue('username').isEmpty 
                        ? user.getStringValue('name') 
                        : user.getStringValue('username');
                    final email = user.getStringValue('email');
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
                            Text(email, style: const TextStyle(fontSize: 12)),
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
