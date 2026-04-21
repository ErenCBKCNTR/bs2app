import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_screen.dart';
import 'package:blind_social/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:blind_social/features/chat/presentation/screens/chat_list_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isProfileComplete = false;

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
    _setupAuthListener();
  }

  void _checkInitialSession() {
    try {
      if (PocketBaseService.client.authStore.isValid) {
        final model = PocketBaseService.client.authStore.model;
        if (model != null) {
          _checkProfile(model.id);
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("AuthWrapper initial session check error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupAuthListener() {
    try {
      PocketBaseService.client.authStore.onChange.listen((e) {
        if (e.model != null && e.token.isNotEmpty) {
          _checkProfile(e.model.id);
        } else {
          if (mounted) {
            setState(() {
              _isAuthenticated = false;
              _isLoading = false;
            });
          }
        }
      }, onError: (err) {
        debugPrint("Auth listener error: $err");
      });
    } catch (e) {
      debugPrint("Auth listener setup error: $e");
    }
  }

  Future<void> _checkProfile(String userId) async {
    try {
      // 10 saniye içinde cevap gelmezse timeout olur ve catch'e düşer
      final record = await PocketBaseService.client.collection('users').getOne(userId).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          // Eğer kullanıcı veritabanında varsa ve dob alanı doluysa profil tamamlanmıştır
          final dob = record.getStringValue('dob');
          
          // Profil tamamlama şartı: Doğum tarihi dolu olmalı
          // PocketBase bazen boş tarih için default stringler döndürebilir
          bool isDobFilled = dob.isNotEmpty && 
                             dob != '0001-01-01 00:00:00Z' && 
                             dob != '0001-01-01 00:00:00';
          
          _isProfileComplete = isDobFilled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Profile check error or timeout: $e");
      // Hata durumunda veya zaman aşımında oturum geçerli sayılsa bile 
      // profil setup sayfasına yönlendirilebilir veya oturum geçersiz sayılabilir.
      // Burada kullanıcıyı bekletmemek için isLoading'i kapatıyoruz.
      if (mounted) {
        setState(() {
          // Eğer token geçerliyse ama profil çekilemiyorsa (internet vs), 
          // yine de listeye girmeyi deneyelim (fallback)
          _isAuthenticated = true; 
          _isProfileComplete = true; // Fallback: Hata varsa listeye girmeyi dene, orada hata verirse yenileriz
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Yükleniyor, lütfen bekleyin',
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const AuthScreen();
    }

    if (!_isProfileComplete) {
      return const ProfileSetupScreen();
    }

    return const ChatListScreen();
  }
}
