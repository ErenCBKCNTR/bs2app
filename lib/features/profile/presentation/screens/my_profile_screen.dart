import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:blind_social/features/update/presentation/screens/update_check_wrapper.dart';
import 'package:blind_social/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  RecordModel? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = PocketBaseService.client.authStore.model;
      if (user != null) {
        final data = await PocketBaseService.client.collection('users').getOne(user.id);
        if (mounted) {
          setState(() {
            _userData = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      bool isAuthInvalid = false;
      if (e is ClientException) {
        if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
          isAuthInvalid = true;
        }
      }

      if (isAuthInvalid) {
        // Oturum geçersizse (şifre değişmiş veya hesap silinmiş) direkt çıkış yap
        _signOut();
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil yüklenirken hata: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    PocketBaseService.client.authStore.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UpdateCheckWrapper(child: AuthWrapper())),
        (route) => false,
      );
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Bilinmiyor';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return 'Geçersiz Tarih';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profilim')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final username = _userData?.getStringValue('username') ?? 'Bilinmiyor';
    final fullName = _userData?.getStringValue('full_name') ?? 'Belirtilmemiş';
    final bio = _userData?.getStringValue('bio') ?? 'Henüz bir biyografi eklenmemiş.';
    final dob = _userData?.getStringValue('dob');
    final createdAt = _userData?.created;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            onPressed: () async {
              if (_userData != null) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(userData: _userData!),
                  ),
                );
                if (result == true) {
                  _fetchProfile(); // Refresh after edit
                }
              }
            },
            icon: const Icon(Icons.edit_outlined),
            tooltip: "Profili Düzenle",
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: "Çıkış Yap",
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Semantics(
                    label: "Profil fotoğrafınız",
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 40, color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fullName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@$username',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Hakkımda'),
                  _buildBioCard(bio),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Bilgiler'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildMiniInfoCard(Icons.cake_outlined, 'Doğum Tarihi', _formatDate(dob)),
                      _buildMiniInfoCard(Icons.calendar_today_outlined, 'Katılım', _formatDate(createdAt)),
                      _buildMiniInfoCard(Icons.email_outlined, 'E-posta', PocketBaseService.client.authStore.model?.getStringValue('email') ?? 'Yok'),
                      _buildMiniInfoCard(Icons.verified_user_outlined, 'Rol', 'Üye'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Hesaptan Çıkış Yap'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.red.withOpacity(0.2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildBioCard(String bio) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          bio,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildMiniInfoCard(IconData icon, String title, String value) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
