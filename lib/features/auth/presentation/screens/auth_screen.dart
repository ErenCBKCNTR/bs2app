import 'dart:io' as io;
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
      // SDK içindeki versiyon uyumsuzlukları ve 'missing provider' hatalarını aşmak için,
      // auth methodlarını PocketBase API'sine doğrudan manual istek atarak çekiyoruz.
      final response = await PocketBaseService.client.send('/api/collections/users/auth-methods', method: 'GET');
      
      final authProviders = response['authProviders'] as List<dynamic>? ?? [];
      final googleMap = authProviders.firstWhere(
        (p) => p['name'] == 'google',
        orElse: () => null,
      );

      if (googleMap == null) {
        throw Exception("Google auth provider'ı API'de bulunamadı. Lütfen PocketBase konsolunu kontrol edin.");
      }

      // Kendi yerel sunucumuzu başlatıyoruz (Yönlendirmeyi yakalamak için)
      final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
      final redirectUri = 'http://${server.address.host}:${server.port}/';

      var rawAuthUrl = Uri.parse(googleMap['authUrl'].toString());
      final authUrl = rawAuthUrl.replace(queryParameters: {
        ...rawAuthUrl.queryParameters,
        'redirect_uri': redirectUri,
      });

      final codeVerifier = googleMap['codeVerifier'].toString();

      // WebView veya inAppBrowserView ile uygulama içi küçük pencere olarak açıyoruz
      try {
        await launchUrl(authUrl, mode: LaunchMode.inAppBrowserView);
      } catch (e) {
        server.close();
        throw Exception("Google login sayfası tarayıcıda açılamadı. Hata: $e");
      }

      // Sunucuya gelen yönlendirmeyi bekle
      final request = await server.first;
      final code = request.uri.queryParameters['code'];
      
      try {
        final html = '''
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Giriş Başarılı</title>
    <style>
        body { background-color: #0f172a; color: #f8fafc; font-family: system-ui, -apple-system, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .container { text-align: center; padding: 32px; background: #1e293b; border-radius: 16px; border: 1px solid #334155; max-width: 80%; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1); }
        .icon { width: 64px; height: 64px; background: #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px auto; }
        .icon svg { width: 32px; height: 32px; color: white; }
        h2 { margin: 0 0 8px 0; font-size: 20px; font-weight: 600; }
        p { margin: 0 0 24px 0; color: #94a3b8; font-size: 14px; line-height: 1.5; }
        .btn { background: #3b82f6; color: white; border: none; padding: 12px 24px; border-radius: 8px; font-size: 16px; font-weight: 600; cursor: pointer; width: 100%; transition: background 0.2s; }
        .btn:active { background: #2563eb; }
        .btn:focus { outline: 3px solid #60a5fa; outline-offset: 2px; }
    </style>
</head>
<body aria-label="Giriş başarılı">
    <div class="container" role="main">
        <div class="icon" aria-hidden="true">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path></svg>
        </div>
        <h2>Giriş Başarılı!</h2>
        <p>Uygulamaya başarıyla bağlandınız.<br>Bu pencere otomatik kapanmazsa lütfen aşağıdaki butona tıklayın.</p>
        <button class="btn" aria-label="Pencereyi kapat ve devam et" onclick="gizleVeKapat()">Kapat ve Devam Et</button>
    </div>
    <script>
        function gizleVeKapat() {
            window.close();
            var btn = document.querySelector('.btn');
            btn.innerText = "Kapatılıyor...";
            // Eger window.close Android kaynakli calismazsa:
            setTimeout(function() {
                 btn.innerText = "Lütfen Ekranın Sol Üstündeki Çarpıya (X) Basın";
                 btn.style.background = "#ef4444";
            }, 1500);
        }
        // 1 saniye sonra otomatik kapatmayi dene
        setTimeout(function() {
            window.close();
        }, 1000);
    </script>
</body>
</html>
''';
        request.response
          ..statusCode = 200
          ..headers.contentType = io.ContentType.html
          ..write(html);
        await request.response.close();
      } catch (_) {}
      
      await server.close(force: true);
      
      // Biraz bekle (sayfa iyice render edilsin) ardından kapat komutunu ver. try-catch icine alinmistir hata firlatmamasi icin.
      await Future.delayed(const Duration(milliseconds: 1000));
      try {
        closeInAppWebView();
      } catch (_) {}

      if (code == null) {
         throw Exception("Oturum acma iptal edildi veya basarisiz oldu.");
      }

      // Gelen code ile auth işlemini tamamla
      await PocketBaseService.client.collection('users').authWithOAuth2Code('google', code, codeVerifier, redirectUri);
      
      // Başarılı giriş sonrası bildirim token'ını güncelle
      await NotificationService().syncWithServer();
    } catch (e, stackTrace) {
      if (mounted) {
        // Kullanıcı detaylı teknik hata görmek istediği için doğrudan dialog olarak basıyoruz
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Teknik Hata Detayı'),
            content: SingleChildScrollView(
              child: Text(
                'Hata:\\n$e\\n\\nStackTrace:\\n$stackTrace',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Kapat'),
              ),
            ],
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
