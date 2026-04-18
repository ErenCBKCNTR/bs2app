import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.instance.info("Background message received: ${message.messageId}");
  // Background mesajları için özel mantık buraya eklenebilir
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

    // FCM Token al (Backend'e kaydetmek için kullanılabilir)
    String? token = await FirebaseMessaging.instance.getToken();
    AppLogger.instance.info('FCM Token: $token');

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

    // Foreground mesaj dinleyicisi
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.instance.info('Foreground mesaj alındı: ${message.notification?.title}');
      _showLocalNotification(message);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && !kIsWeb) {
      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'Yüksek Öncelikli Bildirimler', // title
            channelDescription: 'Bu kanal üzerinden mesaj ve arama bildirimleri gelir.',
            importance: Importance.max,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
        ),
        payload: message.data['chat_id'],
      );
    }
  }

  // Arama bildirimi özel (daha yüksek öncelikli ve zilli)
  Future<void> showCallNotification(String title, String body, String chatId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'call_channel',
      'Aramalar',
      channelDescription: 'Gelen çağrılar için bildirim kanalı',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
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
