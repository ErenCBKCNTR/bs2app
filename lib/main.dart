import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Çevre değişkenlerini yükle
  await dotenv.load(fileName: ".env");
  
  // URL'deki sondaki '/' işaretini kaldır (varsa) ve ws url'sini manuel oluştur.
  // Port bug'ını çözmek için port içermeyen temiz url oluşturuyoruz.
  String url = dotenv.env['SUPABASE_URL']!;
  if(url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  
  // Http'yi ws'ye çevir: https:// -> wss:// veya http:// -> ws://
  String wsUrl = url.replaceFirst('http', 'ws');

  // Supabase'i başlat
  await Supabase.initialize(
    url: url,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    realtimeClientOptions: RealtimeClientOptions(
      eventsPerSecond: 10,
    ),
  );
  
  // Kritik Dokunuş: SDK'nın oluşturduğu yanlış portlu websocket URL'sini 
  // kendi oluşturduğumuz temiz wss:// adresimizle eziyoruz. 
  // Böylece :0 port hatasının etrafından dolanıyoruz!
  final client = Supabase.instance.client;
  (client.realtime as dynamic).restUrl = wsUrl; // Internal URI değerini eziyoruz

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
      home: const AuthWrapper(),
    );
  }
}
