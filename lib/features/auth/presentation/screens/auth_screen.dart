import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/services/notification_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta ve şifrenizi girin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Önce giriş yapmayı dene
      await PocketBaseService.client.collection('users').authWithPassword(email, password);
      
      // Giriş başarılı, bildirim token'ını güncelle
      await NotificationService().syncWithServer();
    } on ClientException catch (e) {
      // Eğer kullanıcı bulunamadıysa (400 Bad Request) kayıt olmayı dene
      if (e.statusCode == 400 || e.statusCode == 404) {
        try {
          // PocketBase'de kayıt yaparken password ve passwordConfirm alanları zorunludur
          await PocketBaseService.client.collection('users').create(body: {
            'email': email,
            'password': password,
            'passwordConfirm': password,
          });
          
          // Kayıt başarılıysa hemen giriş yap
          await PocketBaseService.client.collection('users').authWithPassword(email, password);
          
          // Kayıt sonrası bildirim token'ını güncelle
          await NotificationService().syncWithServer();
        } on ClientException catch (signUpError) {
          if (mounted) {
            String errorMessage = signUpError.response['message'] ?? signUpError.toString();
            if (signUpError.response['data'] != null) {
               errorMessage += " Details: ${signUpError.response['data']}";
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kayıt hatası: $errorMessage')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Giriş hatası: ${e.response['message'] ?? e.toString()}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beklenmeyen bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _authenticateWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // Sunucu eski sürüm/yeni sürüm farkından dolayı listAuthMethods pas geçiliyor.
      // ignore: unused_local_variable
      final authData = await PocketBaseService.client.collection('users').authWithOAuth2(
        'google',
        (url) async {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
      );
      
      // Başarılı giriş sonrası bildirim token'ını güncelle
      await NotificationService().syncWithServer();
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (message.contains('missing provider google')) {
          message = "Google ile giriş şu anda sunucu tarafında aktif değil. Lütfen PocketBase Admin panelinden 'Auth Providers' sekmesinde Google'ı etkinleştirdiğinizden emin olun.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Tamam', onPressed: () {}),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giriş / Kayıt'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hoş Geldiniz',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              semanticsLabel: 'Kör Sosyal Ağına Hoş Geldiniz. Lütfen e-posta ve şifrenizi girin.',
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta Adresi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _authenticate(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _authenticate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Devam Et'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hesabınız yoksa otomatik olarak oluşturulacaktır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('veya', style: TextStyle(color: Colors.grey[600])),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _authenticateWithGoogle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white.withOpacity(0.05) 
                    : Colors.white,
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white24 
                      : Colors.grey,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Image.network(
                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                height: 24,
                width: 24,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.g_mobiledata, 
                  size: 24,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87,
                ),
              ),
              label: Text(
                'Google ile Devam Et',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87, 
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
