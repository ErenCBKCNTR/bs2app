import 'package:flutter/material.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/admin/presentation/screens/user_list_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/server_list_screen.dart';
import 'package:blind_social/features/admin/presentation/screens/feedback_management_screen.dart';

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
                  _buildStatCard(
                    title: 'Toplam Kullanıcılar',
                    value: _stats['totalUsers'].toString(),
                    subtitle: 'Sistemdeki kayıtlı tüm kullanıcılar',
                    icon: Icons.group,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserListScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: 'Aktif Kullanıcılar',
                    value: _stats['activeUsers'].toString(),
                    subtitle: 'Son 15 dakika içinde aktif olanlar',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: 'Yeni Blog Gönderileri',
                    value: _stats['recentPosts'].toString(),
                    subtitle: 'Son 15 dakika içinde paylaşılanlar',
                    icon: Icons.article,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: 'Geri Bildirimler',
                    value: _stats['feedbackCount']?.toString() ?? '0',
                    subtitle: 'Kullanıcılardan gelen bildirimler',
                    icon: Icons.feedback_outlined,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FeedbackManagementScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    title: 'Toplam Sunucular',
                    value: _stats['totalServers'].toString(),
                    subtitle: 'Sistemdeki toplam sohbet sunucusu',
                    icon: Icons.dns,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ServerListScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Moderasyon Araçları',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Tüm Blog Gönderileri'),
                    subtitle: const Text('Gönderileri silmek için blog sayfasına gidin (Yönetici yetkisi ile silme aktiftir)'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Blog sayfasındaki herhangi bir gönderiyi artık silebilirsiniz.')),
                      );
                    },
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF232B2B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
