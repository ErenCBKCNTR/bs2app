import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _checkProfile(session.user.id);
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
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          // Eğer kullanıcı veritabanında varsa ve username ile dob alanları doluysa profil tamamlanmıştır
          _isProfileComplete = data != null && data['username'] != null && data['dob'] != null;
          _isLoading = false;
        });
      }
    } catch (e) {
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
