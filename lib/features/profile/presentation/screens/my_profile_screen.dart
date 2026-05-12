import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:blind_social/features/update/presentation/screens/update_check_wrapper.dart';
import 'package:blind_social/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/core/providers/localization_provider.dart';

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
    final lang = ref.read(localizationProvider);
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
          SnackBar(content: Text('${lang.profile} yüklenirken hata: $e')),
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
    final lang = ref.read(localizationProvider);
    if (isoString == null || isoString.isEmpty) return lang.unknown;
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return 'Geçersiz Tarih';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.myProfile)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final username = _userData?.getStringValue('username') ?? lang.unknown;
    final fullName = _userData?.getStringValue('full_name') ?? lang.notSpecified;
    final bio = _userData?.getStringValue('bio') ?? lang.noBio;
    final dob = _userData?.getStringValue('dob');
    final createdAt = _userData?.created;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.myProfile),
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
            tooltip: lang.editProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Profil Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    Theme.of(context).colorScheme.surface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Semantics(
                    label: lang.profilePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: username.isNotEmpty && username != lang.unknown
                          ? Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(fontSize: 36, color: Colors.black, fontWeight: FontWeight.bold),
                            )
                          : const Icon(Icons.person, size: 36, color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '@$username',
                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Hakkımda Section
            _buildSectionTitle(lang.bio),
            _buildBioCard(bio),
            const SizedBox(height: 16),

            // Bilgiler Section
            _buildSectionTitle(lang.personalInfo),
            Row(
              children: [
                Expanded(child: _buildMiniInfoCard(Icons.cake_outlined, lang.dob, _formatDate(dob), Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildMiniInfoCard(Icons.calendar_today_outlined, lang.joinedAt, _formatDate(createdAt), Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            _buildFullWidthInfoCard(Icons.email_outlined, lang.email, PocketBaseService.client.authStore.model?.getStringValue('email') ?? lang.notSpecified, Colors.amber),
            
            const SizedBox(height: 24),
            
            // Çıkış Yap Butonu
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: Text(lang.signOutAccount),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.08),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.red.withOpacity(0.2)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildBioCard(String bio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Text(
        bio,
        style: TextStyle(fontSize: 15, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9)),
      ),
    );
  }

  Widget _buildMiniInfoCard(IconData icon, String title, String value, Color accentColor) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthInfoCard(IconData icon, String title, String value, Color accentColor) {
    return MergeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
