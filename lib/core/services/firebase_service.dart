import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📝 تسجيل متجر جديد في Firebase
  static Future<void> registerStore() async {
    try {
      final settingsBox = Hive.box('settings');
      final storeId = settingsBox.get('store_id', defaultValue: '');
      final storeName = settingsBox.get('store_name', defaultValue: '');
      final phone = settingsBox.get('store_phone', defaultValue: '');

      if (storeId.isEmpty) return;

      await _firestore.collection('stores').doc(storeId).set({
        'storeId': storeId,
        'storeName': storeName,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Firebase registerStore error: $e');
    }
  }

  /// 👤 إضافة عميل جديد للمتجر في Firebase
  static Future<void> addCustomer({
    required String phone,
    required String name,
  }) async {
    try {
      final settingsBox = Hive.box('settings');
      final storeId = settingsBox.get('store_id', defaultValue: '');

      if (storeId.isEmpty) return;

      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('customers')
          .doc(phone)
          .set({
        'phone': phone,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      print('Firebase addCustomer error: $e');
    }
  }

  /// 👤 إضافة مستخدم (مالك متجر) إلى Firebase
  static Future<void> addUser({
    required String phone,
    required String name,
    required String storeId,
  }) async {
    try {
      final settingsBox = Hive.box('settings');

      // ✅ البريد الإلكتروني من Hive
      final email = settingsBox.get('store_email', defaultValue: '')?.toString() ?? '';

      // ✅ معرف ثابت من البريد
      final docId = email.trim().isNotEmpty
          ? email.trim().replaceAll('@', '_').replaceAll('.', '_')
          : storeId;

      print('📧 البريد: $email');
      print('📄 معرف المستند: $docId');

      // ✅ حفظ في users بمعرف البريد
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .set({
        'phone': phone,
        'name': name,
        'email': email,
        'storeId': docId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ حفظ أيضاً في stores بمعرف البريد
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(docId)
          .set({
        'phone': phone,
        'name': name,
        'email': email,
        'storeId': docId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ تم الحفظ بمعرف: $docId');
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }
  /// 👥 الحصول على عدد المستخدمين الكلي
  static Future<int> getUserCount() async {
    try {
      final snapshot = await _firestore.collection('users').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Firebase getUserCount error: $e');
      return 0;
    }
  }

  /// 🔍 التحقق من وجود عميل في Firebase
  static Future<bool> isCustomerValid(String phone) async {
    try {
      final settingsBox = Hive.box('settings');
      final storeId = settingsBox.get('store_id', defaultValue: '');

      if (storeId.isEmpty) return false;

      final doc = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('customers')
          .doc(phone)
          .get();

      return doc.exists;
    } catch (e) {
      print('Firebase isCustomerValid error: $e');
      return false;
    }
  }

  /// 📊 الحصول على عدد المتاجر المسجلة
  static Future<int> getTotalStores() async {
    try {
      final snapshot = await _firestore.collection('stores').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Firebase getTotalStores error: $e');
      return 0;
    }
  }

  /// 🔄 تحديث آخر نشاط للمتجر
  static Future<void> updateLastActive() async {
    try {
      final settingsBox = Hive.box('settings');
      final storeId = settingsBox.get('store_id', defaultValue: '');

      if (storeId.isEmpty) return;

      await _firestore.collection('stores').doc(storeId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Firebase updateLastActive error: $e');
    }
  }
  /// 👥 الاستماع المباشر لتغييرات عدد المستخدمين
  static Stream<int> getUserCountStream() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}