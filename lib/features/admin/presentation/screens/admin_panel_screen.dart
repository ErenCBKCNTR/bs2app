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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(builder: (context) => const ActiveUsersListScreen()),
                           );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.history, color: Colors.white, size: 32),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Son 24 Saatte Aktif Olanlar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Giriş yapan kullanıcıları listele',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(builder: (context) => const SendAnnouncementScreen()),
                           );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueGrey.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.campaign, color: Colors.white, size: 32),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tüm Kullanıcılara Duyuru',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Genel mesaj gönder',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: [
                          _buildStatCard(
                            title: 'Tüm Kullanıcılar',
                            value: _stats['totalUsers']?.toString() ?? '0',
                            subtitle: 'Kayıtlı hesaplar',
                            icon: Icons.group,
                            color: Colors.purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const UserListScreen()),
                              );
                            },
                          ),
                          _buildStatCard(
                            title: 'Geri Bildirimler',
                            value: _stats['feedbackCount']?.toString() ?? '0',
                            subtitle: 'Gelen mesajlar',
                            icon: Icons.feedback_outlined,
                            color: Colors.teal,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const FeedbackManagementScreen()),
                              );
                            },
                          ),
                          _buildStatCard(
                            title: 'Toplam Sunucular',
                            value: _stats['totalServers'].toString(),
                            subtitle: 'Aktif sunucular',
                            icon: Icons.dns,
                            color: Colors.orange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ServerListScreen()),
                              );
                            },
                          ),
                          _buildStatCard(
                            title: 'Kaynak Yönetimi',
                            value: _stats['totalSources']?.toString() ?? '0',
                            subtitle: 'Tarama Kaynakları',
                            icon: Icons.campaign,
                            color: Colors.red,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SourceManagementScreen()),
                              );
                            },
                          ),
                          _buildStatCard(
                            title: 'Oyun Alanı',
                            value: 'Yönetim',
                            subtitle: 'Oyun Ayarları',
                            icon: Icons.games,
                            color: Colors.green,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const GameManagementScreen()),
                              );
                            },
                          ),
                          _buildStatCard(
                            title: 'Sürüm Bilgisi',
                            value: 'Güncelle',
                            subtitle: 'Uygulama Sürümü',
                            icon: Icons.system_update_alt,
                            color: Colors.indigo,
                            onTap: () {
                              _showUpdateDialog(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Semantics(
      button: onTap != null,
      label: "$title istatistiği. Değer: $value. $subtitle",
      onTapHint: onTap != null ? "Detaylı listeyi görmek için çift dokunun" : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF232B2B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
