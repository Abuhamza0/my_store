import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class StoreIdService {
  static bool isAdmin() {
    final settingsBox = Hive.box('settings');
    return settingsBox.get('is_admin', defaultValue: false) ?? false;
  }

  /// ✅ إرجاع storeId المضمون (يدعم حساب التاجر وحالة زبون المتجر)
  static String getStoreId() {
    final settingsBox = Hive.box('settings');

    // 1. فحص روابط الويب أولاً (إذا كان الزبون قادماً من رابط يحتوي على storeId)
    try {
      final urlStoreId = Get.parameters['storeId'] ?? Get.parameters['store_id'];
      if (urlStoreId != null && urlStoreId.trim().isNotEmpty) {
        final cleanUrlId = urlStoreId.trim();
        saveStoreIdLocally(cleanUrlId); // حفظه فوراً للاستخدام في طلبات العميل
        return cleanUrlId;
      }
    } catch (_) {}

    // 2. إذا كان المستخدم تاجراً ومسجلاً الدخول في FirebaseAuth
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      saveStoreIdLocally(uid);
      return uid;
    }

    // 3. قراءة storeid المحفوظ محلياً للزبون (فحص المفتاحين store_id و storeid)
    final storedId = settingsBox.get('store_id') ?? settingsBox.get('storeid');
    if (storedId != null && storedId.toString().trim().isNotEmpty) {
      final cleanStoredId = storedId.toString().trim();
      if (cleanStoredId != 'default_store') {
        return cleanStoredId;
      }
    }

    // 4. احتياطي أخير: البريد الإلكتروني (في حالات التاجر القديمة)
    try {
      final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      if (authEmail.isNotEmpty) {
        return _emailToStoreId(authEmail);
      }
    } catch (_) {}

    return '';
  }

  /// ✅ حفظ storeId محلياً تحت المفتاحين الموحدين لمنع أي تضارب
  static void saveStoreIdLocally(String storeId) {
    if (storeId.isEmpty || storeId == 'default_store') return;
    final settingsBox = Hive.box('settings');
    settingsBox.put('storeid', storeId);
    settingsBox.put('store_id', storeId);
  }

  /// ✅ تحويل البريد إلى storeId آمن (خطة احتياطية)
  static String _emailToStoreId(String email) {
    return email.trim().toLowerCase().replaceAll('@', '_').replaceAll('.', '_');
  }

  /// ✅ إنشاء storeId في السحابة عند إنشاء حساب جديد للتاجر
  static Future<String> createStoreIdInCloud(String email) async {
    try {
      if (email.isEmpty) return '';

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) return '';

      await FirebaseFirestore.instance
          .collection('store_owners')
          .doc(uid)
          .set({
        'storeid': uid,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));

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

  /// ✅ جلب storeId من السحابة عند تسجيل دخول التاجر
  static Future<String> loadStoreIdFromCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return getStoreId(); // إرجاع المعرف المحفوظ للزبون

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

  /// ✅ التحقق من تطابق storeId المحلي مع السحابي للتاجر
  static Future<void> validateStoreId() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) return; // للزبون فقط لا نسجل خروج

      final localStoreId = getStoreId();

      final doc = await FirebaseFirestore.instance
          .collection('store_owners')
          .doc(uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        await FirebaseFirestore.instance
            .collection('store_owners')
            .doc(uid)
            .set({
          'storeid': localStoreId,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));
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

  /// ✅ تسجيل الخروج القسري للتاجر
  static Future<void> _forceLogout() async {
    final settingsBox = Hive.box('settings');
    settingsBox.delete('storeid');
    settingsBox.delete('store_id');
    settingsBox.delete('store_email');
    settingsBox.delete('store_logged_in');
    settingsBox.delete('is_admin');
    Get.offAllNamed('/store_login');
  }

  /// ✅ مسح بيانات الحساب عند الحذف فقط
  static void clearStoreIdOnAccountDeletion() async {
    final settingsBox = Hive.box('settings');
    settingsBox.delete('store_email');
    settingsBox.delete('storeid');
    settingsBox.delete('store_id');
    settingsBox.delete('store_logged_in');
    settingsBox.delete('is_admin');
    print('🗑️ تم مسح storeId عند حذف الحساب');
  }

  /// ✅ إنشاء مستخدم جديد في مجموعة users
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
          .set({
        'storeid': uid,
        'email': email,
        'password': password,
        'name': name,
        'phone': phone ?? '',
        'is_subscribed': isSubscribed,
        'subscription_type': subscriptionType,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
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
          .set(data, SetOptions(merge: true));
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