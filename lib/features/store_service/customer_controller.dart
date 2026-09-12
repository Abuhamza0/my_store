import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../core/services/store_id_service.dart';
import 'customer_model.dart';

class CustomerController extends GetxController {
  final Box _customerBox = Hive.box('customers');

  final customers = <Customer>[].obs;
  final filteredCustomers = <Customer>[].obs;
  final searchQuery = ''.obs;
  final isLoading = false.obs;

  final onlineTick = 0.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _customersSubscription;
  Timer? _onlineTimer;

  @override
  void onInit() {
    super.onInit();
    loadCustomers();
    _listenToFirestoreCustomers();
    _startOnlineTimer();
  }

  // ✅ الحصول على store_id من UID مباشرة
  String _getStoreId() {
    try {
      return StoreIdService.getStoreId();
    } catch (e) {
      print('❌ خطأ في جلب storeId: $e');
      return '';
    }
  }

  void loadCustomers() {
    isLoading.value = true;
    try {
      customers.clear();
      for (final key in _customerBox.keys) {
        try {
          final data = _customerBox.get(key);
          if (data != null && data is Map) {
            final customer = Customer.fromJson(Map<String, dynamic>.from(data));
            customers.add(customer);
          }
        } catch (e) {
          debugPrint('❌ خطأ في تحميل عميل من Hive: $e');
        }
      }
      filterCustomers();
    } finally {
      isLoading.value = false;
    }
  }

  void _listenToFirestoreCustomers() {
    try {
      final storeId = _getStoreId();
      if (storeId.isEmpty || storeId == 'default_store') {
        print('⚠️ storeId غير صالح - تخطي جلب العملاء من السحابة');
        return;
      }

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('customers')
          .where('store_id', isEqualTo: storeId); // ✅ استخدام store_id

      debugPrint('☁️ بدء الاستماع إلى عملاء Firestore');
      debugPrint('🏪 storeId = $storeId');

      _customersSubscription = query.snapshots().listen(
            (snapshot) async {
          debugPrint('☁️ وصل تحديث من Firestore: ${snapshot.docs.length} عميل');

          final cloudCustomers = <Customer>[];

          for (final doc in snapshot.docs) {
            try {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] ??= doc.id;

              // تحويل Timestamp إلى DateTime
              if (data['createdAt'] is Timestamp) {
                data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
              }
              if (data['lastActive'] is Timestamp) {
                data['lastActive'] = (data['lastActive'] as Timestamp).toDate().toIso8601String();
              }
              if (data['lastOrderDate'] is Timestamp) {
                data['lastOrderDate'] = (data['lastOrderDate'] as Timestamp).toDate().toIso8601String();
              }
              if (data['linkExpiryDate'] is Timestamp) {
                data['linkExpiryDate'] = (data['linkExpiryDate'] as Timestamp).toDate().toIso8601String();
              }

              final customer = Customer.fromJson(data);
              cloudCustomers.add(customer);
              await _customerBox.put(customer.id, customer.toJson());
            } catch (e) {
              debugPrint('❌ خطأ في معالجة عميل Firestore ${doc.id}: $e');
            }
          }

          customers.assignAll(cloudCustomers);
          filterCustomers();
          debugPrint('✅ تم تحديث القائمة: ${customers.length} عميل');
        },
        onError: (error) {
          debugPrint('❌ خطأ في الاستماع إلى Firestore: $error');
          loadCustomers();
        },
      );
    } catch (e) {
      debugPrint('❌ فشل إنشاء Firestore listener: $e');
    }
  }

  void _startOnlineTimer() {
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      onlineTick.value++;
    });
  }

  Future<void> addCustomer(Customer customer) async {
    try {
      final storeId = _getStoreId();
      await _customerBox.put(customer.id, customer.toJson());

      // حفظ في السحابة مع store_id
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customer.id)
          .set({
        ...customer.toJson(),
        'store_id': storeId,
      }, SetOptions(merge: true));

      final index = customers.indexWhere((c) => c.id == customer.id);
      if (index == -1) {
        customers.add(customer);
      } else {
        customers[index] = customer;
      }
      filterCustomers();

      Get.snackbar(
        'نجاح',
        'تم إضافة العميل بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('❌ خطأ في إضافة العميل: $e');
      Get.snackbar('خطأ', 'تعذر إضافة العميل', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      final storeId = _getStoreId();
      await _customerBox.put(customer.id, customer.toJson());
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customer.id)
          .set({
        ...customer.toJson(),
        'store_id': storeId,
      }, SetOptions(merge: true));

      final index = customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        customers[index] = customer;
      } else {
        customers.add(customer);
      }
      filterCustomers();
    } catch (e) {
      debugPrint('❌ خطأ في تحديث العميل: $e');
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    await _customerBox.delete(customerId);
    customers.removeWhere((c) => c.id == customerId);
    filterCustomers();

    try {
      await FirebaseFirestore.instance.collection('customers').doc(customerId).delete();
      debugPrint('✅ تم حذف العميل من Firestore بالـ ID');
    } catch (e) {
      debugPrint('⚠️ الحذف بالـ ID فشل: $e');
    }

    Get.snackbar('نجاح', 'تم حذف العميل', backgroundColor: Colors.green, colorText: Colors.white);
  }

  void filterCustomers() {
    if (searchQuery.value.trim().isEmpty) {
      filteredCustomers.assignAll(customers);
      return;
    }
    final query = searchQuery.value.trim().toLowerCase();
    filteredCustomers.assignAll(
      customers.where((c) =>
      c.name.toLowerCase().contains(query) ||
          c.phone.contains(query) ||
          c.email.toLowerCase().contains(query)),
    );
  }

  int get totalCustomers => customers.length;

  double get totalSales => customers.fold(0.0, (sum, c) => sum + c.totalPurchases);

  @override
  void onClose() {
    _customersSubscription?.cancel();
    _onlineTimer?.cancel();
    super.onClose();
  }
}