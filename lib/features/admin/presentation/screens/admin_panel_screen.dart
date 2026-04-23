import 'package:flutter/material.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/admin/presentation/screens/user_list_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/server_list_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/feedback_management_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/brand_management_screen.dart';

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                        value: _stats['totalUsers'].toString(),
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
                        title: 'Aktif Kullanıcılar',
                        value: _stats['activeUsers'].toString(),
                        subtitle: 'Son 15 dakika',
                        icon: Icons.people,
                        color: Colors.blue,
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
                        title: 'Kampanya Yönetimi',
                        value: 'BOT',
                        subtitle: 'Marka ve Kaynaklar',
                        icon: Icons.campaign,
                        color: Colors.red,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BrandManagementScreen()),
                          );
                        },
                      ),
                    ],
                  ),
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
}
