// sync_service.dart
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

  // ═══════════════════════════════════════════════════════════
  //  🔑 معرّفات
  // ═══════════════════════════════════════════════════════════
  String get storeId => _getStoreId();

  String _getStoreId() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) return uid;

      final storedId = Hive.box('settings')
          .get('store_id', defaultValue: '')
          ?.toString() ?? '';
      if (storedId.isNotEmpty && storedId != 'default_store') {
        return storedId;
      }

      return StoreIdService.getStoreId();
    } catch (e) {
      print('❌ خطأ في جلب storeId: $e');
      return '';
    }
  }

  bool _isValidStoreId(String id) {
    return id.isNotEmpty &&
        id != 'default_store' &&
        id != 'store_' &&
        id != 'demo';
  }

  // ═══════════════════════════════════════════════════════════
  //  ⏰ بدء المزامنة التلقائية
  //  - جلب أولي بعد 3 ثواني (بدون حذف)
  //  - أول رفع بعد 3 ساعات
  //  - رفع دوري كل 5 دقائق بعد ذلك
  // ═══════════════════════════════════════════════════════════
  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    stopAutoSync();

    try {
      if (!Hive.isBoxOpen('customers') || !Hive.isBoxOpen('orders')) {
        return;
      }
    } catch (e) {
      return;
    }

    // ─── 1. جلب كل شيء من السحابة أولاً (بعد 3 ثواني) ───
    Future.delayed(const Duration(seconds: 3), () async {
      await _initialFetchAll();
    });

    // ─── 2. جلب الطلبات + الإشعارات + العملاء كل 30 ثانية ───
    _ordersTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _fetchOrdersSilently();
      await _fetchNotifications();
    });

    // ─── 3. أول رفع تلقائي بعد 3 ساعات ───
    print('⏰ [AutoSync] أول رفع تلقائي بعد 3 ساعات');
    _autoSyncTimer = Timer(const Duration(hours: 3), () async {
      print('🚀 [AutoSync] بدء أول رفع تلقائي...');
      await syncAllData();

      // ✅ بعد أول رفع، استمر كل 5 دقائق
      _autoSyncTimer = Timer.periodic(interval, (_) async {
        await syncAllData();
      });
    });

    // ─── 4. النسخ الاحتياطي كل 6 ساعات ───
    _backupTimer = Timer.periodic(const Duration(hours: 6), (_) async {
      await createBackupIfConnected();
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _ordersTimer?.cancel();
    _backupTimer?.cancel();
    _autoSyncTimer = null;
    _ordersTimer = null;
    _backupTimer = null;
  }

  // ═══════════════════════════════════════════════════════════
  //  📥 الجلب الأولي الكامل (بدون حذف أي شيء)
  // ═══════════════════════════════════════════════════════════
  Future<void> _initialFetchAll() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) {
        print('⚠️ [InitialFetch] storeId غير صالح - تخطي');
        return;
      }

      print('📥 [InitialFetch] بدء الجلب الأولي...');

      // 1. الأقسام
      await _fetchCategories();

      // 2. الإعدادات
      await _fetchSettings();

      // 3. المنتجات
      await _fetchCollectionNoClear('products', 'products');

      // 4. العملاء
      await _fetchCustomersSilently();

      // 5. الطلبات
      await _fetchOrdersSilently();

      // 6. الإشعارات
      await _fetchNotifications();

      // 7. البطاقات الدعائية
      await _fetchPromoCards();

      // 8. محاولة استعادة النسخة الاحتياطية
      await _tryRestoreBackup();

      _reloadControllersAfterFetch();
      print('✅ [InitialFetch] اكتمل الجلب الأولي');
    } catch (e) {
      print('❌ [InitialFetch] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  📢 البطاقات الدعائية
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchPromoCards() async {
    try {
      final doc = await _firestore
          .collection('promo_cards')
          .doc('global')
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) {
        print('ℹ️ [PromoCards] لا توجد بطاقات دعائية');
        return;
      }

      final data = doc.data()!;
      if (data['items'] != null && data['items'] is List) {
        final settingsBox = Hive.box('settings');
        await settingsBox.put('cloud_promo_items', data['items']);
        await settingsBox.put(
          'cloud_promo_last_sync',
          DateTime.now().toIso8601String(),
        );
        print('✅ [PromoCards] تم جلب ${(data['items'] as List).length} بطاقة');
      }
    } catch (e) {
      print('❌ [PromoCards] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🔔 الإشعارات
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchNotifications() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final snapshot = await _firestore
          .collection('notifications')
          .where('store_id', isEqualTo: id)
          .get()
          .timeout(const Duration(seconds: 10));

      final box = Hive.box('settings');
      final List<Map<String, dynamic>> notifications = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        notifications.add({
          'id': doc.id,
          ...Map<String, dynamic>.from(data),
        });
      }

      await box.put('cloud_notifications', notifications);
      await box.put(
        'cloud_notifications_last_sync',
        DateTime.now().toIso8601String(),
      );

      print('✅ [Notifications] تم جلب ${notifications.length} إشعار');
    } catch (e) {
      print('❌ [Notifications] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  💾 النسخة الاحتياطية — محاولة الاستعادة تلقائياً
  // ═══════════════════════════════════════════════════════════
  Future<void> _tryRestoreBackup() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final doc = await _firestore
          .collection('store_backups')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) {
        print('ℹ️ [Backup] لا توجد نسخة احتياطية');
        return;
      }

      final data = doc.data()!;

      // ✅ استعد فقط إذا كانت القيم فارغة محلياً
      final productsBox = Hive.box('products');
      final customersBox = Hive.box('customers');
      final ordersBox = Hive.box('orders');
      final settingsBox = Hive.box('settings');

      // المنتجات
      if (productsBox.isEmpty &&
          data['products'] != null &&
          data['products'] is Map) {
        await _restoreBox('products', data['products'] as Map);
        print('✅ [Backup] استعادة المنتجات');
      }

      // العملاء
      if (customersBox.isEmpty &&
          data['customers'] != null &&
          data['customers'] is Map) {
        await _restoreBox('customers', data['customers'] as Map);
        print('✅ [Backup] استعادة العملاء');
      }

      // الطلبات
      if (ordersBox.isEmpty &&
          data['orders'] != null &&
          data['orders'] is Map) {
        await _restoreBox('orders', data['orders'] as Map);
        print('✅ [Backup] استعادة الطلبات');
      }

      // الأقسام
      if (data['custom_categories_data'] != null) {
        final existing = settingsBox.get('custom_categories_data');
        if (existing == null ||
            (existing is List && existing.isEmpty)) {
          await settingsBox.put(
            'custom_categories_data',
            data['custom_categories_data'],
          );
          print('✅ [Backup] استعادة الأقسام');
        }
      }
    } catch (e) {
      print('❌ [Backup] خطأ في الاستعادة: $e');
    }
  }

  Future<void> _restoreBox(String boxName, Map data) async {
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box(boxName);
    for (var entry in data.entries) {
      try {
        await box.put(entry.key, _processFirebaseData(entry.value));
      } catch (e) {
        print('⚠️ [Backup] فشل استعادة ${entry.key}: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  👥 العملاء — جلب مع السماح بالحذف
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchCustomersSilently() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final snapshot = await _firestore
          .collection('customers')
          .where('store_id', isEqualTo: id)
          .get()
          .timeout(const Duration(seconds: 10));

      final box = Hive.box('customers');
      final cloudIds = <String>{};

      for (var doc in snapshot.docs) {
        cloudIds.add(doc.id);
        final raw = doc.data();
        final data = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        data.remove('store_id');
        data.remove('storeId');

        if (!data.containsKey('lastActive')) {
          data['lastActive'] = null;
        }

        await box.put(doc.id, _processFirebaseData(data));
      }

      // ✅ السماح بالحذف: حذف العملاء المحليين غير الموجودين في السحابة
      await _deleteLocalCustomersNotInCloud(cloudIds);

      if (Get.isRegistered<CustomerController>()) {
        Get.find<CustomerController>().loadCustomers();
      }

      print('✅ [Customers] جلب ${snapshot.docs.length} عميل');
    } catch (e) {
      print('❌ [Customers] خطأ: $e');
    }
  }

  /// ✅ حذف العملاء المحليين الذين حُذفوا من السحابة
  Future<void> _deleteLocalCustomersNotInCloud(Set<String> cloudIds) async {
    try {
      final box = Hive.box('customers');
      final localKeys = box.keys.toList();

      for (var key in localKeys) {
        final keyStr = key.toString();
        if (!cloudIds.contains(keyStr)) {
          await box.delete(key);
          print('🗑️ [Customers] حذف عميل محلي: $keyStr');
        }
      }
    } catch (e) {
      print('❌ [Customers] خطأ في الحذف: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🛒 الطلبات — جلب فقط (بدون حذف)
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchOrdersSilently() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final snapshot = await _firestore
          .collection('orders')
          .where('store_id', isEqualTo: id)
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

      print('✅ [Orders] جلب ${snapshot.docs.length} طلب');
    } catch (e) {
      print('❌ [Orders] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🗂️ المنتجات — جلب بدون حذف
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchCollectionNoClear(
      String collectionName, String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) return;

      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final box = Hive.box(boxName);
      final snapshot = await _firestore
          .collection(collectionName)
          .where('store_id', isEqualTo: id)
          .get()
          .timeout(const Duration(seconds: 15));

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
          await box.put(doc.id, _processFirebaseData(data));
        } catch (e) {
          print('❌ [$collectionName] خطأ في ${doc.id}: $e');
        }
      }

      print('✅ [$collectionName] جلب ${snapshot.docs.length} (بدون حذف)');
    } catch (e) {
      print('❌ [$collectionName] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🗂️ الأقسام — جلب بدون حذف
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchCategories() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      print('🔍 [Categories] جلب لـ: $id');

      final doc = await _firestore
          .collection('categories')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) {
        print('ℹ️ [Categories] لا توجد أقسام');
        return;
      }

      final data = doc.data()!;
      if (!data.containsKey('custom_categories_data')) return;

      final categoriesData = data['custom_categories_data'];
      if (categoriesData == null) return;

      final processed = _processFirebaseData(categoriesData);

      // ✅ لا تحذف المحلي — استخدم السحابي فقط إذا كان المحلي فارغاً
      final settingsBox = Hive.box('settings');
      final existing = settingsBox.get('custom_categories_data');

      if (existing == null || (existing is List && existing.isEmpty)) {
        await settingsBox.put('custom_categories_data', processed);
        print('✅ [Categories] استعادة ${(processed as List).length} قسم');
      } else {
        print('ℹ️ [Categories] المحلي موجود — لن يتم استبداله');
      }
    } catch (e) {
      print('❌ [Categories] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ⚙️ الإعدادات — جلب بدون حذف
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchSettings() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final doc = await _firestore
          .collection('settings')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final settingsBox = Hive.box('settings');

      for (var entry in data.entries) {
        final key = entry.key.toString();

        // ⚠️ لا تمسح هذه المفاتيح
        if (key == 'store_email' ||
            key == 'store_id' ||
            key == 'updated_at' ||
            key == 'custom_categories_data') {
          continue;
        }

        settingsBox.put(key, _processFirebaseData(entry.value));
      }

      print('✅ [Settings] تم جلب الإعدادات');
    } catch (e) {
      print('❌ [Settings] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  📤 المزامنة الكاملة (رفع فقط — بدون حذف)
  // ═══════════════════════════════════════════════════════════
  Future<bool> syncAllData() async {
    try {
      if (!Hive.isBoxOpen('products') ||
          !Hive.isBoxOpen('customers') ||
          !Hive.isBoxOpen('orders') ||
          !Hive.isBoxOpen('settings')) {
        syncError.value = 'صناديق البيانات غير جاهزة';
        return false;
      }
    } catch (e) {
      return false;
    }

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        syncError.value = 'لا يوجد اتصال بالإنترنت';
        return false;
      }
    } catch (e) {
      print('❌ Connectivity error: $e');
    }

    isSyncing.value = true;
    syncError.value = null;

    try {
      // ✅ رفع المنتجات (تحديثات فقط — merge)
      await _uploadProductImages();
      await _syncBox('products', 'products');

      // ✅ رفع العملاء (merge — لا يحذف)
      await _syncBox('customers', 'customers');

      // ✅ رفع الطلبات (merge)
      await _syncBox('orders', 'orders');

      // ✅ رفع الإعدادات
      await _syncSettings();

      // ✅ رفع الأقسام (merge — لا يحذف)
      await _syncCategories();

      lastSyncTime.value = DateTime.now();
      isSyncing.value = false;

      print('✅ [SyncAll] تمت المزامنة في ${DateTime.now()}');
      return true;
    } catch (e) {
      syncError.value = 'خطأ: $e';
      isSyncing.value = false;
      print('❌ [SyncAll] خطأ: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  📤 مزامنة صندوق (رفع فقط — merge)
  // ═══════════════════════════════════════════════════════════
  Future<void> _syncBox(String boxName, String collectionName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) return;
      final box = Hive.box(boxName);
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final collectionRef = _firestore.collection(collectionName);
      for (var key in box.keys) {
        try {
          final data = box.get(key);
          if (data != null) {
            final docRef = collectionRef.doc(key.toString());
            final firestoreData = _prepareDataForFirestore(data);
            if (firestoreData is Map) {
              firestoreData['store_id'] = id;
              firestoreData.remove('storeId');
            }
            // ✅ merge: true — لا يحذف أي حقول موجودة
            await docRef
                .set(firestoreData, SetOptions(merge: true))
                .timeout(const Duration(seconds: 5));
          }
        } catch (e) {
          print('⚠️ [$boxName] فشل رفع $key: $e');
        }
      }
      print('✅ [$boxName] تم رفع ${box.length} عنصر (merge)');
    } catch (e) {
      print('❌ [$boxName] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  📤 مزامنة الأقسام (رفع فقط — merge)
  // ═══════════════════════════════════════════════════════════
  Future<void> _syncCategories() async {
    try {
      final settingsBox = Hive.box('settings');
      final categoriesData = settingsBox.get('custom_categories_data');
      if (categoriesData == null) return;

      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final processedData = await _processImagesInCategories(categoriesData);

      // ✅ merge: true — لا يحذف أي قسم موجود في السحابة
      await _firestore
          .collection('categories')
          .doc(id)
          .set({
        'custom_categories_data': processedData,
        'updated_at': FieldValue.serverTimestamp(),
        'store_id': id,
      }, SetOptions(merge: true));

      print('✅ [Categories] تم رفع الأقسام (merge)');
    } catch (e) {
      print('❌ [Categories] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  📤 مزامنة الإعدادات
  // ═══════════════════════════════════════════════════════════
  Future<void> _syncSettings() async {
    try {
      final settingsBox = Hive.box('settings');
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

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
          .doc(id)
          .set(storeSettings, SetOptions(merge: true));
      print('✅ [Settings] تم رفع الإعدادات');
    } catch (e) {
      print('❌ [Settings] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🖼️ رفع صور المنتجات
  // ═══════════════════════════════════════════════════════════
  Future<void> _uploadProductImages() async {
    if (kIsWeb) return;

    final productsBox = Hive.box('products');
    final id = _getStoreId();
    if (!_isValidStoreId(id)) return;

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
            final ref = _storage.ref('stores/$id/products/$key.jpg');
            await ref.putFile(file);
            final url = await ref.getDownloadURL();
            data['imagePath'] = url;
            await productsBox.put(key, data);
          }
        } catch (e) {
          print('❌ [Images] خطأ في $key: $e');
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  💾 النسخ الاحتياطي
  // ═══════════════════════════════════════════════════════════
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

  Future<void> createBackup() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return;

      final settingsBox = Hive.box('settings');
      final productsBox = Hive.box('products');
      final customersBox = Hive.box('customers');
      final ordersBox = Hive.box('orders');

      final backupData = {
        'products': productsBox.toMap(),
        'customers': customersBox.toMap(),
        'orders': ordersBox.toMap(),
        'custom_categories_data':
        settingsBox.get('custom_categories_data', defaultValue: []),
        'store_settings': {
          'store_name': settingsBox.get('store_name'),
          'currency': settingsBox.get('currency'),
          'language': settingsBox.get('language'),
          'darkMode': settingsBox.get('darkMode'),
        },
        'timestamp': FieldValue.serverTimestamp(),
        'store_id': id,
      };

      await _firestore
          .collection('store_backups')
          .doc(id)
          .set(backupData, SetOptions(merge: true));

      print('✅ [Backup] تم إنشاء نسخة احتياطية');
    } catch (e) {
      print('❌ [Backup] خطأ: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🔄 استعادة يدوية
  // ═══════════════════════════════════════════════════════════
  Future<bool> restoreBackup() async {
    try {
      final id = _getStoreId();
      if (!_isValidStoreId(id)) return false;

      final doc = await _firestore
          .collection('store_backups')
          .doc(id)
          .get();

      if (!doc.exists || doc.data() == null) {
        print('⚠️ [Backup] لا توجد نسخة');
        return false;
      }

      final data = doc.data()!;

      if (data['products'] != null && data['products'] is Map) {
        final box = Hive.box('products');
        await box.clear();
        await _restoreBox('products', data['products'] as Map);
        if (Get.isRegistered<ProductController>()) {
          Get.find<ProductController>().loadProducts();
        }
      }

      if (data['customers'] != null && data['customers'] is Map) {
        final box = Hive.box('customers');
        await box.clear();
        await _restoreBox('customers', data['customers'] as Map);
        if (Get.isRegistered<CustomerController>()) {
          Get.find<CustomerController>().loadCustomers();
        }
      }

      if (data['custom_categories_data'] != null) {
        await Hive.box('settings').put(
          'custom_categories_data',
          data['custom_categories_data'],
        );
      }

      print('✅ [Backup] تمت الاستعادة');
      return true;
    } catch (e) {
      print('❌ [Backup] فشل الاستعادة: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🔧 دوال مساعدة
  // ═══════════════════════════════════════════════════════════
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
      print('❌ Reload error: $e');
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
        if (key == 'imagePath' &&
            value is String &&
            value.startsWith('data:image')) {
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
      return await imageService.uploadBytes(
        bytes: bytes,
        fileName: fileName,
        folder: folder,
      );
    } catch (e) {
      print('❌ [Images] فشل رفع Base64: $e');
      return null;
    }
  }

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
          if (intKey != null) processedKey = intKey;
        }
        processed[processedKey] = _processFirebaseData(value);
      });
      return processed;
    }

    if (data is List) {
      return data.map((e) => _processFirebaseData(e)).toList();
    }

    if (data is Timestamp) return data.toDate().toIso8601String();
    if (data is DateTime) return data.toIso8601String();

    return data.toString();
  }

  dynamic _prepareDataForFirestore(dynamic data) {
    if (data == null) return null;
    if (data is bool) return data;
    if (data is int || data is double || data is num) return data;
    if (data is String) return data;
    if (data is DateTime) return Timestamp.fromDate(data);

    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        result[key.toString()] = _prepareDataForFirestore(value);
      });
      return result;
    }

    if (data is List) {
      return data.map((e) => _prepareDataForFirestore(e)).toList();
    }

    return data.toString();
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // ✅ إصلاح شامل للبيانات
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
              await box.put(key, _processFirebaseData(data));
            }
          }
        }
      }
      await Hive.box('settings').put('needs_data_fix', false);
      print('✅ تم إصلاح جميع البيانات');
      return true;
    } catch (e) {
      print('❌ خطأ في إصلاح البيانات: $e');
      return false;
    }
  }
  /// ✅ جلب البيانات من Firebase (متوافق مع الاستدعاءات القديمة)
  ///
  /// هذه دالة wrapper تستدعي الجلب الأولي الكامل بدون حذف.
  Future<bool> fetchAllData({String? storeId}) async {
    try {
      print('🔄 [fetchAllData] بدء الجلب...');
      isSyncing.value = true;
      syncError.value = null;

      await _initialFetchAll();

      lastSyncTime.value = DateTime.now();
      isSyncing.value = false;

      print('✅ [fetchAllData] اكتمل الجلب');
      return true;
    } catch (e) {
      print('❌ [fetchAllData] خطأ: $e');
      syncError.value = '$e';
      isSyncing.value = false;
      return false;
    }
  }
}