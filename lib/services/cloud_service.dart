import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class CloudService extends GetxController {
  static CloudService get to => Get.find();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  @override
  void onInit() {
    super.onInit();
    debugPrint('☁️ CloudService initialized');
  }

  // ==================== روابط المتجر ====================

  /// ✅ إنشاء رابط متجر سحابي
  Future<void> createStoreLink({
    required String linkId,
    required String storeId,
    required String customerPhone,
    String? customerEmail,
    String? storeName,
    String? createdAt,
    String? source,
  }) async {
    try {
      await firestore.collection('store_links').doc(linkId).set({
        'linkId': linkId,
        'storeId': storeId,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail ?? '',
        'storeName': storeName ?? '',
        'createdAt': createdAt ?? DateTime.now().toIso8601String(),
        'source': source ?? 'cloud_100',
        'isActive': true,
        'clickCount': 0,
        'lastClicked': null,
      });

      debugPrint('✅ Store link created: $linkId');
    } catch (e) {
      debugPrint('❌ Error creating store link: $e');
      rethrow;
    }
  }

  /// ✅ الحصول على بيانات الرابط السحابي
  Future<Map<String, dynamic>?> getStoreLink(String linkId) async {
    try {
      final doc = await firestore.collection('store_links').doc(linkId).get();
      if (doc.exists) {
        // تحديث عداد النقرات
        await firestore.collection('store_links').doc(linkId).update({
          'clickCount': FieldValue.increment(1),
          'lastClicked': FieldValue.serverTimestamp(),
        });

        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting store link: $e');
      return null;
    }
  }

  /// ✅ تحديث رابط المتجر
  Future<void> updateStoreLink({
    required String linkId,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (isActive != null) updates['isActive'] = isActive;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await firestore.collection('store_links').doc(linkId).update(updates);
      debugPrint('✅ Store link updated: $linkId');
    } catch (e) {
      debugPrint('❌ Error updating store link: $e');
      rethrow;
    }
  }

  /// ✅ حذف رابط المتجر
  Future<void> deleteStoreLink(String linkId) async {
    try {
      await firestore.collection('store_links').doc(linkId).delete();
      debugPrint('✅ Store link deleted: $linkId');
    } catch (e) {
      debugPrint('❌ Error deleting store link: $e');
      rethrow;
    }
  }

  /// ✅ الحصول على جميع روابط المتجر
  Future<List<Map<String, dynamic>>> getStoreLinks(String storeId) async {
    try {
      final snapshot = await firestore
          .collection('store_links')
          .where('storeId', isEqualTo: storeId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error getting store links: $e');
      return [];
    }
  }

  /// ✅ التحقق من وجود نسخة احتياطية للمتجر
  Future<bool> checkStoreBackup(String storeId) async {
    try {
      final products = await firestore
          .collection('products')
          .where('store_id', isEqualTo: storeId)
          .limit(1)
          .get();

      final settings = await firestore
          .collection('settings')
          .doc(storeId)
          .get();

      final categories = await firestore
          .collection('categories')
          .doc(storeId)
          .get();

      return products.docs.isNotEmpty || settings.exists || categories.exists;
    } catch (e) {
      debugPrint('❌ Error checking backup: $e');
      return false;
    }
  }

  /// ✅ الحصول على إحصائيات الروابط
  Future<Map<String, dynamic>> getLinkStats(String storeId) async {
    try {
      final links = await getStoreLinks(storeId);

      int totalClicks = 0;
      int activeLinks = 0;

      for (var link in links) {
        totalClicks += (link['clickCount'] ?? 0) as int;
        if (link['isActive'] == true) {
          activeLinks++;
        }
      }

      return {
        'totalLinks': links.length,
        'activeLinks': activeLinks,
        'totalClicks': totalClicks,
      };
    } catch (e) {
      debugPrint('❌ Error getting link stats: $e');
      return {
        'totalLinks': 0,
        'activeLinks': 0,
        'totalClicks': 0,
      };
    }
  }

  // ==================== العملاء ====================

  /// ✅ إضافة عميل
  Future<void> addCustomer({
    required String phone,
    String name = '',
    String countryCode = '+966',
  }) async {
    try {
      final customerId = 'customer_${DateTime.now().millisecondsSinceEpoch}';

      await firestore.collection('customers').doc(customerId).set({
        'id': customerId,
        'phone': phone,
        'name': name,
        'countryCode': countryCode,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Customer added: $phone');
    } catch (e) {
      debugPrint('❌ Error adding customer: $e');
      rethrow;
    }
  }

  /// ✅ تحديث عميل
  Future<void> updateCustomer({
    required String customerId,
    required String phone,
    String name = '',
  }) async {
    try {
      await firestore.collection('customers').doc(customerId).update({
        'phone': phone,
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Customer updated: $customerId');
    } catch (e) {
      debugPrint('❌ Error updating customer: $e');
      rethrow;
    }
  }

  // ==================== الإحصائيات ====================

  /// ✅ الحصول على عدد المستخدمين
  Future<int> getUserCount() async {
    try {
      final snapshot = await firestore.collection('customers').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting user count: $e');
      return 0;
    }
  }

  /// ✅ الحصول على عدد المنتجات
  Future<int> getProductCount() async {
    try {
      final snapshot = await firestore.collection('products').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting product count: $e');
      return 0;
    }
  }

  /// ✅ الحصول على عدد الطلبات
  Future<int> getOrderCount() async {
    try {
      final snapshot = await firestore.collection('orders').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting order count: $e');
      return 0;
    }
  }

  /// ✅ الحصول على عدد الطلبات حسب الحالة
  Future<int> getOrderCountByStatus(String status) async {
    try {
      final snapshot = await firestore
          .collection('orders')
          .where('status', isEqualTo: status)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting order count by status: $e');
      return 0;
    }
  }

  /// ✅ الحصول على عدد المستخدمين النشطين
  Future<int> getActiveUserCount() async {
    try {
      final snapshot = await firestore
          .collection('customers')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting active user count: $e');
      return 0;
    }
  }

  /// ✅ الحصول على إجمالي المبيعات
  Future<double> getTotalSales() async {
    try {
      final snapshot = await firestore.collection('orders').get();
      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['totalAmount'] != null) {
          total += (data['totalAmount'] as num).toDouble();
        }
      }
      return total;
    } catch (e) {
      debugPrint('❌ Error getting total sales: $e');
      return 0;
    }
  }

  /// ✅ الحصول على عدد الروابط النشطة
  Future<int> getActiveLinksCount() async {
    try {
      final snapshot = await firestore
          .collection('store_links')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting active links count: $e');
      return 0;
    }
  }

  /// ✅ الحصول على إحصائيات كاملة
  Future<Map<String, dynamic>> getFullStats() async {
    try {
      final results = await Future.wait([
        getUserCount(),
        getProductCount(),
        getOrderCount(),
        getActiveUserCount(),
        getTotalSales(),
        getActiveLinksCount(),
      ]);

      return {
        'totalUsers': results[0],
        'totalProducts': results[1],
        'totalOrders': results[2],
        'activeUsers': results[3],
        'totalSales': results[4],
        'activeLinks': results[5],
      };
    } catch (e) {
      debugPrint('❌ Error getting full stats: $e');
      return {
        'totalUsers': 0,
        'totalProducts': 0,
        'totalOrders': 0,
        'activeUsers': 0,
        'totalSales': 0.0,
        'activeLinks': 0,
      };
    }
  }

  // ==================== المنتجات ====================

  /// ✅ إضافة منتج
  Future<void> addProduct(Map<String, dynamic> productData) async {
    try {
      final productId = productData['id'] ?? 'product_${DateTime.now().millisecondsSinceEpoch}';

      await firestore.collection('products').doc(productId).set({
        ...productData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Product added: ${productData['name']}');
    } catch (e) {
      debugPrint('❌ Error adding product: $e');
      rethrow;
    }
  }

  /// ✅ تحديث منتج
  Future<void> updateProduct(String productId, Map<String, dynamic> productData) async {
    try {
      await firestore.collection('products').doc(productId).update({
        ...productData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Product updated: $productId');
    } catch (e) {
      debugPrint('❌ Error updating product: $e');
      rethrow;
    }
  }

  /// ✅ حذف منتج
  Future<void> deleteProduct(String productId) async {
    try {
      await firestore.collection('products').doc(productId).delete();
      debugPrint('✅ Product deleted: $productId');
    } catch (e) {
      debugPrint('❌ Error deleting product: $e');
      rethrow;
    }
  }

  // ==================== الطلبات ====================

  /// ✅ إضافة طلب
  Future<void> addOrder(Map<String, dynamic> orderData) async {
    try {
      final orderId = orderData['id'] ?? 'order_${DateTime.now().millisecondsSinceEpoch}';

      await firestore.collection('orders').doc(orderId).set({
        ...orderData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Order added: $orderId');
    } catch (e) {
      debugPrint('❌ Error adding order: $e');
      rethrow;
    }
  }

  /// ✅ تحديث حالة الطلب
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Order status updated: $orderId -> $status');
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
      rethrow;
    }
  }
}