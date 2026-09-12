// ================== ملف: customer_account_manager.dart ==================
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ للرفع السحابي
import 'package:connectivity_plus/connectivity_plus.dart'; // ✅ للتحقق من الاتصال
import 'customer_model.dart';
import 'customer_controller.dart';

/// ✅ الكلاس المسؤول عن إدارة حسابات العملاء وحفظ أرقام الهواتف
/// مع الرفع التلقائي للسحابة
class CustomerAccountManager extends GetxController {
  // ============ المتغيرات ============
  final CustomerController _customerController = Get.find<CustomerController>();
  final Box _settingsBox = Hive.box('settings');
  final Box _phonesBox = Hive.box('phones'); // ✅ بوكس خاص لأرقام الهواتف

  // قائمة أرقام الهواتف المضافة (للمراقبة)
  final addedPhones = <String>[].obs;

  // حالة الاتصال بالسحابة
  final isCloudConnected = false.obs;
  final isSyncing = false.obs;

  // إعدادات Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ التهيئة ============
  @override
  void onInit() {
    super.onInit();
    _loadSavedPhones();
    _initCloudConnection();
  }

  /// تحميل أرقام الهواتف المحفوظة محلياً
  void _loadSavedPhones() {
    final savedPhones = _phonesBox.get('added_phones', defaultValue: <String>[]);
    if (savedPhones is List) {
      addedPhones.assignAll(savedPhones.cast<String>());
    }
  }

  /// مراقبة الاتصال بالسحابة
  void _initCloudConnection() {
    Connectivity().onConnectivityChanged.listen((result) {
      final connected = result != ConnectivityResult.none;
      isCloudConnected.value = connected;

      if (connected) {
        syncPendingData(); // ✅ مزامنة تلقائية عند عودة الاتصال
      }
    });

    // التحقق الأولي
    Connectivity().checkConnectivity().then((result) {
      isCloudConnected.value = result != ConnectivityResult.none;
    });
  }

  // ============ 1️⃣ إضافة رقم هاتف جديد ============
  /// حفظ رقم الهاتف محلياً وفورياً على السحابة
  Future<bool> addPhoneNumber(String phone) async {
    try {
      // تطهير الرقم
      final cleanPhone = _cleanPhone(phone);

      // التحقق من عدم التكرار
      if (addedPhones.contains(cleanPhone)) {
        Get.snackbar(
          'تنبيه',
          'رقم الهاتف موجود مسبقاً',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      }

      // ✅ حفظ محلياً
      addedPhones.add(cleanPhone);
      _phonesBox.put('added_phones', addedPhones.toList());

      // ✅ رفع للسحابة فوراً
      await _uploadPhoneToCloud(cleanPhone);

      Get.snackbar(
        '✅ تم',
        'تم حفظ رقم الهاتف بنجاح',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      return true;

    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل حفظ رقم الهاتف: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  /// حذف رقم هاتف
  Future<void> removePhoneNumber(String phone) async {
    final cleanPhone = _cleanPhone(phone);
    addedPhones.remove(cleanPhone);
    _phonesBox.put('added_phones', addedPhones.toList());

    // حذف من السحابة
    await _deletePhoneFromCloud(cleanPhone);
  }

  // ============ 2️⃣ إنشاء حساب جديد ============
  /// إنشاء حساب عميل جديد (مع التحقق من عدم وجود الحساب مسبقاً)
  Future<Customer?> createAccount({
    required String phone,
    required String name,
    required String password,
  }) async {
    try {
      final cleanPhone = _cleanPhone(phone);
      final cc = _customerController;

      // ✅ التحقق من وجود العميل في النظام
      final existingCustomer = cc.customers.firstWhereOrNull(
            (c) => c.phone == cleanPhone && c.isActive,
      );

      if (existingCustomer == null) {
        Get.snackbar(
          'خطأ',
          'رقم الهاتف غير مسجل في النظام',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return null;
      }

      // ✅ التحقق من عدم وجود حساب مسبق
      if (existingCustomer.password.isNotEmpty) {
        Get.snackbar(
          'تنبيه',
          'الحساب موجود مسبقاً، يرجى تسجيل الدخول',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return null;
      }

      // ✅ التحقق من كلمة المرور
      if (password.length < 6) {
        Get.snackbar(
          'خطأ',
          'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return null;
      }

      // ✅ إنشاء الحساب
      final updatedCustomer = Customer(
        id: existingCustomer.id,
        name: name,
        phone: existingCustomer.phone,
        password: Customer.hashPassword(password),
        isActive: true,
        loginMethod: 'credentials',
      );

      // ✅ تحديث في قاعدة البيانات المحلية
      await cc.updateCustomer(updatedCustomer);

      // ✅ رفع للسحابة فوراً
      await _uploadAccountToCloud(updatedCustomer);

      // ✅ حفظ الجلسة
      _saveSession(updatedCustomer);

      Get.snackbar(
        '🎉 تم بنجاح!',
        'تم إنشاء الحساب بنجاح',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      return updatedCustomer;

    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل إنشاء الحساب: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  // ============ 3️⃣ الرفع التلقائي للسحابة ============
  /// رفع رقم هاتف للسحابة
  Future<void> _uploadPhoneToCloud(String phone) async {
    if (!isCloudConnected.value) {
      _addToPendingQueue('phone', phone);
      return;
    }

    try {
      isSyncing.value = true;

      await _firestore.collection('phones').doc(phone).set({
        'phone': phone,
        'added_at': FieldValue.serverTimestamp(),
        'store_id': _settingsBox.get('store_id', defaultValue: ''),
      }, SetOptions(merge: true));

      isSyncing.value = false;

    } catch (e) {
      isSyncing.value = false;
      _addToPendingQueue('phone', phone);
      debugPrint('❌ فشل رفع الهاتف: $e');
    }
  }

  /// رفع حساب للسحابة
  Future<void> _uploadAccountToCloud(Customer customer) async {
    if (!isCloudConnected.value) {
      _addToPendingQueue('account', customer.toJson());
      return;
    }

    try {
      isSyncing.value = true;

      await _firestore.collection('customers').doc(customer.id).set({
        'id': customer.id,
        'name': customer.name,
        'phone': customer.phone,
        'is_active': customer.isActive,
        'login_method': customer.loginMethod,
        'created_at': FieldValue.serverTimestamp(),
        'store_id': _settingsBox.get('store_id', defaultValue: ''),
      }, SetOptions(merge: true));

      isSyncing.value = false;

    } catch (e) {
      isSyncing.value = false;
      _addToPendingQueue('account', customer.toJson());
      debugPrint('❌ فشل رفع الحساب: $e');
    }
  }

  /// حذف رقم من السحابة
  Future<void> _deletePhoneFromCloud(String phone) async {
    if (!isCloudConnected.value) return;

    try {
      await _firestore.collection('phones').doc(phone).delete();
    } catch (e) {
      debugPrint('❌ فشل حذف الهاتف: $e');
    }
  }

  // ============ قائمة الانتظار للمزامنة ============
  /// إضافة عنصر لقائمة الانتظار (عند عدم وجود اتصال)
  void _addToPendingQueue(String type, dynamic data) {
    final queue = _settingsBox.get('sync_queue', defaultValue: <Map>[]);
    if (queue is List) {
      queue.add({
        'type': type,
        'data': data is String ? data : Map<String, dynamic>.from(data as Map),
        'timestamp': DateTime.now().toIso8601String(),
      });
      _settingsBox.put('sync_queue', queue);
    }
  }

  /// مزامنة البيانات المعلقة عند عودة الاتصال
  Future<void> syncPendingData() async {
    if (!isCloudConnected.value || isSyncing.value) return;

    final queue = _settingsBox.get('sync_queue', defaultValue: <Map>[]);
    if (queue.isEmpty) return;

    isSyncing.value = true;
    final failedItems = <Map>[];

    for (var item in queue) {
      try {
        if (item['type'] == 'phone') {
          await _uploadPhoneToCloud(item['data'] as String);
        } else if (item['type'] == 'account') {
          // إعادة رفع الحساب
          await _firestore.collection('customers')
              .doc(item['data']['id'])
              .set(item['data'], SetOptions(merge: true));
        }
      } catch (e) {
        failedItems.add(item);
      }
    }

    // إعادة وضع الفاشلة في قائمة الانتظار
    _settingsBox.put('sync_queue', failedItems);
    isSyncing.value = false;
  }

  // ============ دوال مساعدة ============
  /// تنظيف رقم الهاتف
  String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '').trim();
  }

  /// حفظ جلسة تسجيل الدخول
  void _saveSession(Customer customer) {
    _settingsBox.put('store_customer_phone', customer.phone);
    _settingsBox.put('store_customer_password', customer.password);
    _settingsBox.put('store_remember_me', true);
  }

  /// مسح الجلسة
  void clearSession() {
    _settingsBox.delete('store_customer_phone');
    _settingsBox.delete('store_customer_password');
    _settingsBox.put('store_remember_me', false);
  }

  /// التحقق من وجود حساب
  bool hasAccount(String phone) {
    final cleanPhone = _cleanPhone(phone);
    final customer = _customerController.customers.firstWhereOrNull(
          (c) => c.phone == cleanPhone && c.isActive,
    );
    return customer != null && customer.password.isNotEmpty;
  }

  /// جلب حساب عن طريق الهاتف
  Customer? getAccountByPhone(String phone) {
    final cleanPhone = _cleanPhone(phone);
    return _customerController.customers.firstWhereOrNull(
          (c) => c.phone == cleanPhone && c.isActive,
    );
  }
}