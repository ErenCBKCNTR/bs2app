import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/providers/theme_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:blind_social/core/services/settings_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:blind_social/core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlat (Web config'i kullanarak manuel initialization)
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
  } catch (e) {
    debugPrint("Firebase başlatılamadı: $e");
  }
  
  // Settings servislerini başlat
  await SettingsService().init();

  // Çevre değişkenlerini yükle
  await dotenv.load(fileName: ".env");

  // PocketBase'i başlat
  try {
    await PocketBaseService.init();
  } catch (e) {
    debugPrint("PocketBase başlatılamadı: $e");
  }

  runApp(
    const ProviderScope(
      child: BlindSocialApp(),
    ),
  );
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
      home: const AuthWrapper(),
    );
  }
}
