import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;

    // تهيئة الإشعارات المحلية
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    // ✅ إنشاء القناة
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ✅ تعامل آمن مع FCM
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission();
      print('🔔 إذن الإشعارات: ${settings.authorizationStatus}');

      final token = await _firebaseMessaging.getToken();
      print('🔑 FCM Token: $token');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(
          title: message.notification?.title ?? 'إشعار',
          body: message.notification?.body ?? '',
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📬 تم فتح الإشعار: ${message.data}');
      });
    } catch (e) {
      print('⚠️ FCM غير متاح حالياً: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // ✅ استخدم نفس معرف القناة
      'High Importance Notifications',
      channelDescription: 'إشعارات الطلبات الجديدة',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(
      0,
      title,
      body,
      details,
    );
  }
}