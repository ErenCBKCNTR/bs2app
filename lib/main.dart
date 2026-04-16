import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Çevre değişkenlerini yükle
  await dotenv.load(fileName: ".env");
  
  // Supabase'i başlat
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    const ProviderScope(
      child: BlindSocialApp(),
    ),
  );
}

class BlindSocialApp extends StatelessWidget {
  const BlindSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blind Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      home: const ChatListScreen(),
    );
  }
}
