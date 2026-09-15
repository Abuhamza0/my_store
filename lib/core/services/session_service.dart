import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'store_id_service.dart';
import 'package:hive/hive.dart';

class SessionService {
  static const String deviceIdKey = 'device_id';

  /// جلب أو إنشاء معرف فريد للجهاز (متوافق مع الويب والموبايل)
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 100000)}';
      await prefs.setString(deviceIdKey, deviceId);
    }
    // ✅ احفظه في Hive للاستخدام في القواعد
    Hive.box('settings').put('device_id', deviceId);
    return deviceId;
  }

  /// التحقق من وجود جهاز آخر نشط (يمرر له storeId المباشر عند تسجيل الدخول)
  static Future<String?> getActiveOtherDevice() async {
    // ✅ استخدام uid مباشرة من StoreIdService
    final storeId = StoreIdService.getStoreId();
    if (storeId.isEmpty) return null;

    final currentDeviceId = await getDeviceId();

    try {
      final storeDoc = await FirebaseFirestore.instance
          .collection('store_devices')
          .doc(storeId) // ✅ المفتاح هو uid
          .get();

      if (!storeDoc.exists || storeDoc.data() == null) return null;

      final data = storeDoc.data()!;
      final activeDeviceId = data['current_device_id']?.toString() ?? '';
      final isLoggedOut = data['logout'] ?? false;

      // ✅ إذا كان المستخدم قد سجل خروجًا، نسمح بالدخول
      if (isLoggedOut == true) {
        return null;
      }

      if (activeDeviceId.isEmpty || activeDeviceId == currentDeviceId) {
        return null;
      }

      // فحص آخر نشاط
      final lastActive = data['last_active'] as Timestamp?;
      if (lastActive != null) {
        final diff = DateTime.now().difference(lastActive.toDate());
        if (diff.inDays >= 30) {
          return null;
        }
      }

      return activeDeviceId;
    } catch (e) {
      print('❌ فشل التحقق: $e');
      return null;
    }
  }

  /// بدء جلسة جديدة للجهاز الحالي وتحديث المعرف في Cloud Firestore
  static Future<bool> startSession() async {
    // ✅ استخدام uid مباشرة من StoreIdService
    final storeId = StoreIdService.getStoreId();
    if (storeId.isEmpty) return false;

    final deviceId = await getDeviceId();

    final storeRef = FirebaseFirestore.instance
        .collection('store_devices')
        .doc(storeId); // ✅ المفتاح هو uid

    final sessionsRef = storeRef.collection('sessions');

    try {
      // حذف الجلسات السابقة
      final oldSessions = await sessionsRef.get();
      for (var doc in oldSessions.docs) {
        await doc.reference.delete();
      }

      // إنشاء جلسة جديدة
      await sessionsRef.doc(deviceId).set({
        'device_id': deviceId,
        'started_at': FieldValue.serverTimestamp(),
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ إضافة حقل logout = false عند بدء الجلسة
      await storeRef.set({
        'storeid': storeId,
        'current_device_id': deviceId,
        'is_online': true,
        'last_active': FieldValue.serverTimestamp(),
        'logout': false,   // ✅ جديد
      }, SetOptions(merge: true));

      print('✅ بدء جلسة جديدة للمتجر $storeId على الجهاز $deviceId');
      return true;
    } catch (e) {
      print('❌ فشل بدء الجلسة: $e');
      return false;
    }
  }

  /// النبض الدوري للنشاط (يُستدعى كل فترة للحفاظ على الجلسة حية)
  static Future<void> heartbeat() async {
    // ✅ استخدام uid مباشرة من StoreIdService
    final storeId = StoreIdService.getStoreId();
    if (storeId.isEmpty) return;

    final deviceId = await getDeviceId();
    final storeRef = FirebaseFirestore.instance.collection('store_devices').doc(storeId);

    try {
      // التحقق أولاً هل ما زال هذا الجهاز هو الجهاز المعتمد
      final doc = await storeRef.get();
      if (doc.exists) {
        final activeId = doc.data()?['current_device_id']?.toString() ?? '';
        if (activeId.isNotEmpty && activeId != deviceId) {
          // جهاز آخر قام بتسجيل الدخول وطرد هذا الجهاز!
          return;
        }
      }

      await storeRef.set({
        'is_online': true,
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ خطأ في تحديث النبض: $e');
    }
  }

  /// إنهاء الجلسة عند تسجيل الخروج
  static Future<void> endSession() async {
    // ✅ استخدام uid مباشرة من StoreIdService
    final storeId = StoreIdService.getStoreId();
    if (storeId.isEmpty) return;
    final deviceId = await getDeviceId();

    final storeRef = FirebaseFirestore.instance
        .collection('store_devices')
        .doc(storeId); // ✅ المفتاح هو uid

    try {
      // ✅ رفع حالة logout = true في السحابة
      await storeRef.set({
        'is_online': false,
        'current_device_id': '',
        'logout': true,     // ✅ تسجيل الخروج
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await storeRef.collection('sessions').doc(deviceId).delete();
      print('✅ تم تسجيل الخروج في السحابة');
    } catch (e) {
      print('❌ خطأ في إنهاء الجلسة: $e');
    }
  }

}