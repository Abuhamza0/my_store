import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'image_upload_service.dart';
import '../../features/store_service/customer_controller.dart';
import '../../features/store_service/order_controller.dart';
import '../../features/store_service/product_controller.dart';
import 'store_id_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  Timer? _autoSyncTimer;
  Timer? _ordersTimer;
  Timer? _backupTimer;

  // مراقبة حالة المزامنة
  final isSyncing = false.obs;
  final lastSyncTime = Rx<DateTime?>(null);
  final syncError = Rx<String?>(null);

  // ✅ استخدام دالة للحصول على storeId بدلاً من متغير ثابت
  String get storeId => _getStoreId();

  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    stopAutoSync();

    try {
      if (!Hive.isBoxOpen('customers') || !Hive.isBoxOpen('orders')) {
        return;
      }
    } catch (e) {
      return;
    }

    // ✅ 1. جلب العملاء والطلبات بعد 3 ثواني
    Future.delayed(const Duration(seconds: 3), () async {
      await _fetchCustomersAndOrdersSilently();
    });

    // ✅ 2. جلب العملاء والطلبات كل 30 ثانية
    _ordersTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _fetchCustomersAndOrdersSilently();
    });

    // ✅ 3. رفع دوري بدون حذف (كل 5 دقائق)
    _autoSyncTimer = Timer.periodic(interval, (_) async {
      await syncAllData();
    });
    // ✅ النسخ الاحتياطي التلقائي كل 6 ساعات
    _backupTimer = Timer.periodic(const Duration(hours: 6), (_) async {
      await createBackupIfConnected();
    });
  }

  /// ✅ الحصول على store_id من UID مباشرة
  String _getStoreId() {
    try {
      // 1. الأولوية القصوى: قراءة uid من الحساب
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        return uid;
      }

      // 2. احتياطي: قراءة store_id من Hive
      final storedId = Hive.box('settings').get('store_id', defaultValue: '')?.toString() ?? '';
      if (storedId.isNotEmpty && storedId != 'default_store') {
        return storedId;
      }

      // 3. من StoreIdService
      return StoreIdService.getStoreId();
    } catch (e) {
      print('❌ خطأ في جلب storeId: $e');
      return '';
    }
  }

  /// ✅ فحص وجود بيانات غير متوافقة في Hive
  bool _hasIncompatibleData(String boxName, String storeId) {
    try {
      if (!Hive.isBoxOpen(boxName)) return false;
      final box = Hive.box(boxName);

      for (var key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final dataStoreId = data['store_id']?.toString() ?? data['storeId']?.toString() ?? '';
          if (dataStoreId.isNotEmpty && dataStoreId != storeId) {
            return true; // وجدنا بيانات لا تتوافق
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// ✅ إظهار رسالة تأكيد قبل مسح البيانات
  Future<bool> _showIncompatibleDataDialog(String boxName) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('⚠️ تنبيه!'),
        content: const Text(
          'البيانات غير متوافقة .. لا يمكن خلط البيانات\n\n'
              'يوجد بيانات قديمة لا تتوافق مع معرف المتجر الحالي.\n'
              'هل تريد مسح البيانات القديمة وجلب بيانات المتجر الحالي؟',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('مسح وجلب'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    return result ?? false;
  }

  /// ✅ جلب العملاء والطلبات بصمت (بدون حذف)
  Future<void> _fetchCustomersAndOrdersSilently() async {
    try {
      // 🛑 حماية قوية: إذا لم يوجد storeId صحيح، لا نجلب أي شيء
      final storeId = _getStoreId();
      if (storeId.isEmpty || storeId == 'default_store' || storeId == 'store_') {
        print('⚠️ storeId غير صالح - تخطي جلب العملاء');
        return;
      }

      // ✅ فحص البيانات غير المتوافقة في customers
      if (_hasIncompatibleData('customers', storeId)) {
        final shouldClear = await _showIncompatibleDataDialog('customers');
        if (!shouldClear) {
          print('🚫 تم إلغاء جلب العملاء بسبب عدم التوافق');
          return;
        }
        // مسح البيانات القديمة
        await Hive.box('customers').clear();
      }

      // ✅ جلب العملاء بشرط store_id فقط (بدون أي خطة احتياطية تسبب مشكلة)
      QuerySnapshot customersSnapshot;
      try {
        customersSnapshot = await _firestore
            .collection('customers')
            .where('store_id', isEqualTo: storeId)
            .get()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('❌ فشل جلب العملاء بـ store_id: $e');
        return; // 🛑 لا نجلب أي شيء إذا فشل الاستعلام
      }

      final customersBox = Hive.box('customers');

      for (var doc in customersSnapshot.docs) {
        final raw = doc.data();
        final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        data.remove('store_id');
        data.remove('storeId');

        if (!data.containsKey('lastActive')) {
          data['lastActive'] = null;
        }

        await customersBox.put(doc.id, _processFirebaseData(data));
      }

      if (Get.isRegistered<CustomerController>()) {
        Get.find<CustomerController>().loadCustomers();
      }

      print('🔇 عملاء: ${customersSnapshot.docs.length}');
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  /// ✅ جلب الطلبات فقط (بدون حذف)
  Future<void> _fetchOrdersOnly() async {
    try {
      final storeId = _getStoreId();
      if (storeId.isEmpty || storeId == 'default_store' || storeId == 'store_') {
        print('⚠️ storeId غير صالح - تخطي جلب الطلبات');
        return;
      }

      // ✅ فحص البيانات غير المتوافقة في orders
      if (_hasIncompatibleData('orders', storeId)) {
        final shouldClear = await _showIncompatibleDataDialog('orders');
        if (!shouldClear) {
          print('🚫 تم إلغاء جلب الطلبات بسبب عدم التوافق');
          return;
        }
        // مسح البيانات القديمة
        await Hive.box('orders').clear();
      }

      final snapshot = await _firestore
          .collection('orders')
          .where('store_id', isEqualTo: storeId)
          .get()
          .timeout(const Duration(seconds: 10));

      final box = Hive.box('orders');

      for (var doc in snapshot.docs) {
        final rawData = doc.data();
        final data = <String, dynamic>{};
        (rawData as Map).forEach((key, value) {
          data[key.toString()] = value;
        });
        data.remove('store_id');
        await box.put(doc.id, _processFirebaseData(data));
      }

      if (Get.isRegistered<OrderController>()) {
        Get.find<OrderController>().loadOrders();
      }

      print('✅ جلب ${snapshot.docs.length} طلب');
    } catch (e) {
      print('❌ خطأ في جلب الطلبات: $e');
    }
  }

  /// ✅ جلب بدون مسح (إضافة/تحديث فقط) - **مصحح ليمنع جلب جميع العملاء**
  Future<void> _fetchCollectionNoClear(String collectionName, String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) return;

      // 🛑 حماية قوية: إذا لم يوجد storeId صحيح، لا نجلب أي شيء
      final storeId = _getStoreId();
      if (storeId.isEmpty || storeId == 'default_store' || storeId == 'store_') {
        print('⚠️ storeId غير صالح - تخطي $collectionName');
        return;
      }

      // ✅ فحص البيانات غير المتوافقة في Hive
      if (_hasIncompatibleData(boxName, storeId)) {
        final shouldClear = await _showIncompatibleDataDialog(boxName);
        if (!shouldClear) {
          print('🚫 تم إلغاء جلب $collectionName بسبب عدم التوافق');
          return;
        }
        // مسح البيانات القديمة غير المتوافقة فقط
        await _clearIncompatibleData(boxName, storeId);
      }

      final box = Hive.box(boxName);
      QuerySnapshot snapshot;
      try {
        // ✅ جلب فقط باستخدام store_id (بدون خطة احتياطية خطيرة)
        snapshot = await _firestore
            .collection(collectionName)
            .where('store_id', isEqualTo: storeId)
            .get()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        print('❌ فشل جلب $collectionName بـ store_id: $e');
        return; // 🛑 لا نجلب أي شيء إذا فشل الاستعلام
      }

      if (snapshot.docs.isEmpty) return;

      for (var doc in snapshot.docs) {
        try {
          final rawData = doc.data();
          if (rawData == null) continue;
          final data = <String, dynamic>{};
          (rawData as Map).forEach((key, value) {
            data[key.toString()] = value;
          });
          data.remove('store_id');
          data.remove('storeId');
          data.remove('doc_id');
          final processedData = _processFirebaseData(data);
          await box.put(doc.id, processedData);
        } catch (e) {
          print('❌ خطأ: $e');
        }
      }

      print('✅ تم جلب ${snapshot.docs.length} من $collectionName (بدون مسح)');
    } catch (e) {
      print('❌ خطأ في جلب $collectionName: $e');
    }
  }

  /// ✅ مسح البيانات غير المتوافقة فقط (وليس كل البيانات)
  Future<void> _clearIncompatibleData(String boxName, String storeId) async {
    try {
      if (!Hive.isBoxOpen(boxName)) return;
      final box = Hive.box(boxName);

      final keysToDelete = <dynamic>[];
      for (var key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          final dataStoreId = data['store_id']?.toString() ?? data['storeId']?.toString() ?? '';
          if (dataStoreId.isNotEmpty && dataStoreId != storeId) {
            keysToDelete.add(key);
          }
        }
      }

      for (var key in keysToDelete) {
        await box.delete(key);
      }

      print('🗑️ تم مسح ${keysToDelete.length} عنصر غير متوافق من $boxName');
    } catch (e) {
      print('❌ خطأ في مسح البيانات غير المتوافقة: $e');
    }
  }

  /// ✅ إعادة تحميل المتحكمات بصمت
  void _reloadControllersAfterFetch() {
    try {
      if (Get.isRegistered<ProductController>()) {
        Get.find<ProductController>().loadProducts();
      }
      if (Get.isRegistered<CustomerController>()) {
        Get.find<CustomerController>().loadCustomers();
      }
      if (Get.isRegistered<OrderController>()) {
        Get.find<OrderController>().loadOrders();
      }
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  /// إيقاف المزامنة التلقائية
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _ordersTimer?.cancel();
    _backupTimer?.cancel();
    _autoSyncTimer = null;
    _ordersTimer = null;
    _backupTimer = null;
  }

  Future<void> createBackupIfConnected() async {
    try {
      final hasConnection = await checkConnectivity();
      if (!hasConnection) return;

      await createBackup();
      print('✅ نسخة احتياطية تلقائية تمت');
    } catch (e) {
      print('❌ فشل النسخ الاحتياطي التلقائي: $e');
    }
  }

  /// ✅ المزامنة الكاملة (رفع فقط بدون حذف)
  Future<bool> syncAllData() async {
    try {
      if (!Hive.isBoxOpen('products') ||
          !Hive.isBoxOpen('customers') ||
          !Hive.isBoxOpen('orders') ||
          !Hive.isBoxOpen('settings')) {
        print('⚠️ Hive boxes not open, cannot sync');
        syncError.value = 'صناديق البيانات غير جاهزة';
        return false;
      }
    } catch (e) {
      print('❌ Hive error: $e');
      return false;
    }

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        syncError.value = 'لا يوجد اتصال بالإنترنت';
        return false;
      }
    } catch (e) {
      print('❌ Connectivity check error: $e');
    }

    isSyncing.value = true;
    syncError.value = null;

    try {
      await _uploadProductImages();
      await _syncBox('products', 'products');
      await _syncBox('customers', 'customers');
      await _syncBox('orders', 'orders');
      await _syncSettings();
      await _syncCategories();

      lastSyncTime.value = DateTime.now();
      isSyncing.value = false;
      await createBackup();
      print('✅ تمت المزامنة (رفع بدون حذف) في ${DateTime.now()}');
      return true;
    } catch (e) {
      syncError.value = 'خطأ في المزامنة: $e';
      isSyncing.value = false;
      print('❌ خطأ في المزامنة: $e');
      return false;
    }
  }

  /// ✅ جلب البيانات من Firebase (بدون مسح محلي)
  Future<bool> fetchAllData({String? storeId}) async {
    final effectiveStoreId = storeId ?? _getStoreId();
    isSyncing.value = true;
    syncError.value = null;

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        syncError.value = 'لا يوجد اتصال بالإنترنت';
        isSyncing.value = false;
        return false;
      }

      print('🔄 بدء جلب البيانات من Firebase...');

      if (!Hive.isBoxOpen('products') ||
          !Hive.isBoxOpen('customers') ||
          !Hive.isBoxOpen('orders') ||
          !Hive.isBoxOpen('settings')) {
        syncError.value = 'صناديق البيانات غير جاهزة';
        isSyncing.value = false;
        return false;
      }

      int successCount = 0;
      int failCount = 0;

      try {
        await _fetchCollectionNoClear('products', 'products');
        successCount++;
      } catch (e) {
        failCount++;
        print('❌ المنتجات: $e');
      }

      try {
        await _fetchCollectionNoClear('customers', 'customers');
        successCount++;
      } catch (e) {
        failCount++;
        print('❌ العملاء: $e');
      }

      try {
        await _fetchCollectionNoClear('orders', 'orders');
        successCount++;
      } catch (e) {
        failCount++;
        print('❌ الطلبات: $e');
      }

      try {
        await _fetchCategories();
        successCount++;
      } catch (e) {
        failCount++;
      }

      try {
        await _fetchSettings();
        successCount++;
      } catch (e) {
        failCount++;
      }

      lastSyncTime.value = DateTime.now();
      isSyncing.value = false;
      await createBackup();

      print('✅ تم الجلب: $successCount نجاح, $failCount فشل');
      return successCount > 0;
    } catch (e) {
      syncError.value = 'خطأ: $e';
      isSyncing.value = false;
      return false;
    }
  }

  /// ✅ رفع صورة إلى Firebase Storage
  Future<String?> _uploadImageToStorage(String imagePath, String folder) async {
    try {
      if (imagePath.isEmpty || imagePath.startsWith('http') || imagePath.startsWith('assets/')) {
        return imagePath;
      }

      final file = File(imagePath);
      if (!await file.exists()) return imagePath;

      final storeId = _getStoreId();
      final fileName = imagePath.split('/').last;
      final ref = _storage.ref('stores/$storeId/$folder/$fileName');

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('❌ خطأ في رفع الصورة: $e');
      return imagePath;
    }
  }

  /// ✅ رفع صور المنتجات
  Future<void> _uploadProductImages() async {
    if (kIsWeb) return;

    final productsBox = Hive.box('products');

    for (var key in productsBox.keys) {
      final data = productsBox.get(key);
      if (data != null && data is Map) {
        final imagePath = data['imagePath']?.toString() ?? '';

        if (imagePath.startsWith('assets/') || imagePath.startsWith('http')) {
          continue;
        }

        try {
          final file = File(imagePath);
          if (await file.exists()) {
            final ref = FirebaseStorage.instance.ref('products/$key.jpg');
            await ref.putFile(file);
            final url = await ref.getDownloadURL();
            data['imagePath'] = url;
            await productsBox.put(key, data);
          }
        } catch (e) {
          print('❌ خطأ في رفع الصورة: $e');
        }
      }
    }
  }

  /// مزامنة التقسيمات والتبويبات (رفع فقط بدون حذف)
  Future<void> _syncCategories() async {
    try {
      final settingsBox = Hive.box('settings');
      final categoriesData = settingsBox.get('custom_categories_data');
      if (categoriesData == null) return;

      final storeId = _getStoreId();

      final processedData = await _processImagesInCategories(categoriesData);

      await _firestore
          .collection('categories')
          .doc(storeId)
          .set({
        'custom_categories_data': processedData,
        'updated_at': FieldValue.serverTimestamp(),
        'store_id': storeId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ خطأ في رفع التقسيمات: $e');
    }
  }

  Future<dynamic> _processImagesInCategories(dynamic data) async {
    if (data is List) {
      final result = [];
      for (var item in data) {
        result.add(await _processImagesInCategories(item));
      }
      return result;
    } else if (data is Map) {
      final result = <String, dynamic>{};
      for (var entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (key == 'imagePath' && value is String && value.startsWith('data:image')) {
          final uploadedUrl = await _uploadBase64Image(value, 'categories');
          result[key] = uploadedUrl ?? value;
        } else {
          result[key] = await _processImagesInCategories(value);
        }
      }
      return result;
    }
    return data;
  }

  Future<String?> _uploadBase64Image(String base64Data, String folder) async {
    try {
      final imageService = ImageUploadService();
      final bytes = base64Decode(base64Data.split(',').last);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await imageService.uploadBytes(
        bytes: bytes,
        fileName: fileName,
        folder: folder,
      );
      return url;
    } catch (e) {
      print('❌ فشل رفع Base64: $e');
      return null;
    }
  }

  Future<void> createBackup() async {
    try {
      final storeId = _getStoreId();
      final settingsBox = Hive.box('settings');
      final productsBox = Hive.box('products');
      final customersBox = Hive.box('customers');
      final ordersBox = Hive.box('orders');

      final backupData = {
        'products': productsBox.toMap(),
        'customers': customersBox.toMap(),
        'orders': ordersBox.toMap(),
        'custom_categories_data': settingsBox.get('custom_categories_data', defaultValue: []),
        'store_settings': {
          'store_name': settingsBox.get('store_name'),
          'currency': settingsBox.get('currency'),
          'language': settingsBox.get('language'),
          'darkMode': settingsBox.get('darkMode'),
        },
        'timestamp': FieldValue.serverTimestamp(),
        'store_id': storeId,
      };

      await _firestore
          .collection('store_backups')
          .doc(storeId)
          .set(backupData, SetOptions(merge: true));

      print('✅ تم إنشاء نسخة احتياطية');
    } catch (e) {
      print('❌ فشل إنشاء نسخة احتياطية: $e');
    }
  }

  /// جلب التقسيمات والتبويبات (بدون مسح)
  Future<void> _fetchCategories() async {
    try {
      final storeId = _getStoreId();
      final doc = await _firestore
          .collection('categories')
          .doc(storeId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('custom_categories_data')) {
          final categoriesData = _processFirebaseData(data['custom_categories_data']);
          final settingsBox = Hive.box('settings');
          await settingsBox.put('custom_categories_data', categoriesData);
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب التقسيمات: $e');
    }
  }

  /// ✅ مزامنة صندوق Hive بدون حذف (رفع فقط)
  Future<void> _syncBox(String boxName, String collectionName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) return;
      final box = Hive.box(boxName);
      final storeId = _getStoreId(); // ✅ من الخدمة الموحدة
      if (storeId.isEmpty || storeId == 'default_store' || storeId == 'store_') {
        print('⚠️ storeId غير صالح - تخطي الرفع');
        return;
      }

      final collectionRef = _firestore.collection(collectionName);
      for (var key in box.keys) {
        try {
          final data = box.get(key);
          if (data != null) {
            final docRef = collectionRef.doc(key.toString());
            final firestoreData = _prepareDataForFirestore(data);
            if (firestoreData is Map) {
              firestoreData['store_id'] = storeId;
              firestoreData.remove('storeId'); // ✅ إزالة الحقل القديم إن وجد
            }
            await docRef.set(firestoreData, SetOptions(merge: true))
                .timeout(const Duration(seconds: 5));
          }
        } catch (e) {
          print('⚠️ Error syncing $key: $e');
        }
      }
    } catch (e) {
      print('❌ خطأ في مزامنة $boxName: $e');
    }
  }

  /// ✅ مزامنة الإعدادات (رفع فقط بدون store_email و store_id)
  Future<void> _syncSettings() async {
    try {
      final settingsBox = Hive.box('settings');
      final storeId = _getStoreId();

      if (storeId.isEmpty || storeId == 'default_store' || storeId == 'store_') {
        print('⚠️ storeId فارغ - تخطي');
        return;
      }

      final keysToSync = [
        'store_name',
        'store_description',
        'store_logo',
        'currency',
        'language',
        'darkMode',
        'store_phone',
        'store_address',
        'custom_categories_data',
        'trial_end_date',
        'store_subscribed',
        'subscription_type',
        'tax_rate',
        'delivery_fee',
      ];

      final storeSettings = <String, dynamic>{};
      for (var key in keysToSync) {
        final value = settingsBox.get(key);
        if (value != null) {
          storeSettings[key] = _prepareDataForFirestore(value);
        }
      }

      await _firestore
          .collection('settings')
          .doc(storeId)
          .set(storeSettings, SetOptions(merge: true));
    } catch (e) {
      print('❌ خطأ في مزامنة الإعدادات: $e');
    }
  }

  /// ✅ جلب الإعدادات (بدون مسح store_email و store_id)
  Future<void> _fetchSettings() async {
    try {
      final storeId = _getStoreId();
      final doc = await _firestore
          .collection('settings')
          .doc(storeId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final settingsBox = Hive.box('settings');

        for (var entry in data.entries) {
          final key = entry.key.toString();
          if (key == 'store_email' || key == 'store_id' || key == 'updated_at') {
            continue;
          }
          settingsBox.put(key, _processFirebaseData(entry.value));
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب الإعدادات: $e');
    }
  }

  /// ✅ جلب من السحابة بدون مسح
  Future<void> _fetchCollection(String collectionName, String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) return;
      final box = Hive.box(boxName);
      final storeId = _getStoreId();
      if (storeId.isEmpty || storeId == 'default_store' || storeId == 'store_') return;

      // ✅ فحص البيانات غير المتوافقة
      if (_hasIncompatibleData(boxName, storeId)) {
        final shouldClear = await _showIncompatibleDataDialog(boxName);
        if (!shouldClear) {
          return;
        }
        await _clearIncompatibleData(boxName, storeId);
      }

      QuerySnapshot snapshot;
      try {
        // ✅ استخدم فقط store_id
        snapshot = await _firestore
            .collection(collectionName)
            .where('store_id', isEqualTo: storeId)
            .get()
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        // 🛑 لا تجلب أي شيء إذا فشل الاستعلام
        return;
      }

      if (snapshot.docs.isEmpty) return;

      for (var doc in snapshot.docs) {
        final rawData = doc.data();
        if (rawData is! Map) continue;
        final data = Map<String, dynamic>.from(rawData);
        data.remove('store_id');
        data.remove('storeId');
        await box.put(doc.id, _processFirebaseData(data));
      }
    } catch (e) {
      print('❌ خطأ في جلب $collectionName: $e');
    }
  }

  /// معالجة وتحويل البيانات من Firebase إلى تنسيق Hive
  dynamic _processFirebaseData(dynamic data) {
    if (data == null) return null;
    if (data is bool) return data;
    if (data is int || data is double || data is num) return data;

    if (data is String) {
      final lower = data.toLowerCase().trim();
      if (lower == 'true') return true;
      if (lower == 'false') return false;

      final intValue = int.tryParse(data);
      if (intValue != null) return intValue;

      final doubleValue = double.tryParse(data);
      if (doubleValue != null) return doubleValue;

      return data;
    }

    if (data is Map) {
      final processed = <dynamic, dynamic>{};
      data.forEach((key, value) {
        dynamic processedKey = key;
        if (key is String) {
          final intKey = int.tryParse(key);
          if (intKey != null) {
            processedKey = intKey;
          }
        }
        processed[processedKey] = _processFirebaseData(value);
      });
      return processed;
    }

    if (data is List) {
      return data.map((e) => _processFirebaseData(e)).toList();
    }

    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    }

    if (data is DateTime) {
      return data.toIso8601String();
    }

    return data.toString();
  }

  /// تنظيف البيانات في Hive (بدون مسح - فقط تصحيح الأنواع)
  Future<void> _cleanHiveBox(String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) return;

      final box = Hive.box(boxName);
      final keysToFix = <dynamic>[];

      for (var key in box.keys) {
        final data = box.get(key);
        var hasInvalidData = false;

        if (data is Map) {
          data.forEach((k, v) {
            if (v is String &&
                (v.toLowerCase() == 'true' || v.toLowerCase() == 'false')) {
              hasInvalidData = true;
            }
          });
        } else if (data is String &&
            (data.toLowerCase() == 'true' ||
                data.toLowerCase() == 'false')) {
          hasInvalidData = true;
        }

        if (hasInvalidData) {
          keysToFix.add(key);
        }
      }

      if (keysToFix.isNotEmpty) {
        for (var key in keysToFix) {
          final data = box.get(key);
          final fixedData = _processFirebaseData(data);
          await box.put(key, fixedData);
        }
        print('🔧 تم إصلاح ${keysToFix.length} عنصر في $boxName');
      }
    } catch (e) {
      print('❌ خطأ في تنظيف $boxName: $e');
    }
  }

  /// تجهيز البيانات لـ Firestore
  dynamic _prepareDataForFirestore(dynamic data) {
    if (data == null) return null;
    if (data is bool) return data;
    if (data is int || data is double || data is num) return data;
    if (data is String) return data;

    if (data is DateTime) return Timestamp.fromDate(data);

    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final stringKey = key.toString();
        result[stringKey] = _prepareDataForFirestore(value);
      });
      return result;
    }

    if (data is List) {
      return data.map((e) => _prepareDataForFirestore(e)).toList();
    }

    return data.toString();
  }

  /// إصلاح جميع البيانات
  Future<bool> fixAllData() async {
    try {
      final boxes = ['products', 'customers', 'orders', 'settings'];

      for (var boxName in boxes) {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          final keys = box.keys.toList();

          for (var key in keys) {
            final data = box.get(key);
            if (data != null) {
              final fixedData = _fixDataTypes(data);
              await box.put(key, fixedData);
            }
          }
        }
      }

      final settingsBox = Hive.box('settings');
      await settingsBox.put('needs_data_fix', false);
      print('✅ تم إصلاح جميع البيانات بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في إصلاح البيانات: $e');
      return false;
    }
  }

  /// إصلاح أنواع البيانات
  dynamic _fixDataTypes(dynamic data) {
    if (data == null) return null;
    if (data is bool) return data;
    if (data is int || data is double || data is num) return data;

    if (data is String) {
      final lower = data.toLowerCase().trim();
      if (lower == 'true') return true;
      if (lower == 'false') return false;

      final intValue = int.tryParse(data);
      if (intValue != null) return intValue;

      final doubleValue = double.tryParse(data);
      if (doubleValue != null) return doubleValue;

      return data;
    }

    if (data is Map) {
      final fixed = <dynamic, dynamic>{};
      data.forEach((key, value) {
        fixed[key] = _fixDataTypes(value);
      });
      return fixed;
    }

    if (data is List) {
      return data.map((e) => _fixDataTypes(e)).toList();
    }

    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    }

    if (data is DateTime) {
      return data.toIso8601String();
    }

    return data;
  }

  /// الحصول على حالة الاتصال
  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('❌ خطأ في فحص الاتصال: $e');
      return false;
    }
  }

  Future<bool> restoreBackup() async {
    try {
      final storeId = _getStoreId();
      final doc = await _firestore
          .collection('store_backups')
          .doc(storeId)
          .get();

      if (!doc.exists || doc.data() == null) {
        print('⚠️ لا توجد نسخة احتياطية');
        return false;
      }

      final data = doc.data()!;

      if (data['products'] != null && data['products'] is Map) {
        final productsBox = Hive.box('products');
        await productsBox.clear();
        (data['products'] as Map).forEach((key, value) {
          productsBox.put(key, value);
        });
        if (Get.isRegistered<ProductController>()) {
          Get.find<ProductController>().loadProducts();
        }
      }

      if (data['customers'] != null && data['customers'] is Map) {
        final customersBox = Hive.box('customers');
        await customersBox.clear();
        (data['customers'] as Map).forEach((key, value) {
          customersBox.put(key, value);
        });
        if (Get.isRegistered<CustomerController>()) {
          Get.find<CustomerController>().loadCustomers();
        }
      }

      if (data['custom_categories_data'] != null) {
        await Hive.box('settings').put('custom_categories_data', data['custom_categories_data']);
      }

      print('✅ تمت استعادة النسخة الاحتياطية بنجاح');
      return true;
    } catch (e) {
      print('❌ فشل استعادة النسخة: $e');
      return false;
    }
  }
}