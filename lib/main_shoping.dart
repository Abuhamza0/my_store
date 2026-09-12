import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:html' as html; // ✅ للويب فقط
import 'features/store_service/sales_screen.dart';
import 'features/store_service/product_controller.dart';
import 'features/store_service/customer_controller.dart';
import 'features/store_service/order_controller.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    final notificationService = NotificationService();
    await notificationService.init();
  }
  await Hive.initFlutter();
  await Hive.openBox('products');
  await Hive.openBox('customers');
  await Hive.openBox('orders');
  await Hive.openBox('settings');
  await SharedPreferences.getInstance();

  Get.put(ProductController(), permanent: true);
  Get.put(CustomerController(), permanent: true);
  Get.put(OrderController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// ✅ دالة موثوقة لقراءة storeId من الرابط
  String _getStoreIdFromUrl() {
    // 1) استخدام Uri.base
    var storeId = Uri.base.queryParameters['storeId'] ?? '';

    // 2) إذا فارغ، نقرأ من window.location.href (للويب)
    if (storeId.isEmpty) {
      try {
        final fullUrl = html.window.location.href;
        storeId = Uri.parse(fullUrl).queryParameters['storeId'] ?? '';
      } catch (_) {}
    }

    print('🔍 storeId from URL: "$storeId"');
    return storeId;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ استخدم الدالة الموحدة لقراءة storeId
    final storeId = _getStoreIdFromUrl();
    final phone = Uri.base.queryParameters['phone'] ?? '';

    print('📱 phone: "$phone"');

    return GetMaterialApp(
      title: 'المتجر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1A2332),
        useMaterial3: true,
      ),
      home: SalesScreen(
        storeIdFromUrl: storeId.isEmpty ? null : storeId,
        phoneFromUrl: phone.isEmpty ? null : phone,
        showBackButton: false,
      ),
    );
  }
}