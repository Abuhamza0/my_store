import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../core/services/badge_service.dart';
import '../../core/services/store_id_service.dart';
import '../../core/services/sync_service.dart';
import 'Premium_Cart_Sheet.dart';
import 'Sales_Category_Detail_Page.dart';
import 'customer_model.dart';
import 'customer_controller.dart';
import 'product_model.dart';
import 'product_controller.dart';
import 'order_model.dart';
import 'order_controller.dart';
import 'custom_category_model.dart';
import 'settings_page.dart';
import 'store_header_with_cart.dart';
import 'package:mystore/utils/image_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SalesScreen extends StatefulWidget {
  final Customer? customer;
  final bool showBackButton;
  final String? storeIdFromUrl;
  final String? phoneFromUrl;
  final String? emailFromUrl;

  const SalesScreen({
    super.key,
    this.customer,
    this.showBackButton = false,
    this.storeIdFromUrl,
    this.phoneFromUrl,
    this.emailFromUrl,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  Customer? _loggedInCustomer;
  bool _isLoggedIn = false;
  final bool _rememberMe = true;
  Timer? _autoSyncTimer;
  final SyncService _syncService = SyncService();
  late final phoneController = TextEditingController(text: widget.phoneFromUrl ?? '');
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final RxInt notificationsCount = 0.obs;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int connectedCustomersCount = 0;
  String? _currentStoreId;
  bool isLoading = false;
  bool showPassword = false;
  bool showRegister = false;
  bool passwordVisible = false;
  bool phoneChecked = false;
  bool rememberMe = true;
  bool _isStoreValid = false;
  Customer? foundCustomer;
  Timer? _heartbeatTimer;
  final _searchController = TextEditingController();
  final _searchQuery = ''.obs;
  final cats = <CustomCategory>[].obs;
  final _viewMode = 1.obs; // 0=قائمة, 1=شبكي, 2=كل المنتجات
  List<Map<String, dynamic>> _storeOptions = [];
  List<String> _allowedPhones = [];
  String get storeName => _getStoreName();


  // ==================== دالة الحصول على الـ UID (المعرف الموحد) ====================
  String _getStoreId() {
    try {
      // 1. الأولوية القصوى: قراءة uid من الحساب
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        return uid;
      }

      // 2. احتياطي: من Hive
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

  Future<void> _loadFromCloudIfNeeded() async {
    if (widget.storeIdFromUrl == null || widget.storeIdFromUrl!.isEmpty) return;

    try {
      print('☁️ جلب بيانات المتجر: ${widget.storeIdFromUrl}');

      final firestore = FirebaseFirestore.instance;
      final storeId = widget.storeIdFromUrl!;

      // ✅ 1. جلب المنتجات
      final productsSnapshot = await firestore
          .collection('products')
          .where('store_id', isEqualTo: storeId)
          .get();

      if (productsSnapshot.docs.isNotEmpty) {
        final productsBox = Hive.box('products');
        await productsBox.clear();

        for (var doc in productsSnapshot.docs) {
          final data = doc.data();
          data.remove('store_id');
          await productsBox.put(doc.id, data);
        }
        print('✅ جلب ${productsSnapshot.docs.length} منتج');

        final pc = Get.find<ProductController>();
        pc.loadProducts();
      }

      // ✅ 2. جلب التقسيمات
      final categoriesDoc = await firestore
          .collection('categories')
          .doc(storeId)
          .get();

      if (categoriesDoc.exists) {
        final data = categoriesDoc.data();
        if (data != null && data.containsKey('custom_categories_data')) {
          await Hive.box('settings').put('custom_categories_data', data['custom_categories_data']);
          print('✅ جلب التقسيمات');
        }
      }

      // ✅ 3. جلب اسم المتجر
      final settingsDoc = await firestore
          .collection('settings')
          .doc(storeId)
          .get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null && data.containsKey('store_name')) {
          await Hive.box('settings').put('store_name', data['store_name']);
        }
      }

      // ✅ 4. إعادة تحميل الفئات
      _loadCategories();

      if (mounted) setState(() {});

    } catch (e) {
      print('❌ خطأ في جلب بيانات المتجر: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    _fixAndInitSession().then((_) {
      if (!mounted) return;

      if (widget.customer != null) {
        _loggedInCustomer = widget.customer;
        _isLoggedIn = true;
        _loadCategories();
        _startAutoSync();
        _startHeartbeat();
        _checkSavedSession();
        if (_loggedInCustomer != null) {
          _startHeartbeat();
          _listenForNotifications();
        }

        return;
      }

      _checkSavedSession();
      _loadCategories();
      _loadFromCloudIfNeeded();
      _loadCustomersFromCloud().then((_) {
        _loadCategories();
        _autoLoginFromUrlEmail();
      });

      _startAutoSync();
    });
  }

  Future<void> _fixAndInitSession() async {
    try {
      await _resolveStoreId();
    } catch (e) {
      print('❌ خطأ في تصحيح وتأكيد storeId: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _autoLoginFromUrlEmail() {
    if (widget.emailFromUrl != null && widget.emailFromUrl!.isNotEmpty) {
      final cleanEmail = widget.emailFromUrl!.trim().toLowerCase();
      final cc = Get.find<CustomerController>();

      final customer = cc.customers.firstWhereOrNull(
            (c) => c.email.trim().toLowerCase() == cleanEmail && c.isActive,
      );

      if (customer != null && mounted) {
        setState(() {
          _loggedInCustomer = customer;
          _isLoggedIn = true;
        });
        _startHeartbeat();
      }
    }
  }

  void _startAutoSync() {
    Future.delayed(const Duration(seconds: 3), () async {
      await _syncFromCloud();
    });

    _autoSyncTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      await _syncFromCloud();
    });
  }

  Future<void> _syncFromCloud() async {
    try {
      final syncService = SyncService();
      final hasConnection = await syncService.checkConnectivity();
      if (!hasConnection) return;

      // ✅ تمرير storeId من الرابط
      final storeId = widget.storeIdFromUrl ?? StoreIdService.getStoreId();

      final success = await syncService.fetchAllData(storeId: storeId);

      if (success && mounted) {
        final pc = Get.find<ProductController>();
        pc.loadProducts();
        _loadCategories();
        if (mounted) setState(() {});
        debugPrint('🔄 تم تحديث البيانات من السحابة');
      }
    } catch (e) {
      debugPrint('❌ خطأ في المزامنة: $e');
    }
  }

  void _reloadData() {
    final pc = Get.find<ProductController>();
    final cc = Get.find<CustomerController>();

    pc.loadProducts();
    cc.loadCustomers();

    cats.clear();
    final saved = Hive.box('settings').get('custom_categories_data', defaultValue: <Map>[]);
    if (saved is List) {
      for (var j in saved) {
        try {
          cats.add(CustomCategory.fromJson(Map<String, dynamic>.from(j)));
        } catch (_) {}
      }
    }

    if (mounted) setState(() {});
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _updateLastActive();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateLastActive();
    });
  }

  String _resolvedStoreId = '';

  Future<String> fixAndResolveStoreLink(String rawLink) async {
    if (rawLink.trim().isEmpty) return rawLink;

    try {
      Uri uri = Uri.parse(rawLink.trim());
      String extractedId = '';

      if (uri.queryParameters.containsKey('storeId')) {
        extractedId = uri.queryParameters['storeId'] ?? '';
      } else if (uri.pathSegments.isNotEmpty) {
        extractedId = uri.pathSegments.last;
      } else {
        extractedId = rawLink.trim();
      }

      if (extractedId.isEmpty) return rawLink;

      String correctedId = extractedId;
      final snapshot = await FirebaseFirestore.instance.collection('stores').get();

      for (var doc in snapshot.docs) {
        final docId = doc.id;
        final data = doc.data();

        if (docId.toLowerCase() == extractedId.toLowerCase() ||
            (data['email'] != null && data['email'].toString().toLowerCase() == extractedId.toLowerCase()) ||
            (data['store_id'] != null && data['store_id'].toString().toLowerCase() == extractedId.toLowerCase())) {

          correctedId = docId;
          break;
        }
      }

      if (uri.hasQuery) {
        var newQueryParams = Map<String, String>.from(uri.queryParameters);
        newQueryParams['storeId'] = correctedId;
        return uri.replace(queryParameters: newQueryParams).toString();
      } else {
        return rawLink.replaceAll(extractedId, correctedId);
      }

    } catch (e) {
      print('خطأ أثناء تصحيح الرابط: $e');
      return rawLink;
    }
  }

  Future<String> _resolveStoreId([String? inputId]) async {
    final targetInput = (inputId != null && inputId.isNotEmpty)
        ? inputId
        : (widget.storeIdFromUrl ?? _getStoreId()); // ✅ استخدام uid هنا

    if (targetInput.trim().isEmpty) return '';

    final cleanInput = targetInput.trim();

    try {
      final directDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(cleanInput)
          .get();

      if (directDoc.exists) {
        return directDoc.id;
      }

      final snapshot = await FirebaseFirestore.instance.collection('stores').get();

      for (var doc in snapshot.docs) {
        final docId = doc.id;
        if (docId.toLowerCase() == cleanInput.toLowerCase()) {
          return docId;
        }

        final data = doc.data();
        if (data.containsKey('store_id') &&
            data['store_id'].toString().toLowerCase() == cleanInput.toLowerCase()) {
          return data['store_id'];
        }

        if (data.containsKey('email') &&
            data['email'].toString().toLowerCase() == cleanInput.toLowerCase()) {
          return docId;
        }
      }
    } catch (e) {
      print('خطأ أثناء مطابقة معرف المتجر: $e');
    }

    return cleanInput;
  }

  Future<void> _promptStoreIdFromSettings() async {
    final result = await Get.to(() => const SettingsPage());
    // قراءة uid من الإعدادات أو Firestore
    _resolvedStoreId = _getStoreId();
  }

  Future<void> _updateLastActive() async {
    if (_loggedInCustomer == null) return;
    // ✅ استخدام الـ uid مباشرة
    final storeId = _getStoreId();
    if (storeId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(_loggedInCustomer!.id)
        .set({
      'lastActive': DateTime.now().toIso8601String(),
      'isOnline': true,
      'storeId': storeId, // ✅ رفع كـ storeId
      'store_id': storeId, // ✅ رفع كـ store_id لضمان القراءة
    }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  String _getStoreIdFromUrl() {
    return widget.storeIdFromUrl ?? '';
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    nameController.dispose();
    passwordController.dispose();
    _searchController.dispose();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  String _getStoreName() {
    try {
      final settingsBox = Hive.box('settings');

      final storeName = settingsBox.get('store_name', defaultValue: '');

      if (storeName == null || storeName.toString().isEmpty) {
        final userName = settingsBox.get('user_name', defaultValue: '');
        if (userName != null && userName.toString().isNotEmpty) {
          return userName.toString();
        }

        final ownerName = settingsBox.get('owner_name', defaultValue: '');
        if (ownerName != null && ownerName.toString().isNotEmpty) {
          return ownerName.toString();
        }
      }

      return storeName?.toString() ?? 'متجري';
    } catch (e) {
      print('❌ خطأ في قراءة اسم المتجر: $e');
      return 'متجري';
    }
  }

  Future<void> _loadCustomersFromCloud() async {
    try {
      final storeId = _resolvedStoreId.isNotEmpty ? _resolvedStoreId : _getStoreId();
      if (storeId.isEmpty) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('store_id', isEqualTo: storeId)
          .get();

      final cc = Get.find<CustomerController>();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final exists = cc.customers.any((c) => c.phone == data['phone']);
        if (!exists) {
          final customer = Customer(
            id: data['id'] ?? doc.id,
            name: data['name'] ?? '',
            phone: data['phone'] ?? '',
            password: data['password'] ?? '',
            isActive: data['isActive'] ?? true,
            loginMethod: data['loginMethod'] ?? 'phone',
          );
          cc.customers.add(customer);
          final box = Hive.box('customers');
          box.put(customer.id, customer.toJson());
        }
      }
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  void _loadCategories() {
    final saved = Hive.box('settings')
        .get('custom_categories_data', defaultValue: <Map>[]);

    cats.clear();

    if (saved is List) {
      for (var j in saved) {
        try {
          cats.add(CustomCategory.fromJson(Map<String, dynamic>.from(j)));
        } catch (_) {}
      }
    }

    print('📂 تم تحميل ${cats.length} قسم');
  }

  void _checkSavedSession() async {
    final storeKey = _getStoreKey();
    final prefs = await SharedPreferences.getInstance();

    final ph = prefs.getString('${storeKey}_phone') ?? '';
    final pw = prefs.getString('${storeKey}_password') ?? '';
    final name = prefs.getString('${storeKey}_name') ?? '';
    final id = prefs.getString('${storeKey}_id') ?? '';
    final rememberMe = prefs.getBool('${storeKey}_remember') ?? false;

    print('📱 جلسة $storeKey: $name - $ph');

    if (rememberMe && ph.isNotEmpty && pw.isNotEmpty) {
      final customer = Customer(
        id: id.isNotEmpty ? id : null,
        name: name,
        phone: ph,
        password: pw,
        isActive: true,
        loginMethod: 'credentials',
      );

      if (mounted) {
        setState(() {
          _loggedInCustomer = customer;
          _isLoggedIn = true;
        });
      }

      _startHeartbeat();
      _listenForNotifications();
    }
  }

  void _saveSession(Customer c) async {
    final storeKey = _getStoreKey();
    final s = Hive.box('settings');
    s.put('${storeKey}_phone', c.phone);
    s.put('${storeKey}_password', c.password);
    s.put('${storeKey}_remember', true);
    s.put('${storeKey}_name', c.name);
    s.put('${storeKey}_id', c.id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${storeKey}_phone', c.phone);
    await prefs.setString('${storeKey}_password', c.password);
    await prefs.setBool('${storeKey}_remember', true);
    await prefs.setString('${storeKey}_name', c.name);
    await prefs.setString('${storeKey}_id', c.id);
  }

  void _clearSession() async {
    final storeKey = _getStoreKey();
    final s = Hive.box('settings');
    s.delete('${storeKey}_phone');
    s.delete('${storeKey}_password');
    s.put('${storeKey}_remember', false);
    s.delete('${storeKey}_name');
    s.delete('${storeKey}_id');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${storeKey}_phone');
    await prefs.remove('${storeKey}_password');
    await prefs.setBool('${storeKey}_remember', false);
    await prefs.remove('${storeKey}_name');
    await prefs.remove('${storeKey}_id');
  }

  void _logout() {
    if (_loggedInCustomer != null) {
      FirebaseFirestore.instance.collection('customers').doc(_loggedInCustomer!.id).set({
        'isOnline': false,
        'lastActive': DateTime.now().toIso8601String(),
        'store_id': _getStoreId(), // ✅ استخدام uid
      }, SetOptions(merge: true));
    }

    _clearSession();
    setState(() {
      _loggedInCustomer = null;
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customer != null || _isLoggedIn) {
      return _buildShoppingScreen();
    }

    String currentStoreId = (widget.storeIdFromUrl != null && widget.storeIdFromUrl!.isNotEmpty)
        ? widget.storeIdFromUrl!
        : '';

    if (currentStoreId.isEmpty) {
      currentStoreId = StoreIdService.getStoreId();
    }

    if (currentStoreId.isEmpty) {
      currentStoreId = _resolvedStoreId;
    }

    // ✅ لا تعرض شاشة خطأ - استخدم أي قيمة متاحة
    if (currentStoreId.isEmpty || currentStoreId == 'default_store') {
      Get.snackbar(
        'تنبيه',
        'لا يوجد معرف متجر صالح، سيتم استخدام المعرف الافتراضي',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }

    return _buildLoginScreen(); // ✅ افتح شاشة تسجيل الدخول دائماً
  }

  List<Product> _filterBySearch(List<Product> products) {
    if (_searchQuery.value.isEmpty) return products;
    final query = _searchQuery.value.toLowerCase();
    return products
        .where((p) =>
    p.name.toLowerCase().contains(query) ||
        p.description.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildLoginScreen() {


    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1B2D), Color(0xFF1D325E), Color(0xFF2A4B8C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // 🌟 شعار المتجر
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 50),
                    ),
                    const SizedBox(height: 20),

                    // ✨ اسم المتجر
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ).createShader(b),
                      child: Text(
                        storeName,
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تسوق بكل سهولة 🛍️',
                      style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 30),

                    // 💳 بطاقة تسجيل الدخول
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            showRegister ? 'إنشاء حساب' : showPassword ? 'أدخل كلمة المرور' : 'تسجيل الدخول',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2332)),
                          ),
                          const SizedBox(height: 24),

                          // ✅ حقل رقم الهاتف
                          TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            enabled: !phoneChecked,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: phoneChecked ? Colors.grey : Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف',
                              prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF667eea)),
                              suffixIcon: phoneChecked
                                  ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: phoneChecked ? Colors.grey.shade100 : Colors.grey.shade50,
                            ),
                            validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 16),

                          // ✅ زر تحقق
                          if (!showPassword && !showRegister)
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: isLoading ? null : () async {
                                  final phone = phoneController.text.trim();
                                  if (phone.isEmpty) {
                                    Get.snackbar('خطأ', 'أدخل رقم الهاتف',
                                        snackPosition: SnackPosition.TOP,
                                        backgroundColor: Colors.red, colorText: Colors.white);
                                    return;
                                  }

                                  setState(() => isLoading = true);

                                  final customer = await _checkPhoneInCloud(phone);

                                  if (!mounted) return;

                                  setState(() {
                                    isLoading = false;
                                    phoneChecked = true;

                                    if (customer != null) {
                                      foundCustomer = customer;
                                      if (customer.password.isNotEmpty) {
                                        showPassword = true;
                                        showRegister = false;
                                      } else {
                                        showRegister = true;
                                        showPassword = false;
                                        nameController.text = customer.name;
                                      }
                                    } else if (_storeOptions.length > 1) {
                                      phoneChecked = false;
                                      _showStoreSelection(phone);
                                    } else {
                                      phoneChecked = false;
                                      // ✅ رسالة واضحة للمستخدم
                                      Get.snackbar(
                                        'رقم الهاتف ليس مسجل',
                                        'هذا الرقم غير موجود في سجل العملاء. تواصل مع صاحب المتجر.',
                                        snackPosition: SnackPosition.TOP,
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 4),
                                      );
                                    }
                                  });
                                },
                                icon: isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.cloud_rounded, color: Colors.white),
                                label: Text(isLoading ? 'جاري التحقق...' : 'تحقق من الرقم',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667eea),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),

                          // ✅ نص توضيحي
                          if (showRegister) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                foundCustomer != null && foundCustomer!.name.isNotEmpty
                                    ? 'مرحباً ${foundCustomer!.name}، أكمل إنشاء حسابك.'
                                    : 'رقمك مسجل. أكمل البيانات.',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                              ),
                            ),
                          ],

                          // ✅ حقل كلمة المرور
                          if (showPassword) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: !passwordVisible,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFf093fb)),
                                suffixIcon: IconButton(
                                  icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => passwordVisible = !passwordVisible),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // البقاء متصلاً
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => rememberMe = !rememberMe),
                                  child: Container(
                                    width: 24, height: 24,
                                    decoration: BoxDecoration(
                                      color: rememberMe ? const Color(0xFF667eea) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: rememberMe ? Colors.transparent : Colors.grey, width: 2),
                                    ),
                                    child: rememberMe ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text('البقاء متصلاً'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (passwordController.text.isEmpty) return;
                                  if (Customer.hashPassword(passwordController.text) != foundCustomer!.password) {
                                    Get.snackbar('خطأ', 'كلمة المرور خاطئة');
                                    return;
                                  }

                                  setState(() {
                                    _loggedInCustomer = foundCustomer;
                                    _isLoggedIn = true;
                                  });

                                  // ✅ storeId من الرابط مباشرة
                                  final storeId = widget.storeIdFromUrl ?? '';
                                  print('🔍 storeId: "$storeId"');

                                  // ✅ فقط lastActive - بدون storeId
                                  FirebaseFirestore.instance.collection('customers').doc(foundCustomer!.id).set({
                                    'lastActive': DateTime.now().toIso8601String(),
                                    'isOnline': true,
                                  }, SetOptions(merge: true));

                                  _startHeartbeat();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2332)),
                                child: const Text('دخول', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],

                          // ✅ حقول إنشاء الحساب
                          if (showRegister) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'الاسم',
                                prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF43e97b)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: !passwordVisible,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFf093fb)),
                                suffixIcon: IconButton(
                                  icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => passwordVisible = !passwordVisible),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (nameController.text.trim().isEmpty) {
                                    Get.snackbar('خطأ', 'أدخل الاسم');
                                    return;
                                  }
                                  if (passwordController.text.isEmpty) {
                                    Get.snackbar('خطأ', 'أدخل كلمة المرور');
                                    return;
                                  }

                                  try {
                                    final updated = Customer(
                                      id: foundCustomer!.id,
                                      name: nameController.text.trim(),
                                      phone: foundCustomer!.phone,
                                      password: Customer.hashPassword(passwordController.text),
                                      isActive: true,
                                      loginMethod: 'credentials',
                                    );

                                    // ✅ حفظ في Hive
                                    final box = Hive.box('customers');
                                    await box.put(updated.id, updated.toJson());
                                    try {

                                      // ✅ جلب storeId الحالي من السحابة - لا تغيره
                                      final customerDoc = await FirebaseFirestore.instance
                                          .collection('customers')
                                          .doc(updated.id)
                                          .get();

                                      String existingStoreId = '';
                                      if (customerDoc.exists) {
                                        existingStoreId = customerDoc.data()?['storeId']?.toString() ?? '';
                                      }

                                      // ✅ إذا لا يوجد storeId - استخدم من الرابط
                                      if (existingStoreId.isEmpty) {
                                        existingStoreId = widget.storeIdFromUrl ?? '';
                                      }

                                      print('🔍 existingStoreId: "$existingStoreId"');
                                      print('🔍 widget.storeIdFromUrl: "${widget.storeIdFromUrl}"');

                                      final customerData = {
                                        'id': updated.id,
                                        'name': updated.name,
                                        'phone': updated.phone,
                                        'password': updated.password,
                                        'isActive': true,
                                        'loginMethod': 'credentials',
                                        'storeId': existingStoreId, // ✅ الحفاظ على المعرف الأصلي
                                        'lastActive': DateTime.now().toIso8601String(),
                                        'isOnline': true,
                                      };

                                      await FirebaseFirestore.instance.collection('customers').doc(updated.id).set({
                                        'id': updated.id,
                                        'name': updated.name,
                                        'phone': updated.phone,
                                        'password': updated.password,
                                        'isActive': true,
                                        'loginMethod': 'credentials',
                                        'storeId': existingStoreId, // ✅ الحفاظ على المعرف الأصلي
                                        'lastActive': DateTime.now().toIso8601String(),
                                        'isOnline': true,
                                      },
                                        SetOptions(merge: true), // ✅ merge - لا يمسح storeId الموجود
                                      );

                                      print('✅ تم الحفظ - storeId: ${customerData['storeId']}');
                                    } catch (e) {
                                      print('❌ خطأ: $e');
                                    }

                                    // ✅ حفظ الجلسة
                                    _saveSession(updated);
                                    _updateCustomerOnlineStatus(updated.id, true);

                                    // ✅ إعادة بناء الصفحة بالكامل - بدلاً من setState
                                    Get.offAll(() => SalesScreen(
                                      customer: updated,
                                      showBackButton: false,
                                    ));
                                    _startHeartbeat();

                                    Get.snackbar('🎉 تم!', 'تم الدخول للمتجر بنجاح',
                                        backgroundColor: Colors.green, colorText: Colors.white);
                                    _listenForNotifications();

                                  } catch (e) {
                                    debugPrint('❌ خطأ: $e');
                                    Get.snackbar('خطأ', 'فشل الدخول: $e');
                                  }
                                },
                                icon: const Icon(Icons.check_rounded, color: Colors.white),
                                label: const Text('دخول المتجر',
                                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF43e97b),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  phoneChecked = false;
                                  showRegister = false;
                                  foundCustomer = null;
                                  passwordController.clear();
                                });
                              },
                              child: const Text('تغيير الرقم', style: TextStyle(color: Colors.grey)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('© نظام سوفت 2025', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _checkActiveCustomers() async {
    try {
      final storeId = _getStoreId(); // ✅ استخدام uid

      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('store_id', isEqualTo: storeId)
          .get();

      int onlineCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lastActive = data['lastActive']?.toString() ?? '';
        final isOnline = data['isOnline'] ?? false;

        if (isOnline || (lastActive.isNotEmpty &&
            DateTime.now().difference(DateTime.tryParse(lastActive) ?? DateTime.now()).inMinutes < 3)) {
          onlineCount++;
        }
      }

      print('🟢 متصلون: $onlineCount');

      if (mounted) {
        setState(() {
          connectedCustomersCount = onlineCount;
        });
      }
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  Future<void> _updateCustomerOnlineStatus(String customerId, bool isOnline) async {
    try {
      await FirebaseFirestore.instance.collection('customers').doc(customerId).set({
        'isOnline': isOnline,
        'lastActive': DateTime.now().toIso8601String(),
        'store_id': _getStoreId(), // ✅ استخدام uid
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  void _updateStoreStatus() {
    final urlStoreId = widget.storeIdFromUrl ?? _getStoreId();
    _isStoreValid = urlStoreId.isNotEmpty && urlStoreId != 'default_store';
    if (mounted) setState(() {});
  }
  Future<Customer?> _checkPhoneInCloud(String phone) async {
    try {
      // ✅ استخدام storeId من الرابط مباشرة
      final storeId = widget.storeIdFromUrl ?? StoreIdService.getStoreId();

      // إذا كان storeId فارغاً، نجرب من Hive
      final fallbackStoreId = Hive.box('settings').get('store_id', defaultValue: '')?.toString() ?? '';
      final effectiveStoreId = storeId.isNotEmpty && storeId != 'default_store'
          ? storeId
          : fallbackStoreId;

      if (effectiveStoreId.isEmpty || effectiveStoreId == 'default_store') {
        debugPrint('❌ storeId غير صالح، سنستخدم البحث المباشر بالرقم');
      } else {
        debugPrint('🔍 البحث عن: $phone في storeId=$effectiveStoreId');

        QuerySnapshot snapshot;
        try {
          snapshot = await FirebaseFirestore.instance
              .collection('customers')
              .where('store_id', isEqualTo: effectiveStoreId)
              .get()
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          snapshot = await FirebaseFirestore.instance
              .collection('customers')
              .where('storeId', isEqualTo: effectiveStoreId)
              .get()
              .timeout(const Duration(seconds: 10));
        }

        final matchingDocs = snapshot.docs.where((doc) {
          final rawData = doc.data() ?? {};
          final Map<String, dynamic> map = Map<String, dynamic>.from(rawData as Map);

          final isActive = map['isActive'] ?? true;
          final storedPhone = map['phone']?.toString() ?? '';
          final normalizedStored = storedPhone.replaceAll(RegExp(r'[^\d]'), '');
          final normalizedSearch = phone.replaceAll(RegExp(r'[^\d]'), '');
          return isActive && normalizedStored == normalizedSearch;
        }).toList();

        if (matchingDocs.isNotEmpty) {
          return _extractCustomerFromDoc(matchingDocs.first);
        }
      }

      debugPrint('❌ لم نجد في هذا المتجر، نجرب البحث المباشر بالرقم...');

      final directSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (directSnapshot.docs.isNotEmpty) {
        return _extractCustomerFromDoc(directSnapshot.docs.first);
      }

      return null;
    } catch (e) {
      debugPrint('❌ خطأ: $e');
      return null;
    }
  }

  Customer _extractCustomerFromDoc(QueryDocumentSnapshot doc) {
    final rawData = doc.data() ?? {};
    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData as Map);
    return Customer(
      id: data['id']?.toString() ?? doc.id,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      password: data['password']?.toString() ?? '',
      isActive: data['isActive'] ?? true,
      loginMethod: data['loginMethod']?.toString() ?? 'credentials',
      storeId: data['store_id']?.toString() ?? data['storeId']?.toString(),
    );
  }
  void _showStoreSelection(String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.store_rounded, color: Color(0xFF667eea), size: 24),
            SizedBox(width: 8),
            Text('اختر المتجر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('رقم الهاتف $phone مسجل في ${_storeOptions.length} متاجر:',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            ..._storeOptions.map((store) {
              final hasPassword = store['password'].toString().isNotEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);

                      setState(() {
                        foundCustomer = Customer(
                          id: store['customerId']?.toString() ?? '',
                          name: store['name']?.toString() ?? '',
                          phone: store['phone']?.toString() ?? phone,
                          password: store['password']?.toString() ?? '',
                          isActive: true,
                          loginMethod: hasPassword ? 'credentials' : 'phone',
                        );
                        phoneChecked = true;

                        if (hasPassword) {
                          showPassword = true;
                          showRegister = false;
                        } else {
                          showRegister = true;
                          showPassword = false;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasPassword ? Colors.blue.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasPassword ? Colors.blue.shade200 : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.store_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  store['storeName']?.toString() ?? 'متجر',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasPassword ? 'لديك حساب - أدخل كلمة المرور' : 'أكمل إنشاء حسابك',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasPassword ? Colors.blue.shade700 : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            hasPassword ? Icons.lock_rounded : Icons.person_add_rounded,
                            color: hasPassword ? Colors.blue : Colors.green,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  String _getStoreKey() {
    // ✅ استخدام uid في مفتاح الجلسة
    final storeId = _getStoreId();
    return 'session_$storeId';
  }

  Future<void> _uploadOrderToFirebase(Order order, {String? storeId}) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();

      // ✅ المعرف من الرابط فقط - بدون أي شروط
      String finalStoreId = (widget.storeIdFromUrl ?? storeId ?? order.storeId ?? '').trim();

      // ✅ إزالة أي شرط - ارفع دائماً حتى لو كان فارغاً

      // 1. رفع كائن الطلب إلى مجموعة orders (بدون أي شرط)
      await FirebaseFirestore.instance.collection('orders').doc(order.id).set({
        'customerId': order.customerId,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'items': order.items.map((item) => item.toJson()).toList(),
        'totalAmount': order.totalAmount,
        'notes': order.notes ?? '',
        'customerToken': token ?? order.customerToken ?? '',
        'status': 'pending',
        'accessMethod': order.accessMethod,
        'isRead': false,
        'storeId': finalStoreId,
        'store_id': finalStoreId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. إضافة الإشعار السحابي (بدون أي شرط)
      await FirebaseFirestore.instance.collection('notifications').add({
        'customerId': order.customerId,
        'customerPhone': order.customerPhone,
        'title': 'طلب جديد 📦',
        'body': 'طلب جديد من ${order.customerName} بقيمة ${order.totalAmount.toStringAsFixed(2)} ر.س',
        'isRead': false,
        'storeId': finalStoreId,
        'store_id': finalStoreId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ تم رفع الطلب والإشعار بنجاح إلى السحابة (storeId: $finalStoreId)');
    } catch (e) {
      print('❌ فشل رفع الطلب إلى السحابة: $e');

      // ✅ الرفع الاحتياطي - دائمًا يحاول (بدون أي شروط)
      await _uploadOrderDirect(order, widget.storeIdFromUrl ?? '');
    }
  }

  Future<void> _uploadOrderDirect(Order order, String storeId) async {
    final cleanStoreId = storeId.trim();

    // ✅ لا يوجد أي شرط - ارفع دائماً حتى لو كان فارغاً

    String? token = await FirebaseMessaging.instance.getToken();
    try {
      await FirebaseFirestore.instance.collection('orders').doc(order.id).set({
        'customerId': order.customerId,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'items': order.items.map((item) => item.toJson()).toList(),
        'totalAmount': order.totalAmount,
        'notes': order.notes ?? '',
        'customerToken': token ?? order.customerToken ?? '',
        'status': 'pending',
        'accessMethod': order.accessMethod,
        'isRead': false,
        'storeId': cleanStoreId,
        'store_id': cleanStoreId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('notifications').add({
        'customerId': order.customerId,
        'customerPhone': order.customerPhone,
        'title': 'طلب جديد 📦',
        'body': 'تم استلام طلب جديد بقيمة ${order.totalAmount.toStringAsFixed(2)} ر.س',
        'isRead': false,
        'storeId': cleanStoreId,
        'store_id': cleanStoreId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ تم الرفع المباشر والإشعار بنجاح (storeId: $cleanStoreId)');
    } catch (e) {
      print('❌ فشل الرفع المباشر: $e');
    }
  }

  void _showCreateAccount() {
    final ph = TextEditingController(),
        nm = TextEditingController(),
        ps = TextEditingController(),
        cp = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_add_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            const Text(
              'إنشاء حساب',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(
                  ph,
                  'رقم الهاتف',
                  Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                _buildDialogField(
                  nm,
                  'الاسم',
                  Icons.person,
                ),
                const SizedBox(height: 12),

                _buildDialogField(
                  ps,
                  'كلمة المرور (6 أحرف على الأقل)',
                  Icons.lock,
                  obscure: true,
                ),
                const SizedBox(height: 12),

                _buildDialogField(
                  cp,
                  'تأكيد كلمة المرور',
                  Icons.lock_outline,
                  obscure: true,
                ),
              ]
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final p = ph.text.trim(),
                  n = nm.text.trim(),
                  s = ps.text.trim(),
                  c = cp.text.trim();
              if (p.isEmpty || n.isEmpty || s.isEmpty || c.isEmpty) {
                Get.snackbar('خطأ', 'املأ جميع الحقول',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.red,
                    colorText: Colors.white);
                return;
              }
              if (s.length < 6) {
                Get.snackbar('خطأ', 'كلمة المرور قصيرة',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.red,
                    colorText: Colors.white);
                return;
              }
              if (s != c) {
                Get.snackbar('خطأ', 'كلمة المرور غير متطابقة',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.red,
                    colorText: Colors.white);
                return;
              }
              final cc = Get.find<CustomerController>();
              final ex = cc.customers
                  .firstWhereOrNull((x) => x.phone == p && x.isActive);
              if (ex == null) {
                Get.snackbar('خطأ', 'رقم الهاتف غير مسجل',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.red,
                    colorText: Colors.white);
                return;
              }
              if (ex.password.isNotEmpty) {
                Get.snackbar('تنبيه', 'الحساب موجود مسبقاً',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.orange,
                    colorText: Colors.white);
                return;
              }
              final up = Customer(
                id: ex.id,
                name: n,
                phone: ex.phone,
                password: Customer.hashPassword(s),
                isActive: true,
                loginMethod: 'credentials',
              );
              await cc.updateCustomer(up);
              _saveSession(up);
              Navigator.pop(ctx);
              setState(() {
                _loggedInCustomer = up;
                _isLoggedIn = true;
              });
              Get.snackbar('🎉 تم!', 'تم إنشاء الحساب بنجاح',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.green,
                  colorText: Colors.white);
            },
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            label: const Text('إنشاء',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43e97b),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType? keyboardType,
        bool obscure = false,
      }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A2332)),
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildShoppingScreen() {
    final pc = Get.find<ProductController>();
    final oc = Get.put(OrderController());
    final cart = <OrderItem>[].obs;
    final total = 0.0.obs;

    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    const luxuryNavy = Color(0xFF101A2D);
    const luxuryNavyDark = Color(0xFF0B1220);
    const luxuryGold = Color(0xFFD4AF37);
    const luxuryGoldLight = Color(0xFFF1D77A);

    final backgroundColor = isDark
        ? const Color(0xFF080D16)
        : const Color(0xFFF4F6F9);

    final cardColor = isDark
        ? const Color(0xFF101827)
        : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: luxuryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 68,
        titleSpacing: 18,

        leading: Padding(
          padding: const EdgeInsets.only(left: 14, right: 4),
          child: Center(
            child: Tooltip(
              message: _isStoreValid ? 'المتجر متزامن' : 'يوجد خلل في المتجر',
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isStoreValid ? Colors.green : Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: (_isStoreValid ? Colors.green : Colors.red).withOpacity(0.8),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        title: Row(
          children: [

            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    luxuryGoldLight,
                    luxuryGold,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                BorderRadius.circular(12),

                boxShadow: [
                  BoxShadow(
                    color: luxuryGold.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: const Icon(
                Icons.shopping_bag_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: const [

                Text(
                  'تسوق الآن',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 2),

                Text(
                  'متجر المنتجات',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [


          _buildLuxuryAppBarButton(
            icon: Icons.refresh_rounded,
            tooltip: 'تحديث البيانات',
            onPressed: () => _refreshAllData(),
          ),

          const SizedBox(width: 3),
          IconButton(
            icon: const Icon(Icons.store_rounded, color: Colors.white70, size: 20),
            tooltip: 'تعديل storeId',
            onPressed: () {
              _loadCurrentStoreId();
              _showStoreIdEditor();
            },
          ),

          // في build() داخل AppBar (شاشة الزبون):
          Obx(() {
            final count = notificationsCount.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _buildLuxuryAppBarButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'الإشعارات',
                  onPressed: () => _showCustomerNotifications(),
                ),
                if (count > 0)
                  Positioned(
                    top: 7,
                    right: 4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        border: Border.all(color: luxuryNavy, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),

          const SizedBox(width: 3),

          _buildLuxuryAppBarButton(
            icon: Icons.logout_rounded,
            tooltip: 'تسجيل الخروج',
            onPressed: () {

              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: cardColor,
                  elevation: 20,

                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(20),
                  ),

                  title: Row(
                    children: [

                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.red
                              .withOpacity(0.10),
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.red,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : luxuryNavy,
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  content: Text(
                    'هل تريد تسجيل الخروج؟',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white60
                          : Colors.black54,
                      fontSize: 14,
                    ),
                  ),

                  actionsPadding:
                  const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    18,
                  ),

                  actions: [

                    TextButton(
                      onPressed: () =>
                          Navigator.pop(ctx),
                      child: Text(
                        'لا',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : luxuryNavy,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    ElevatedButton(
                      onPressed: () {

                        Navigator.pop(ctx);

                        _logout();

                        Get.offAll(
                              () => const SalesScreen(
                            showBackButton: false,
                          ),
                        );
                      },

                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFFD32F2F),
                        foregroundColor:
                        Colors.white,
                        elevation: 0,

                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                      ),

                      child: const Text(
                        'نعم',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 10),
        ],
      ),

      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              8,
              14,
              0,
            ),
            child: Container(
              width: double.infinity,

              decoration: BoxDecoration(
                color: cardColor,

                borderRadius:
                BorderRadius.circular(22),

                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFE7EAF0),
                ),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      isDark ? 0.14 : 0.055,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),

              child: ClipRRect(
                borderRadius:
                BorderRadius.circular(22),

                child: StoreHeaderWithCart(
                  loggedInCustomer:
                  _loggedInCustomer,

                  cart: cart,

                  total: total,

                  onCartTap: () =>
                      _showCart(
                        cart,
                        total,
                        oc,
                      ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              8,
              14,
              0,
            ),
            child: Container(
              height: 42,

              decoration: BoxDecoration(
                color: cardColor,

                borderRadius:
                BorderRadius.circular(17),

                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFE7EAF0),
                ),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      isDark ? 0.12 : 0.045,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),

              child: TextField(
                controller: _searchController,

                onChanged: (v) =>
                _searchQuery.value = v,

                style: TextStyle(
                  color: isDark
                      ? Colors.white
                      : luxuryNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),

                decoration: InputDecoration(
                  hintText:
                  'ابحث عن منتج...',

                  hintStyle: TextStyle(
                    color: isDark
                        ? Colors.white38
                        : Colors.grey.shade400,
                    fontSize: 13,
                  ),

                  prefixIcon: Container(
                    margin:
                    const EdgeInsets.all(9),

                    decoration: BoxDecoration(
                      gradient:
                      const LinearGradient(
                        colors: [
                          luxuryGoldLight,
                          luxuryGold,
                        ],
                      ),

                      borderRadius:
                      BorderRadius.circular(11),
                    ),

                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size:16,
                    ),
                  ),

                  suffixIcon:
                  _searchQuery.value.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? Colors.white54
                          : Colors.grey,
                    ),

                    onPressed: () {
                      _searchController.clear();
                      _searchQuery.value = '';
                    },
                  )
                      : null,

                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(17),
                    borderSide: BorderSide.none,
                  ),

                  filled: true,
                  fillColor:
                  Colors.transparent,

                  contentPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(
              top: 5,
              bottom: 3,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),

              decoration: BoxDecoration(
                color: cardColor,

                borderRadius:
                BorderRadius.circular(15),

                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFE7EAF0),
                ),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      isDark ? 0.10 : 0.035,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Obx(
                    () => Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [

                    _buildLuxuryViewButton(
                      icon:
                      Icons.view_agenda_rounded,
                      index: 0,
                      tooltip: 'عرض قائمة',
                      isDark: isDark,
                    ),

                    _buildLuxuryViewButton(
                      icon:
                      Icons.grid_view_rounded,
                      index: 1,
                      tooltip: 'عرض شبكي',
                      isDark: isDark,
                    ),

                    _buildLuxuryViewButton(
                      icon:
                      Icons.list_alt_rounded,
                      index: 2,
                      tooltip: 'كل المنتجات',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Obx(() {

              if (pc.isLoading.value) {
                return Center(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [

                      Container(
                        width: 58,
                        height: 58,
                        padding:
                        const EdgeInsets.all(14),

                        decoration:
                        BoxDecoration(
                          color: luxuryGold
                              .withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),

                        child:
                        const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: luxuryGold,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'جاري تحميل المنتجات...',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (_searchQuery.value.isNotEmpty) {

                final f =
                _filterBySearch(pc.products);

                if (f.isEmpty) {
                  return _buildLuxuryEmptyState(
                    icon:
                    Icons.search_off_rounded,
                    title:
                    'لا توجد نتائج',
                    subtitle:
                    'لم نعثر على منتج يطابق بحثك',
                    isDark: isDark,
                  );
                }

                return _buildSearchResults(
                  f,
                  cart,
                  total,
                  isDark,
                );
              }

              if (pc.products.isEmpty &&
                  cats.isEmpty) {

                return _buildLuxuryEmptyState(
                  icon:
                  Icons.storefront_rounded,
                  title:
                  'لا توجد منتجات',
                  subtitle:
                  'ستظهر المنتجات هنا عند إضافتها',
                  isDark: isDark,
                );
              }

              switch (_viewMode.value) {

                case 0:
                  return _buildListView(
                    pc,
                    cart,
                    total,
                    isDark,
                  );

                case 1:
                  return _buildGridView(
                    pc,
                    cart,
                    total,
                    isDark,
                  );

                case 2:
                  return _buildAllProductsView(
                    pc,
                    cart,
                    total,
                    isDark,
                  );

                default:
                  return _buildGridView(
                    pc,
                    cart,
                    total,
                    isDark,
                  );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryViewButton({
    required IconData icon,
    required int index,
    required String tooltip,
    required bool isDark,
  }) {
    const gold = Color(0xFFD4AF37);
    const goldDark = Color(0xFFB88A16);

    final isSelected = _viewMode.value == index;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _viewMode.value = index;
          },
          borderRadius: BorderRadius.circular(8),

          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 180,
            ),
            curve: Curves.easeOut,

            width: 36,
            height: 32,

            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                colors: [
                  gold,
                  goldDark,
                ],
              )
                  : null,

              color: isSelected
                  ? null
                  : Colors.transparent,

              borderRadius:
              BorderRadius.circular(8),

              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color:
                  gold.withOpacity(0.18),
                  blurRadius: 6,
                  offset:
                  const Offset(0, 2),
                ),
              ]
                  : null,
            ),

            child: Icon(
              icon,
              size: 17,

              color: isSelected
                  ? Colors.white
                  : isDark
                  ? Colors.white54
                  : const Color(0xFF7A8494),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryAppBarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius:
          BorderRadius.circular(12),

          child: Container(
            width: 42,
            height: 42,

            margin:
            const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 2,
            ),

            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(0.065),

              borderRadius:
              BorderRadius.circular(12),

              border: Border.all(
                color: Colors.white
                    .withOpacity(0.07),
              ),
            ),

            child: Icon(
              icon,
              color: Colors.white70,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    const gold = Color(0xFFD4AF37);
    const navy = Color(0xFF101A2D);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Container(
            width: 110,
            height: 110,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: LinearGradient(
                colors: [
                  gold.withOpacity(0.16),
                  gold.withOpacity(0.035),
                ],

                begin:
                Alignment.topLeft,
                end:
                Alignment.bottomRight,
              ),
            ),

            child: Icon(
              icon,
              size: 48,
              color:
              gold.withOpacity(0.80),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            title,
            style: TextStyle(
              color: isDark
                  ? Colors.white
                  : navy,
              fontSize: 19,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            subtitle,
            style: TextStyle(
              color: isDark
                  ? Colors.white54
                  : Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('customerId', isEqualTo: _loggedInCustomer!.id)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data();
              return ListTile(
                leading: const Icon(Icons.notifications_rounded, color: Colors.green),
                title: Text(data['title'] ?? ''),
                subtitle: Text(data['body'] ?? ''),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildViewModeButton(IconData icon, int mode, String tooltip) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _viewMode.value == mode
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: _viewMode.value == mode ? Colors.amber : Colors.white70,
          size: 18,
        ),
      ),
      onPressed: () => _viewMode.value = mode,
      tooltip: tooltip,
      splashRadius: 18,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildSearchResults(
      List<Product> products, RxList<OrderItem> cart, RxDouble total, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.70,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: products.length,
      itemBuilder: (c, i) =>
          _buildProductCard(products[i], cart, total, isDark),
    );
  }

  Widget _buildGridView(
      ProductController pc,
      RxList<OrderItem> cart,
      RxDouble total,
      bool isDark,
      ) {
    final oc = Get.find<OrderController>();

    const gold = Color(0xFFD4AF37);
    const goldLight = Color(0xFFF1D77A);
    const navy = Color(0xFF101A2D);

    final cardColor = isDark ? const Color(0xFF101827) : Colors.white;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cats.length,
      itemBuilder: (context, index) {
        final cat = cats[index];

        final allProducts = <Product>[];

        for (var sub in cat.subCategories) {
          allProducts.addAll(
            pc.products.where((p) => p.category == sub.name),
          );

          if (sub.subCategories != null) {
            for (var sc in sub.subCategories!) {
              allProducts.addAll(
                pc.products.where((p) => p.category == sc.name),
              );
            }
          }
        }

        final productCount = allProducts.length;
        final subCategoryCount = cat.subCategories.length;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Get.to(
                    () => SalesCategoryDetailPage(
                  category: cat,
                  cart: cart,
                  total: total,
                  loggedInCustomer: _loggedInCustomer,
                  onCartTap: () => _showCart(cart, total, oc),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.055)
                      : const Color(0xFFE7EAF0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.14 : 0.045),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 95,
                        height: 95,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              gold.withOpacity(isDark ? 0.12 : 0.07),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [goldLight, gold],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: gold.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.folder_copy_rounded,
                                      size: 11,
                                      color: gold,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$subCategoryCount',
                                      style: const TextStyle(
                                        color: gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: gold.withOpacity(0.30),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: gold.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: (cat.imagePath != null && cat.imagePath!.isNotEmpty)
                                  ? Image.network(
                                cat.imagePath!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(gold),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: gold.withOpacity(0.1),
                                    child: const Icon(
                                      Icons.image_not_supported_rounded,
                                      color: gold,
                                      size: 24,
                                    ),
                                  );
                                },
                              )
                                  : Container(
                                color: gold.withOpacity(0.1),
                                child: const Icon(
                                  Icons.category_rounded,
                                  color: gold,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
                          Expanded(
                            child: Center(
                              child: Text(
                                cat.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white : navy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.045)
                                  : const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$productCount منتج',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF7A8494),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    Positioned(
                      bottom: 9,
                      right: 10,
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: isDark ? gold.withOpacity(0.60) : gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductImageForCard(Product p) {
    final imagePath = p.imagePath ?? '';

    print('📸 imagePath: $imagePath');
    print('📸 يبدأ بـ http: ${imagePath.startsWith('http')}');

    if (imagePath.startsWith('http') || imagePath.startsWith('https')) {
      return Image.network(
        imagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholderForCard(),
      );
    }

    if (imagePath.startsWith('assets/') && imagePath != 'assets/images/product_placeholder.png') {
      return Image.asset(
        imagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholderForCard(),
      );
    }

    if (imagePath.startsWith('blob:')) {
      return ImageHelper.displayImage(
        imagePath: imagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: _buildImagePlaceholderForCard(),
      );
    }

    return _buildImagePlaceholderForCard();
  }

  Widget _buildImagePlaceholderForCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.grey.shade100, Colors.grey.shade200]),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_rounded, size: 25, color: Colors.grey.shade400),
            const SizedBox(height: 4),
            Text('لا صورة', style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  void _showProductDetailPopup(
      Product product, RxList<OrderItem> cart, RxDouble total) {
    final currency =
    Hive.box('settings').get('currency', defaultValue: 'USD');
    int quantity = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final itemTotal = product.price * quantity;
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: _buildProductImageForDetail(product),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2332),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$currency${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (product.description.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              product.description,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (quantity > 1) {
                                  setDialogState(() => quantity--);
                                }
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.remove_rounded,
                                    color: Color(0xFF1A2332)),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2332),
                              ),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() => quantity++);
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1A2332),
                                      Color(0xFF2D3A4E)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.add_rounded,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'الإجمالي: $currency${itemTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2332),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _addToCart(product, quantity, cart, total);
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.add_shopping_cart_rounded,
                                color: Colors.white, size: 22),
                            label: const Text(
                              'أضف للسلة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A2332),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductImageForDetail(Product product) {
    final imagePath = product.imagePath ?? '';

    if (imagePath.startsWith('http') || imagePath.startsWith('https')) {
      return Image.network(
        imagePath,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDetailImagePlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildDetailImagePlaceholder();
        },
      );
    }

    if (imagePath.startsWith('assets/') && imagePath != 'assets/images/product_placeholder.png') {
      return Image.asset(
        imagePath,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDetailImagePlaceholder(),
      );
    }

    return _buildDetailImagePlaceholder();
  }

  Widget _buildProductCard(Product p, RxList<OrderItem> cart, RxDouble total, bool isDark) {
    final currency = Hive.box('settings').get('currency', defaultValue: 'SAR')?.toString() ?? 'SAR';

    return GestureDetector(
      onTap: () => _showProductDetailPopup(p, cart, total),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: _buildProductImageForCard(p),
                  ),
                  Positioned(
                    top: 4, left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1A2332), Color(0xFF2D3A4E)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$currency${p.price.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(p.description.isNotEmpty ? p.description : 'لا يوجد وصف',
                        style: TextStyle(fontSize: 7, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity, height: 22,
                      child: ElevatedButton(
                        onPressed: () => _addToCart(p, 1, cart, total),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2332),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 10),
                          SizedBox(width: 2),
                          Text('أضف', style: TextStyle(color: Colors.white, fontSize: 8)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailImagePlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                size: 30,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد صورة',
              style: TextStyle(
                fontSize: 11,
                color: Colors.teal.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(
      Product p, int qty, RxList<OrderItem> cart, RxDouble total) {
    final idx = cart.indexWhere((i) => i.productId == p.id);
    if (idx != -1) {
      final e = cart[idx];
      cart[idx] = OrderItem(
        productId: p.id,
        productName: p.name,
        price: p.price,
        quantity: e.quantity + qty,
        total: p.price * (e.quantity + qty),
      );
    } else {
      cart.add(OrderItem(
        productId: p.id,
        productName: p.name,
        price: p.price,
        quantity: qty,
        total: p.price * qty,
      ));
    }
    total.value = cart.fold(0.0, (s, i) => s + i.total);
    Get.snackbar(
      '✅ تم',
      'تمت الإضافة للسلة',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  void _showCart(RxList<OrderItem> cart, RxDouble total, OrderController oc) {
    final currency = Hive.box('settings').get('currency', defaultValue: 'SAR')?.toString() ?? 'SAR';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.52),
      builder: (ctx) => PremiumCartSheet(
        cart: cart,
        total: total,
        oc: oc,
        loggedInCustomer: _loggedInCustomer,
        currency: currency,
        uploadOrder: _uploadOrderToFirebase,
      ),
    );
  }

  Widget _cartQtyButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    const navy = Color(0xFF101A2D);
    const gold = Color(0xFFD4AF37);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(
            colors: [navy, Color(0xFF263752)],
          )
              : null,
          color: filled ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(9),
          border: filled
              ? null
              : Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(
          icon,
          size: 15,
          color: filled ? gold : navy,
        ),
      ),
    );
  }

  Future<void> _refreshAllData() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final storeId = _getStoreId(); // ✅ استخدام uid

      if (storeId.isEmpty || storeId == 'default_store') {
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar('خطأ', 'لا يوجد معرف للمتجر', backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('store_id', isEqualTo: storeId)
          .get();

      final productsBox = Hive.box('products');
      await productsBox.clear();

      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        data.remove('store_id');
        data.remove('storeId');
        await productsBox.put(doc.id, data);
      }

      final categoriesDoc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(storeId)
          .get();

      if (categoriesDoc.exists) {
        final data = categoriesDoc.data();
        if (data != null && data.containsKey('custom_categories_data')) {
          await Hive.box('settings').put('custom_categories_data', data['custom_categories_data']);
        }
      }

      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc(storeId)
          .get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null && data.containsKey('store_name')) {
          await Hive.box('settings').put('store_name', data['store_name']);
        }
      }

      final pc = Get.find<ProductController>();
      pc.loadProducts();

      _loadCategories();

      if (Get.isDialogOpen ?? false) Get.back();

      if (mounted) setState(() {});

      Get.snackbar(
        '✅ تم',
        'تم تحديث ${productsSnapshot.docs.length} منتج',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      print('❌ خطأ: $e');
      Get.snackbar('خطأ', '$e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // ==================== الاستماع للإشعارات من السحابة ====================
  void _listenForNotifications() {
    if (_loggedInCustomer == null) return;

    // ✅ الحصول على storeId (UID) من الخدمة
    final storeId = _getStoreId(); // أو StoreIdService.getStoreId()
    final customerPhone = _loggedInCustomer!.phone;

    print('🔔 الاستماع للإشعارات - storeId: $storeId, customerPhone: $customerPhone');

    // ✅ الاستماع للإشعارات بناءً على customerPhone و store_id
    FirebaseFirestore.instance
        .collection('notifications')
        .where('store_id', isEqualTo: storeId) // ✅ استخدام store_id
        .where('customerPhone', isEqualTo: customerPhone)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      notificationsCount.value = snapshot.docs.length; // ✅ تحديث العداد
      BadgeService.updateBadge(notificationsCount.value);

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data();
          if (data == null) continue;

          Get.showSnackbar(
            GetSnackBar(
              title: data['title']?.toString() ?? 'إشعار',
              message: data['body']?.toString() ?? '',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.green,
              duration: const Duration(days: 1),
              isDismissible: true,
              icon: const Icon(Icons.notifications_rounded, color: Colors.white),
            ),
          );

          _playNotificationSound();
        }
      }
    });
  }

  // ==================== عرض الإشعارات ====================
  void _showCustomerNotifications() {
    if (_loggedInCustomer == null) return;

    final customerPhone = _loggedInCustomer!.phone;
    final storeId = _getStoreId();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: Get.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ✅ مقبض
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ✅ عنوان
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'الإشعارات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(),
            // ✅ قائمة الإشعارات
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('store_id', isEqualTo: storeId)
                    .where('customerPhone', isEqualTo: customerPhone)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('لا توجد إشعارات'));
                  }

                  // ✅ ترتيب يدوي
                  final docs = List.from(snapshot.data!.docs);
                  docs.sort((a, b) {
                    final aTime = a.data()['createdAt'];
                    final bTime = b.data()['createdAt'];
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.toString().compareTo(aTime.toString());
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final isRead = data['isRead'] ?? false;

                      return GestureDetector(
                        onTap: () async {
                          // ✅ تحديث كـ مقروء
                          await doc.reference.update({'isRead': true});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.grey.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRead ? Colors.grey.shade200 : Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: (isRead ? Colors.grey : Colors.green).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.notifications_rounded,
                                  color: isRead ? Colors.grey : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title']?.toString() ?? 'إشعار',
                                      style: TextStyle(
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['body']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification2.mp3'));
    } catch (e) {
      print('❌ خطأ في الصوت: $e');
    }
  }

  Widget _buildListView(ProductController pc, RxList<OrderItem> cart,
      RxDouble total, bool isDark) {
    if (cats.isEmpty) return _buildAllProductsView(pc, cart, total, isDark);

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: cats.length,
      itemBuilder: (context, index) {
        final cat = cats[index];
        final colors = [
          const Color(0xFFFF6B6B), const Color(0xFF4ECDC4),
          const Color(0xFFFFD93D), const Color(0xFF6C5CE7),
          const Color(0xFFFF8A5C), const Color(0xFF45B7D1),
        ];
        final colorIndex = cat.name.hashCode.abs() % colors.length;
        final folderColor = colors[colorIndex];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [folderColor.withOpacity(0.8), folderColor],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder_rounded,
                  color: Colors.white, size: 20),
            ),
            title: Text(
              cat.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              '${cat.subCategories.length} فروع',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            initiallyExpanded: cats.length <= 2,
            children: [
              for (var sub in cat.subCategories)
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.03)
                        : const Color(0xFF667eea).withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF667eea).withOpacity(0.2)),
                  ),
                  child: ExpansionTile(
                    leading: const Icon(Icons.label_rounded,
                        color: Color(0xFF667eea), size: 18),
                    title: Text(sub.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                      '${sub.subCategories?.length ?? 0} فئات',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 10),
                    ),
                    children: [
                      ..._buildProductListItems(
                        pc.products
                            .where((p) => p.category == sub.name)
                            .toList(),
                        cart,
                        total,
                        isDark,
                      ),
                      if (sub.subCategories != null &&
                          sub.subCategories!.isNotEmpty)
                        for (var subCat in sub.subCategories!)
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.teal.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              leading: const Icon(
                                  Icons.subdirectory_arrow_right_rounded,
                                  color: Colors.teal,
                                  size: 16),
                              title: Text(subCat.name,
                                  style: const TextStyle(fontSize: 12)),
                              subtitle: Text(
                                '${pc.products.where((p) => p.category == subCat.name).length} منتجات',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 9),
                              ),
                              children: _buildProductListItems(
                                pc.products
                                    .where(
                                        (p) => p.category == subCat.name)
                                    .toList(),
                                cart,
                                total,
                                isDark,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildProductListItems(List<Product> products,
      RxList<OrderItem> cart, RxDouble total, bool isDark) {
    if (products.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'لا توجد منتجات',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ),
      ];
    }
    return products
        .map((p) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: _buildProductImageForCard(p),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (p.description.isNotEmpty)
                  Text(
                    p.description,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${p.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (p.flavor != null && p.flavor!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🍹 ${p.flavor}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _addToCart(p, 1, cart, total),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    ))
        .toList();
  }

  Widget _buildAllProductsView(ProductController pc, RxList<OrderItem> cart,
      RxDouble total, bool isDark) {
    final allProducts = <Product>[];

    for (var cat in cats) {
      for (var sub in cat.subCategories) {
        allProducts.addAll(pc.products.where((p) => p.category == sub.name));
        if (sub.subCategories != null) {
          for (var sc in sub.subCategories!) {
            allProducts.addAll(pc.products.where((p) => p.category == sc.name));
          }
        }
      }
    }

    final unique = allProducts.toSet().toList();

    if (unique.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'لا توجد منتجات',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: unique.length,
      itemBuilder: (context, index) {
        final p = unique[index];
        return _buildProductCard(p, cart, total, isDark);
      },
    );
  }

  // 2. إضافة دالة لجلب storeId الحالي (في initState أو عند الحاجة)
  void _loadCurrentStoreId() {
    final storeId = StoreIdService.getStoreId();
    if (storeId.isEmpty || storeId == 'default_store') {
      _currentStoreId = widget.storeIdFromUrl ?? '';
    } else {
      _currentStoreId = storeId;
    }
  }

  Future<void> _showStoreIdEditor() async {
    final controller = TextEditingController(text: _currentStoreId ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.store_rounded, color: Color(0xFF1D325E), size: 24),
            SizedBox(width: 8),
            Text('تعديل معرف المتجر', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يمكنك تعديل معرف المتجر (storeId) يدوياً إذا لزم الأمر'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'storeId',
                hintText: 'أدخل معرف المتجر',
                prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF1D325E)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final newStoreId = controller.text.trim();
              if (newStoreId.isEmpty) {
                Get.snackbar('خطأ', 'لا يمكن أن يكون storeId فارغاً',
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }

              // ✅ حفظ المعرف الجديد
              StoreIdService.saveStoreIdLocally(newStoreId);
              _currentStoreId = newStoreId;

              // تحديث Hive
              Hive.box('settings').put('store_id', newStoreId);
              Hive.box('settings').put('storeid', newStoreId);

              Navigator.pop(ctx);
              setState(() {});

              Get.snackbar('تم', 'تم تحديث storeId بنجاح: $newStoreId',
                  backgroundColor: Colors.green, colorText: Colors.white,
                  duration: const Duration(seconds: 3));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D325E),
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

