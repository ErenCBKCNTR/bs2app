import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';
import 'pocketbase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.instance.info("Background message received: ${message.messageId}");
  
  // Eğer bu bir 'call' tipinde bir mesajsa veya normal bir mesajsa bildirimi göster
  final type = message.data['type'];
  final notificationService = NotificationService();
  
  if (type == 'call') {
    await notificationService.showCallNotification(
      message.data['title'] ?? 'Gelen Arama',
      message.data['body'] ?? 'Size bir çağrı var',
      message.data['chat_id'] ?? '',
    );
  } else {
    // Normal mesajlar için de arka planda bildirimi manuel tetikle (FCM bazen kısıtlayabiliyor)
    await notificationService._showLocalNotification(message);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Firebase Messaging altyapısını kur
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Bildirim izinlerini iste (iOS & Android 13+)
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      AppLogger.instance.info('Kullanıcı bildirim izinlerini verdi.');
    } else {
      AppLogger.instance.warning('Kullanıcı bildirim izinlerini reddetti.');
    }

    // Pil optimizasyonunu devre dışı bırakmayı iste (Arka plan bildirimleri için önemli)
    try {
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        // Doğrudan sistemi uyarmayı dene
        await Permission.ignoreBatteryOptimizations.request();
        
        // Eğer hala reddedilmişse ayarları açması için kullanıcıyı uyarabiliriz ama 
        // şu an için log atıp devam edelim.
        if (await Permission.ignoreBatteryOptimizations.isDenied) {
           AppLogger.instance.warning('Pil optimizasyon izni kullanıcı tarafından manuel reddedildi.');
        }
      }
    } catch (e) {
      AppLogger.instance.warning('Pil optimizasyon izni istenemedi: $e');
    }

    // Android 13+ bildirim izni (permission_handler ile ek kontrol)
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      AppLogger.instance.warning('Bildirim izni istenemedi: $e');
    }

    // FCM Token al ve sunucuya senkronize et
    _syncToken();

    // Token yenilendiğinde tekrar senkronize et
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _syncToken(token: newToken);
    });

    // Yerel bildirimleri ayarla
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Bildirime tıklandığında yapılacak işlemler
        AppLogger.instance.info('Bildirime tıklandı: ${response.payload}');
      },
    );

    // Kanalları önceden oluştur (Ses ve öncelik ayarlarının geçerli olması için)
    final androidPlugin = _localNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'high_importance_channel',
        'Yüksek Öncelikli Bildirimler',
        description: 'Bu kanal üzerinden mesaj ve arama bildirimleri gelir.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));

      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'call_channel_v2',
        'Aramalar',
        description: 'Gelen çağrılar için bildirim kanalı',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.instance.info('Foreground mesaj alındı: ${message.notification?.title}');
      _showLocalNotification(message);
    });
  }

  Future<void> syncWithServer() async {
    await _syncToken();
  }

  Future<void> _syncToken({String? token}) async {
    try {
      final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      
      AppLogger.instance.info('FCM Token senkronize ediliyor: $fcmToken');
      
      final authStore = PocketBaseService.client.authStore;
      if (authStore.isValid && authStore.model != null) {
        final userId = authStore.model.id;
        await PocketBaseService.client.collection('users').update(userId, body: {
          'fcm_token': fcmToken,
        });
        AppLogger.instance.info('FCM Token PocketBase sunucusuna başarıyla kaydedildi.');
      }
    } catch (e) {
      AppLogger.instance.error('FCM Token senkronizasyon hatası: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    
    // Eğer notification objesi yoksa data'daki title/body'yi kullan
    final title = notification?.title ?? message.data['title'] ?? 'Yeni Mesaj';
    final body = notification?.body ?? message.data['body'] ?? 'Size bir mesaj geldi';

    if (!kIsWeb) {
      await _localNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'Yüksek Öncelikli Bildirimler', // title
            channelDescription: 'Bu kanal üzerinden mesaj ve arama bildirimleri gelir.',
            importance: Importance.max,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: message.data['chat_id'] ?? message.data['type'],
      );
    }
  }

  // Arama bildirimi özel (daha yüksek öncelikli ve zilli)
  Future<void> showCallNotification(String title, String body, String chatId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'call_channel_v2', // Kanal ID değişti (sound ayarını zorlamak için)
      'Aramalar',
      channelDescription: 'Gelen çağrılar için bildirim kanalı',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: chatId,
    );
  }
}
