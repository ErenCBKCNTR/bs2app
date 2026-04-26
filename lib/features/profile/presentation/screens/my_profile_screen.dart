import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:blind_social/features/update/presentation/screens/update_check_wrapper.dart';
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
    final dob = _userData?.getStringValue('dob');
    final createdAt = _userData?.created;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: "Çıkış Yap",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 40, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '@$username',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('İsim Soyisim'),
              subtitle: Text(fullName),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Kullanıcı Adı'),
              subtitle: Text(username),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('E-posta'),
              subtitle: Text(PocketBaseService.client.authStore.model?.getStringValue('email') ?? 'Belirtilmemiş'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cake),
              title: const Text('Doğum Tarihi'),
              subtitle: Text(_formatDate(dob)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Katılım Tarihi'),
              subtitle: Text(_formatDate(createdAt)),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Hesaptan Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            )
          ],
        ),
      ),
    );
  }
}
