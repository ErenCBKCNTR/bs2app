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
    if (PocketBaseService.client.authStore.isValid) {
      _checkProfile(PocketBaseService.client.authStore.model.id);
    } else {
      _isLoading = false;
    }
  }

  void _setupAuthListener() {
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
    });
  }

  Future<void> _checkProfile(String userId) async {
    try {
      final record = await PocketBaseService.client.collection('users').getOne(userId);

      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          // Eğer kullanıcı veritabanında varsa ve dob alanı doluysa profil tamamlanmıştır
          final dob = record.getStringValue('dob');
          final username = record.getStringValue('username');
          
          // Profil tamamlama şartı: 
          // 1. Doğum tarihi dolu olmalı
          // 2. Kullanıcı adı PocketBase'in varsayılan "users_..." formatında olmamalı (opsiyonel ama sağlıklı)
          bool isDobFilled = dob.isNotEmpty && dob != '0001-01-01 00:00:00Z';
          bool isUsernameCustom = username.isNotEmpty && !username.startsWith('users_');
          
          _isProfileComplete = isDobFilled; // Kullanıcı özellikle doğum tarihi dediği için ona odaklanıyoruz
          _isLoading = false;
        });
      }
    } catch (e) {
      // Offline fallback or new account with no profile
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isProfileComplete = false;
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
