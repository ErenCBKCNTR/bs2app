import 'package:flutter/material.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/admin/presentation/screens/user_list_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/server_list_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/feedback_management_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/source_management_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/game_management_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/active_users_list_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/send_announcement_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    // Auto-promote/Fix admin role for developer emails if they are in admin panel
    await _adminService.checkAndFixAdminRole();
    
    final stats = await _adminService.getStats();
    if (mounted) {
      setState(() {
        _stats = stats;
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
        title: const Text('Yönetici Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'İstatistikleri Yenile',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildSectionHeader('Özet'),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              'Toplam Kullanıcı',
                              _stats['totalUsers']?.toString() ?? '0',
                              Icons.people,
                              Colors.blue,
                            ),
                            _buildSummaryCard(
                              'Geri Bildirim',
                              _stats['feedbackCount']?.toString() ?? '0',
                              Icons.feedback,
                              Colors.amber,
                            ),
                            _buildSummaryCard(
                              'Aktif Sunucular',
                              _stats['totalServers']?.toString() ?? '0',
                              Icons.dns,
                              Colors.purple,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Hızlı Aksiyonlar'),
                      _buildActionItem(
                        context,
                        title: 'Son 24 Saatte Aktif Olanlar',
                        subtitle: 'Giriş yapan kullanıcıları analiz edin',
                        icon: Icons.history,
                        gradient: const [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveUsersListScreen())),
                      ),
                      const SizedBox(height: 12),
                      _buildActionItem(
                        context,
                        title: 'Tüm Kullanıcılara Duyuru',
                        subtitle: 'Sistem geneli bilgilendirme mesajı gönder',
                        icon: Icons.campaign,
                        gradient: const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SendAnnouncementScreen())),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Yönetim'),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: [
                          _buildStatCard(
                            title: 'Kullanıcı Listesi',
                            value: 'Yönet',
                            subtitle: 'Profil & Yetki',
                            icon: Icons.group_outlined,
                            color: Colors.indigo,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen())),
                          ),
                          _buildStatCard(
                            title: 'Geri Bildirim',
                            value: 'İncele',
                            subtitle: 'Mesajları Oku',
                            icon: Icons.comment_bank_outlined,
                            color: Colors.teal,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackManagementScreen())),
                          ),
                          _buildStatCard(
                            title: 'Oyun Alanı',
                            value: 'Ayarlar',
                            subtitle: 'Oyun Listesi',
                            icon: Icons.sports_esports_outlined,
                            color: Colors.green,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GameManagementScreen())),
                          ),
                          _buildStatCard(
                            title: 'Sürüm Kontrol',
                            value: 'APK',
                            subtitle: 'Sürüm Güncelle',
                            icon: Icons.system_update_outlined,
                            color: Colors.orange,
                            onTap: () => _showUpdateDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: BorderSide(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: gradient.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showUpdateDialog(BuildContext context) async {
    final versionController = TextEditingController();
    final urlController = TextEditingController();
    
    // Fetch initial data
    try {
      final records = await PocketBaseService.client.collection('app_settings').getList(page: 1, perPage: 1);
      if (records.items.isNotEmpty) {
        versionController.text = records.items.first.getStringValue('current_version');
        urlController.text = records.items.first.getStringValue('apk_url');
      }
    } catch (e) {
      AppLogger.instance.error("App details fetch error: $e");
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sürüm Bilgisi ve Güncelleme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: versionController,
                decoration: const InputDecoration(labelText: 'Güncel Sürüm (Örn: 1.5.0)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'APK URL Linki'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final records = await PocketBaseService.client.collection('app_settings').getList(page: 1, perPage: 1);
                  final body = {
                    'current_version': versionController.text.trim(),
                    'apk_url': urlController.text.trim(),
                  };
                  if (records.items.isNotEmpty) {
                    await PocketBaseService.client.collection('app_settings').update(records.items.first.id, body: body);
                  } else {
                    await PocketBaseService.client.collection('app_settings').create(body: body);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sürüm güncellendi!')),
                    );
                  }
                } catch (e) {
                  AppLogger.instance.error("Update settings error: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: PocketBase ayarları güncellenemedi. Lütfen veritabanınızda app_settings adında bir koleksiyon oluşturun ve current_version ile apk_url alanlarının (text tipinde) olduğundan emin olun! Detay: $e'),
                        duration: const Duration(seconds: 8),
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }
}
