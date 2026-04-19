import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/services/notification_service.dart';
import 'package:pocketbase/pocketbase.dart';

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
          ],
        ),
      ),
    );
  }
}
