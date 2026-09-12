import 'package:cloud_firestore/cloud_firestore.dart';

class CloudStoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📝 تسجيل متجر جديد
  static Future<String> registerStore({
    required String storeName,
    required String ownerPhone,
  }) async {
    final storeRef = _firestore.collection('stores').doc();
    final storeId = storeRef.id;

    await storeRef.set({
      'storeId': storeId,
      'storeName': storeName,
      'ownerPhone': ownerPhone,
      'subscribed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return storeId;
  }

  /// 🔍 البحث عن متجر برقم الهاتف
  static Future<Map<String, dynamic>?> findStoreByPhone(String phone) async {
    final snapshot = await _firestore
        .collection('stores')
        .where('ownerPhone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  }

  /// ✅ التحقق من صحة المتجر
  static Future<bool> isStoreValid(String storeId, String phone) async {
    final doc = await _firestore.collection('stores').doc(storeId).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    return data['ownerPhone'] == phone;
  }

  /// 🛍️ الحصول على منتجات متجر
  static Stream<QuerySnapshot> getProducts(String storeId) {
    return _firestore
        .collection('stores_data')
        .doc(storeId)
        .collection('products')
        .snapshots();
  }

  /// 👥 الحصول على عملاء متجر
  static Stream<QuerySnapshot> getCustomers(String storeId) {
    return _firestore
        .collection('stores_data')
        .doc(storeId)
        .collection('customers')
        .snapshots();
  }
}