import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/providers/theme_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:blind_social/core/services/settings_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:blind_social/core/services/notification_service.dart';

import 'package:blind_social/core/services/security_service.dart';

import 'package:blind_social/core/services/audio_cache_service.dart';

import 'package:blind_social/features/update/presentation/screens/update_check_wrapper.dart';

void main() async {
  // Global hata yakalayıcı (Framework hataları)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Flutter Error: ${details.exception}");
    AppLogger.instance.error("Flutter Error: ${details.exception}");
  };

  // UI Hata yakalayıcı (Kırmızı ekran yerine)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    "Uygulamada bir hata oluştu.",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exception.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Uygulamayı yeniden başlatmayı dene
                      PocketBaseService.client.authStore.clear();
                      SystemNavigator.pop();
                    },
                    child: const Text("ÇIKIŞ YAP VE KAPAT"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  WidgetsFlutterBinding.ensureInitialized();
  
  // Uygulamanın her zaman dikey modda çalışmasını sağlar
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  
  // Ekran korumasını başlat (Screenshot engelleme)
  await SecurityService().protectScreen();
  
  // Settings servislerini başlat
  try {
    await SettingsService().init();
  } catch (e) {
    debugPrint("Settings başlatılamadı: $e");
  }

  // Çevre değişkenlerini yükle
  try {
    await dotenv.load(fileName: "env.txt");
  } catch (e) {
    debugPrint(".env dosyası yüklenemedi: $e");
  }

  // PocketBase'i başlat
  try {
    await PocketBaseService.init();
  } catch (e) {
    debugPrint("PocketBase başlatılamadı: $e");
  }

  // App'i hemen başlat
  runApp(
    const ProviderScope(
      child: BlindSocialApp(),
    ),
  );

  // Arka planda Firebase ve bildirimleri başlat (UI'yı engellemeden)
  _initializeFirebase();
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCK9ayY6TUhFoZ32JkzSraldUAwSzY_Wdg",
        appId: "1:681771970848:web:6700bba826c4c43f23e745",
        messagingSenderId: "681771970848",
        projectId: "gen-lang-client-0566800967",
      ),
    );
    // Bildirim servisini başlat
    await NotificationService().init();
    
    // Uygulama zilseslerini önbelleğe al
    await AudioCacheService.initializeCache();
  } catch (e) {
    debugPrint("Firebase başlatılamadı: $e");
  }
}

class BlindSocialApp extends ConsumerWidget {
  const BlindSocialApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Blind Social',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075E54),
          brightness: Brightness.light,
          primary: const Color(0xFF075E54),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ),
        focusColor: Colors.black.withOpacity(0.3),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075E54), // WhatsApp Yeşili
          brightness: Brightness.dark,
          primary: const Color(0xFF25D366),
          surface: const Color(0xFF121B22),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        // Erişilebilirlik için yüksek kontrast ve odak yönetimi
        focusColor: Colors.white.withOpacity(0.3),
      ),
      home: const UpdateCheckWrapper(child: AuthWrapper()),
    );
  }
}
