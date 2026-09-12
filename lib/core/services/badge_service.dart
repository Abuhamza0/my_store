import 'package:flutter/foundation.dart';
import 'package:flutter_app_badge/flutter_app_badge.dart';

class BadgeService {
  static Future<void> updateBadge(int count) async {
    if (kIsWeb) return;

    try {
      // هذه المكتبة تستخدم الدالة count لتحديث أو تصفير الشارة مباشرة
      if (count > 0) {
        FlutterAppBadge.count(count);
      } else {
        FlutterAppBadge.count(0);
      }
      print('✅ Badge updated successfully: $count');
    } catch (e) {
      print('⚠️ تحذير: فشل تحديث شارة التطبيق: $e');
    }
  }
}