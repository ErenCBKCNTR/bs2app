import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_screen.dart';
import 'package:blind_social/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:blind_social/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:blind_social/core/services/security_service.dart';
import 'package:flutter/services.dart';
import 'package:blind_social/core/services/user_metadata_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isProfileComplete = false;
  bool _isDeviceCompromised = false;

  @override
  void initState() {
    super.initState();
    _performSecurityCheck();
  }

  Future<void> _performSecurityCheck() async {
    final isSecure = await SecurityService().isDeviceSecure();
    if (!isSecure) {
      if (mounted) {
        setState(() {
          _isDeviceCompromised = true;
          _isLoading = false;
        });
      }
      return;
    }
    
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
          UserMetadataService().updateMetadata();
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
      
      bool isAuthInvalid = false;
      if (e is ClientException) {
        // Eğer sunucudan 401 (Unauthorized), 403 (Forbidden) veya 404 (Not Found) alınırsa
        // kullanıcının hesabı silinmiş veya şifresi değiştirilmiştir.
        if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
          isAuthInvalid = true;
        }
      }

      if (isAuthInvalid) {
        PocketBaseService.client.authStore.clear();
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
            _isLoading = false;
          });
        }
        return;
      }

      // Hata durumunda (internet yoksayı vs) veya zaman aşımında oturum geçerli sayılsa bile 
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
    if (_isDeviceCompromised) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_update_warning, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Güvenlik İhlali Tespit Edildi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cihazınızda root/jailbreak veya bir hata ayıklayıcı tespit edildi. Blind Social verilerinizin güvenliği için modifiyeli cihazlarda çalışmayı reddeder.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => SystemNavigator.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('UYGULAMAYI KAPAT'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
