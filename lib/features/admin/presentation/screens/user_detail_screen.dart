import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';

class UserDetailScreen extends StatefulWidget {
  final RecordModel user;
  
  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = false;

  void _confirmDeleteUser() {
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
              setState(() => _isLoading = true);
              try {
                await _adminService.deleteUserCascade(widget.user.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı ve verileri veritabanından silindi.')));
                  Navigator.pop(context, true); // go back and refresh
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silme hatası: $e')));
                }
              }
            },
            child: const Text('EVET, TAMAMEN SİL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18)),
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

    final pbName = widget.user.getStringValue('full_name').isEmpty 
        ? widget.user.getStringValue('name') 
        : widget.user.getStringValue('full_name');
    final actualUsername = widget.user.getStringValue('username').isEmpty 
        ? 'Belirtilmemiş'
        : widget.user.getStringValue('username');
    final displayName = pbName.isNotEmpty ? pbName : (actualUsername != 'Belirtilmemiş' ? actualUsername : 'Bilinmeyen Kullanıcı');
    
    final email = widget.user.getStringValue('email');
    final created = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(widget.user.created).toLocal());
    final lastIp = widget.user.getStringValue('last_ip');
    final lastLocation = widget.user.getStringValue('last_location');
    final role = widget.user.getStringValue('role') == '0' ? 'Yönetici' : 'Kullanıcı';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Detayları'),
      ),
      body: _isLoading 
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.account_circle, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              displayName, 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 32),
            _detailRow('Kullanıcı Adı:', actualUsername),
            _detailRow('E-Posta Adresi:', email.isEmpty ? 'Gizli (PocketBase Güvenlik Kuralları)' : email),
            _detailRow('Kayıt Tarihi:', created),
            _detailRow('Son IP Adresi:', lastIp.isEmpty ? 'Bilinmiyor' : lastIp),
            _detailRow('Son Konum:', lastLocation.isEmpty ? 'Bilinmiyor' : lastLocation),
            _detailRow('Kullanıcı Tipi:', role),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _confirmDeleteUser,
              icon: const Icon(Icons.delete_forever),
              label: const Text('KULLANICIYI SİL (TÜM VERİLER DAHİL)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      ),
    );
  }
}
