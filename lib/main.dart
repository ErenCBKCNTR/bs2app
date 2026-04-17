import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blind_social/core/providers/theme_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:blind_social/core/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Settings servislerini başlat
  await SettingsService().init();

  // Çevre değişkenlerini yükle
  await dotenv.load(fileName: ".env");
  
  // URL'deki sondaki '/' işaretini kaldır (varsa)
  String url = dotenv.env['SUPABASE_URL']!;
  if(url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }

  // Supabase'i başlat
  try {
    await Supabase.initialize(
      url: url,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  } catch (e) {
    debugPrint("Supabase başlatılamadı: $e");
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
