import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _checkWebOAuthRedirect();
    }
  }

  Future<void> _checkWebOAuthRedirect() async {
    final uri = Uri.base;
    if (uri.queryParameters.containsKey('code')) {
      final code = uri.queryParameters['code']!;
      
      final prefs = await SharedPreferences.getInstance();
      final verifier = prefs.getString('pb_oauth_code_verifier');
      final provider = prefs.getString('pb_oauth_provider');
      final redirectUri = prefs.getString('pb_oauth_redirect_uri');

      if (verifier != null && provider != null && redirectUri != null) {
        setState(() => _isLoading = true);
        try {
          final authData = await PocketBaseService.client.collection('users').authWithOAuth2Code(
            provider,
            code,
            verifier,
            redirectUri,
          );
          
          if (authData.meta != null && authData.record != null) {
            final currentFullName = authData.record!.getStringValue('full_name');
            if (currentFullName.isEmpty || authData.meta!['isNew'] == true) {
              String googleName = '';
              if (authData.meta!['name'] != null) {
                googleName = authData.meta!['name'] as String;
              } else if (authData.meta!['rawUser'] != null) {
                final raw = authData.meta!['rawUser'] as Map<String, dynamic>;
                googleName = raw['name'] ?? raw['given_name'] ?? '';
              }
              
              final userEmail = authData.record!.getStringValue('email').toLowerCase();
              final isDeveloperEmail = userEmail == 'erencs87@gmail.com';
              await PocketBaseService.client.collection('users').update(authData.record!.id, body: {
                'role': isDeveloperEmail ? 0 : 1,
                'full_name': googleName,
              });
              await PocketBaseService.client.collection('users').authRefresh();
            }
          }
          await NotificationService().syncWithServer();
          
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/');
          }
        } catch (e, stackTrace) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Teknik Hata Detayı'),
                content: SingleChildScrollView(
                  child: Text(
                    'Hata:\n$e\n\nStackTrace:\n$stackTrace',
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
          await prefs.remove('pb_oauth_code_verifier');
          await prefs.remove('pb_oauth_provider');
          await prefs.remove('pb_oauth_redirect_uri');
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

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
          // Kendi e-postanı admin yapmak için özel kural
          final isDeveloperEmail = email.toLowerCase() == 'erencs87@gmail.com';
          
          await PocketBaseService.client.collection('users').create(body: {
            'email': email,
            'password': password,
            'passwordConfirm': password,
            'role': isDeveloperEmail ? 0 : 1, // GELISIRICI ICIN ADMIN (0), DIGERLERI ICIN (1)
          });
          
          // Kayıt başarılıysa hemen giriş yap
          await PocketBaseService.client.collection('users').authWithPassword(email, password);
          
          // Kayıt sonrası bildirim token'ını güncelle
          await NotificationService().syncWithServer();
        } on ClientException catch (signUpError) {
          if (mounted) {
            String errorMessage = 'Kayıt sırasında bir hata oluştu.';
            if (signUpError.response.isNotEmpty && signUpError.response['data'] != null) {
              final data = signUpError.response['data'] as Map<String, dynamic>;
              final List<String> errors = [];
              if (data['email'] != null) {
                errors.add('E-posta: Geçerli bir e-posta adresi giriniz veya bu e-posta zaten kullanımda.');
              }
              if (data['password'] != null) {
                errors.add('Şifre: En az 8 karakter uzunluğunda olmalıdır.');
              }
              if (data['username'] != null) {
                errors.add('Kullanıcı Adı: Geçersiz veya kullanımda (en az 3 karakter boşluksuz).');
              }
              
              if (errors.isNotEmpty) {
                errorMessage = errors.join('\n');
              } else {
                errorMessage = signUpError.response['message'] ?? signUpError.toString();
              }
            } else {
              errorMessage = signUpError.response['message'] ?? signUpError.toString();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          String errorMessage = 'Giriş yapılamadı.';
          if (e.response.isNotEmpty && e.response['message'] != null) {
            if (e.response['message'].toString().contains('Failed to authenticate')) {
              errorMessage = 'E-posta adresi veya şifre hatalı.';
            } else {
              errorMessage = e.response['message'] ?? e.toString();
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 4),
            ),
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
      if (kIsWeb) {
        final response = await PocketBaseService.client.send('/api/collections/users/auth-methods', method: 'GET');
        final authProviders = response['authProviders'] as List<dynamic>? ?? [];
        final googleMap = authProviders.firstWhere(
          (p) => p['name'] == 'google',
          orElse: () => null,
        );

        if (googleMap == null) {
          throw Exception("Google auth provider'ı API'de bulunamadı. Lütfen PocketBase konsolunu kontrol edin.");
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_oauth_code_verifier', googleMap['codeVerifier'].toString());
        await prefs.setString('pb_oauth_provider', 'google');

        final uri = Uri.base;
        final redirectUri = uri.origin + (uri.path.isEmpty ? '/' : uri.path);
        
        // Eger https://cabukcan.com.tr/ Google Console'da ekli degilse redirect_uri_mismatch hatasi verir
        await prefs.setString('pb_oauth_redirect_uri', redirectUri);

        var rawAuthUrl = Uri.parse(googleMap['authUrl'].toString());
        final authUrl = rawAuthUrl.replace(queryParameters: {
          ...rawAuthUrl.queryParameters,
          'redirect_uri': redirectUri,
        });

        await launchUrl(authUrl, webOnlyWindowName: '_self');
        return;
      }

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
      io.HttpServer? server;
      try {
        // Android için Google Cloud Console'da yetkilendirilebilmesi adına SABİT bir port deniyoruz.
        server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 41325);
      } catch (e) {
        // Eğer 41325 portu meşgulse rastgele al (fakat bu port Google Console'da yoksa redirect_uri_mismatch verebilir)
        server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
      }
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
            window.close(); // Klasik kapatma komutu (genelde Android tarafindan bloklanir)
            var btn = document.querySelector('.btn');
            btn.innerText = "Kapatılıyor...";
            
            // ASIL COZUM: 
            // Cihazdaki Android Isletim Sistemine, "Custom Tab"in onunden kendi
            // uygulamamiza (blindsocial://auth) ziplamasi ve browser'i arkada ezmesi komutu:
            setTimeout(function() {
                 window.location.replace("blindsocial://auth");
            }, 50);
        }
        // 1 saniye sonra otomatik kapatmayi dene
        setTimeout(gizleVeKapat, 500);
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
      
      // url_launcher closeInAppWebView on Android custom tabs is notoriously broken
      // when no native app link or deep link catches it natively.
      // Eger custom tab kapanmazsa asagidaki islem yine de arka planda bitmis olacak
      try {
        closeInAppWebView();
      } catch (_) {}

      // Birkaç kez arka arkaya force kapatma gönder (Custom Tab workaround)
      for (var i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        try { closeInAppWebView(); } catch (_) {}
      }

      if (code == null) {
         throw Exception("Oturum acma iptal edildi veya basarisiz oldu.");
      }

      // Gelen code ile auth işlemini tamamla
      final authData = await PocketBaseService.client.collection('users').authWithOAuth2Code('google', code, codeVerifier, redirectUri);
      
      // authData.meta holds OAuth2 response from the provider, sometimes inside an inner 'rawUser' object
      if (authData.meta != null && authData.record != null) {
        // Pocketbase structure: meta['name'] or meta['rawUser']['name']
        final currentFullName = authData.record!.getStringValue('full_name');
        if (currentFullName.isEmpty) {
          
          String googleName = '';
          if (authData.meta!['name'] != null) {
            googleName = authData.meta!['name'] as String;
          } else if (authData.meta!['rawUser'] != null) {
            final raw = authData.meta!['rawUser'] as Map<String, dynamic>;
            googleName = raw['name'] ?? raw['given_name'] ?? '';
          }

          if (authData.meta!['isNew'] == true || currentFullName.isEmpty) {
            // Kendi e-postanı admin yapmak için özel kural
            final userEmail = authData.record!.getStringValue('email').toLowerCase();
            final isDeveloperEmail = userEmail == 'erencs87@gmail.com';

            await PocketBaseService.client.collection('users').update(authData.record!.id, body: {
               'role': isDeveloperEmail ? 0 : 1,
               'full_name': googleName,
            });
            await PocketBaseService.client.collection('users').authRefresh();
          }
        }
      }

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
              semanticsLabel: 'Kör Sosyal Ağına Hoş Geldiniz. Lütfen giriş yöntemi seçin.',
            ),
            const SizedBox(height: 32),
            Semantics(
              button: true,
              label: 'Google hesabınız ile hızlı giriş yapın veya kayıt olun.',
              child: OutlinedButton.icon(
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
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('veya e-posta ile', style: TextStyle(color: Colors.grey[600])),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            Semantics(
              label: 'E-posta adresinizi giriniz.',
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta Adresi',
                  hintText: 'ornek@eposta.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Şifrenizi giriniz. Eğer hesabınız yoksa belirleyeceğiniz şifre en az 8 karakter olmalıdır.',
              child: TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  hintText: 'En az 8 karakter',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _authenticate(),
              ),
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'Devam Et. Kayıtlı e-posta ise giriş yapar, değilse yeni hesap oluşturur.',
              button: true,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Devam Et'),
              ),
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
