import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';
import 'pocketbase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.instance.info("Background message received: ${message.messageId}");
  
  final notificationService = NotificationService();
  // Arka plan izolesinde yerel bildirim eklentisini hazırla
  await notificationService._initForBackground();
  
  final type = message.data['type'];
  if (type == 'call') {
    await notificationService.showCallNotification(
      message.data['title'] ?? 'Gelen Arama',
      message.data['body'] ?? 'Size bir çağrı var',
      message.data['chat_id'] ?? '',
    );
  } else {
    await notificationService._showLocalNotification(message);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> _initForBackground() async {
    if (_isInitialized) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _localNotificationsPlugin.initialize(initializationSettings);
    _isInitialized = true;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    
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
        // Bildirime veya butonlara (Cevapla/Reddet) tıklandığında yapılacak işlemler
        AppLogger.instance.info('Bildirime tıklandı. Action: ${response.actionId}, Payload: ${response.payload}');
        
        if (response.actionId == 'reject_call') {
          _localNotificationsPlugin.cancel(response.id ?? 0);
        }
      },
    );

    // Kanalları önceden oluştur (Ses ve öncelik ayarlarının geçerli olması için)
    final androidPlugin = _localNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'high_importance_channel_v3',
        'Mesaj Bildirimleri',
        description: 'Bu kanal üzerinden mesaj bildirimleri gelir.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));

      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'call_channel_v3',
        'Gelen Aramalar',
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
            'high_importance_channel_v3', // Kanal ID'yi yine değiştirelim ki ayarlar sıfırlansın
            'Mesaj Bildirimleri', 
            channelDescription: 'Bu kanal üzerinden mesaj bildirimleri gelir.',
            importance: Importance.max,
            priority: Priority.max,
            ticker: title,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
          ),
        ),
        payload: message.data['chat_id'] ?? message.data['type'],
      );
    }
  }

  // Arama bildirimi özel (daha yüksek öncelikli ve zilli)
  Future<void> showCallNotification(String title, String body, String chatId) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'call_channel_v3',
      'Gelen Aramalar',
      channelDescription: 'Gelen çağrılar için tam ekran bildirim kanalı',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      ticker: title,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept_call',
          'Cevapla',
          titleColor: Color.fromARGB(255, 76, 175, 80),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'reject_call',
          'Reddet',
          titleColor: Color.fromARGB(255, 244, 67, 54),
        ),
      ],
    );
    
    final NotificationDetails platformChannelSpecifics =
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
