// store_id_service.dart
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class StoreIdService {
  // ═══════════════════════════════════════════════════════════
  //  🆔 إدارة Device ID
  // ═══════════════════════════════════════════════════════════

  /// مفتاح Hive لتخزين deviceId
  static const String _deviceIdKey = 'device_id';

  /// إرجاع deviceId الحالي (يُنشأ مرة واحدة ويُحفظ للأبد)
  static String getDeviceId() {
    final settingsBox = Hive.box('settings');
    String? deviceId = settingsBox.get(_deviceIdKey)?.toString();

    if (deviceId == null || deviceId.isEmpty) {
      // إنشاء معرّف جديد فريد
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 100000)}';
      settingsBox.put(_deviceIdKey, deviceId);
      print('🆕 تم إنشاء deviceId جديد: $deviceId');
    }

    return deviceId;
  }

  /// حفظ deviceId يدوياً (يُستخدم من SessionService)
  static void saveDeviceId(String deviceId) {
    if (deviceId.isEmpty) return;
    Hive.box('settings').put(_deviceIdKey, deviceId);
  }

  // ═══════════════════════════════════════════════════════════
  //  🏷️ إضافة deviceId إلى أي Map تلقائياً
  // ═══════════════════════════════════════════════════════════

  /// تُضيف deviceId إلى أي Map قبل رفعها إلى Firestore
  ///
  /// الاستخدام:
  /// ```dart
  /// await FirebaseFirestore.instance
  ///     .collection('products')
  ///     .doc(id)
  ///     .set(StoreIdService.stamp({...}));
  /// ```
  static Map<String, dynamic> stamp(Map<String, dynamic> data) {
    return {
      ...data,
      'deviceId': getDeviceId(),
    };
  }

  /// نسخة مطورة: تكتب مباشرة إلى Firestore مع deviceId
  ///
  /// الاستخدام:
  /// ```dart
  /// await StoreIdService.setWithDevice(
  ///   collection: 'products',
  ///   docId: product.id,
  ///   data: {...},
  /// );
  /// ```
  static Future<void> setWithDevice({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .set(stamp(data), SetOptions(merge: merge));
    } catch (e) {
      print('❌ setWithDevice error: $e');
      rethrow;
    }
  }

  /// نسخة مطورة: تحديث مباشر مع deviceId
  ///
  /// الاستخدام:
  /// ```dart
  /// await StoreIdService.updateWithDevice(
  ///   collection: 'orders',
  ///   docId: order.id,
  ///   data: {'status': 'pending'},
  /// );
  /// ```
  static Future<void> updateWithDevice({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .update(stamp(data));
    } catch (e) {
      print('❌ updateWithDevice error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  👑 التحقق من الأدمن
  // ═══════════════════════════════════════════════════════════

  static bool isAdmin() {
    final settingsBox = Hive.box('settings');
    return settingsBox.get('is_admin', defaultValue: false) ?? false;
  }

  // ═══════════════════════════════════════════════════════════
  //  🏪 إدارة Store ID (كما هو)
  // ═══════════════════════════════════════════════════════════

  /// ✅ إرجاع storeId المضمون (يدعم حساب التاجر وحالة زبون المتجر)
  static String getStoreId() {
    final settingsBox = Hive.box('settings');

    // 1. فحص روابط الويب
    try {
      final urlStoreId = Get.parameters['storeId'] ?? Get.parameters['store_id'];
      if (urlStoreId != null && urlStoreId.trim().isNotEmpty) {
        final cleanUrlId = urlStoreId.trim();
        saveStoreIdLocally(cleanUrlId);
        return cleanUrlId;
      }
    } catch (_) {}

    // 2. FirebaseAuth (للتاجر)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      saveStoreIdLocally(uid);
      return uid;
    }

    // 3. المحلي (للزبون)
    final storedId = settingsBox.get('store_id') ?? settingsBox.get('storeid');
    if (storedId != null && storedId.toString().trim().isNotEmpty) {
      final cleanStoredId = storedId.toString().trim();
      if (cleanStoredId != 'default_store') {
        return cleanStoredId;
      }
    }

    // 4. احتياطي
    try {
      final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      if (authEmail.isNotEmpty) {
        return _emailToStoreId(authEmail);
      }
    } catch (_) {}

    return '';
  }

  static void saveStoreIdLocally(String storeId) {
    if (storeId.isEmpty || storeId == 'default_store') return;
    final settingsBox = Hive.box('settings');
    settingsBox.put('storeid', storeId);
    settingsBox.put('store_id', storeId);
  }

  static String _emailToStoreId(String email) {
    return email.trim().toLowerCase().replaceAll('@', '_').replaceAll('.', '_');
  }

  static Future<String> createStoreIdInCloud(String email) async {
    try {
      if (email.isEmpty) return '';

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) return '';

      await FirebaseFirestore.instance
          .collection('store_owners')
          .doc(uid)
          .set(stamp({
        'storeid': uid,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
      }), SetOptions(merge: false));

      saveStoreIdLocally(uid);
      final settingsBox = Hive.box('settings');
      settingsBox.put('store_email', email);

      print('✅ تم إنشاء storeId في السحابة: $uid');
      return uid;
    } catch (e) {
      print('❌ فشل إنشاء storeId في السحابة: $e');
      return '';
    }
  }

  static Future<String> loadStoreIdFromCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return getStoreId();

      final uid = user.uid;
      if (uid.isEmpty) return '';

      final doc = await FirebaseFirestore.instance
          .collection('store_owners')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final storedStoreId = doc.data()!['storeid']?.toString() ?? '';
        if (storedStoreId.isNotEmpty) {
          saveStoreIdLocally(storedStoreId);
          return storedStoreId;
        }
      }

      return await createStoreIdInCloud(user.email ?? '');
    } catch (e) {
      print('❌ خطأ في جلب storeId من السحابة: $e');
      return getStoreId();
    }
  }

  static Future<void> validateStoreId() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) return;

      final localStoreId = getStoreId();

      final doc = await FirebaseFirestore.instance
          .collection('store_owners')
          .doc(uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        await FirebaseFirestore.instance
            .collection('store_owners')
            .doc(uid)
            .set(stamp({
          'storeid': localStoreId,
          'updated_at': FieldValue.serverTimestamp(),
        }), SetOptions(merge: false));
        return;
      }

      final cloudStoreId = doc.data()!['storeid']?.toString() ?? '';
      if (cloudStoreId.isNotEmpty && cloudStoreId != localStoreId) {
        await _forceLogout();
      }
    } catch (e) {
      print('❌ فشل التحقق من storeId: $e');
    }
  }

  static Future<void> _forceLogout() async {
    final settingsBox = Hive.box('settings');
    settingsBox.delete('storeid');
    settingsBox.delete('store_id');
    settingsBox.delete('store_email');
    settingsBox.delete('store_logged_in');
    settingsBox.delete('is_admin');
    Get.offAllNamed('/store_login');
  }

  static void clearStoreIdOnAccountDeletion() async {
    final settingsBox = Hive.box('settings');
    settingsBox.delete('store_email');
    settingsBox.delete('storeid');
    settingsBox.delete('store_id');
    settingsBox.delete('store_logged_in');
    settingsBox.delete('is_admin');
    print('🗑️ تم مسح storeId عند حذف الحساب');
  }

  // ═══════════════════════════════════════════════════════════
  //  👤 إدارة المستخدمين
  // ═══════════════════════════════════════════════════════════

  static Future<void> createUserInCloud({
    required String email,
    required String password,
    required String name,
    String? phone,
    bool isSubscribed = false,
    String subscriptionType = 'free',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(stamp({
        'storeid': uid,
        'email': email,
        'password': password,
        'name': name,
        'phone': phone ?? '',
        'is_subscribed': isSubscribed,
        'subscription_type': subscriptionType,
        'created_at': FieldValue.serverTimestamp(),
      }), SetOptions(merge: false));
      print('✅ تم إنشاء المستخدم في users');
    } catch (e) {
      print('❌ فشل إنشاء المستخدم: $e');
    }
  }

  static Future<Map<String, dynamic>?> loadUserFromCloud(String email) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (e) {
      print('❌ فشل جلب المستخدم: $e');
    }
    return null;
  }

  static Future<void> updateUserInCloud({
    required String email,
    required Map<String, dynamic> data,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(stamp(data), SetOptions(merge: true));
      print('✅ تم تحديث المستخدم');
    } catch (e) {
      print('❌ فشل تحديث المستخدم: $e');
    }
  }

  static Future<void> deleteUserFromCloud(String email) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();
      print('✅ تم حذف المستخدم');
    } catch (e) {
      print('❌ فشل حذف المستخدم: $e');
    }
  }
}