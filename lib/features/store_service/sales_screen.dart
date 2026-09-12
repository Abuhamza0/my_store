// sales_screen.dart
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive/hive.dart';
import 'Premium_Cart_Sheet.dart';
import 'Sales_Category_Detail_Page.dart';
import 'customer_model.dart';
import 'customer_controller.dart';
import 'product_model.dart';
import 'product_controller.dart';
import 'order_model.dart';
import 'order_controller.dart';
import 'custom_category_model.dart';
import 'category_detail_page.dart';
import 'package:mystore/utils/image_helper.dart';
import 'Premium_Product_Expanded_View.dart';
import 'package:mystore/core/services/locale_service.dart';

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
  static const _navy = Color(0xFF0B1220);
  static const _navy2 = Color(0xFF14213A);
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFF1D77A);
  static const _page = Color(0xFFF5F7FA);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const _secureStorage = FlutterSecureStorage();
  static const _sessionCustomerIdKey = 'mystore_customer_session_id';
  static const _sessionStoreIdKey = 'mystore_customer_session_store_id';
  static const _sessionExpiresAtKey = 'mystore_customer_session_expires_at';
  static const _customerLanguageKey = 'mystore_customer_language';

  static const _sessionDuration = Duration(hours: 24);
  Timer? _sessionTimer;
  bool _restoringCredentialSession = true;


  final _searchController = TextEditingController();
  final _searchQuery = ''.obs;
  final _cart = <OrderItem>[].obs;
  final _cartTotal = 0.0.obs;
  final _notificationsCount = 0.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _storeSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _categorySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationSub;
  StreamSubscription<User?>? _authSub;

  Customer? _loggedInCustomer;
  bool _initializing = true;
  bool _storeExists = false;
  bool _online = true;
  bool _loadingOrder = false;
  String? _error;

  String _storeName = 'store'.tr;
  String? _storeLogo;
  String _currency = 'SAR';
  String _resolvedStoreId = '';

  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final RxString _customerLocale = 'en'.obs;

  bool _phoneVerified = false;
  bool _verifyingPhone = false;
  bool _authenticating = false;
  bool _passwordVisible = false;
  Map<String, dynamic>? _verifiedCustomerData;
  String? _verifiedCustomerId;

  List<CustomCategory> _categories = [];
  int _selectedCategoryIndex = 0;
  int _viewMode = 1;
  int _productSizeMode = 0;

  List<Product> _products = [];

  ProductController? _productController;
  CustomerController? _customerController;
  OrderController? _orderController;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _resolveAndStart();
    _loadCustomerLanguage();

    ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });
  }

  void _loadSettings() {
    final box = Hive.box('settings');
    _currency = box.get('currency', defaultValue: 'SAR')?.toString() ?? 'SAR';
  }

  Future<void> _loadCustomerLanguage() async {
    try {
      final savedLang = await _secureStorage.read(key: _customerLanguageKey);
      if (savedLang != null && savedLang.isNotEmpty) {
        _customerLocale.value = savedLang;
        Get.updateLocale(Locale(savedLang));
      } else {
        // ✅ إذا لم تكن هناك لغة محفوظة، استخدم الإنجليزية
        _customerLocale.value = 'en';
        Get.updateLocale(const Locale('en'));
      }
    } catch (e) {
      debugPrint('Load customer language error: $e');
      // ✅ في حالة الخطأ، استخدم الإنجليزية
      _customerLocale.value = 'en';
      Get.updateLocale(const Locale('en'));
    }
  }


  Future<void> _saveCustomerLanguage(String lang) async {
    try {
      await _secureStorage.write(key: _customerLanguageKey, value: lang);
    } catch (e) {
      debugPrint('Save customer language error: $e');
    }
  }

  void _toggleCustomerLanguage() {
    final newLang = _customerLocale.value == 'en' ? 'ar' : 'en';
    _customerLocale.value = newLang;
    Get.updateLocale(Locale(newLang));
    _saveCustomerLanguage(newLang);

    if (mounted) {
      setState(() {});
    }
  }

  String get _storeId => (widget.storeIdFromUrl ?? '').trim();

  Customer? get _customer => widget.customer ?? _loggedInCustomer;

  bool get _isLoggedIn => _customer != null || _auth.currentUser != null;

  @override
  void dispose() {
    _storeSub?.cancel();
    _categorySub?.cancel();
    _productSub?.cancel();
    _notificationSub?.cancel();
    _authSub?.cancel();
    _searchController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _sessionTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _resolveAndStart() async {
    try {
      if (_storeId.isEmpty || _storeId == 'default_store') {
        throw StateError('invalid_store_id'.tr);
      }

      _resolvedStoreId = _storeId;

      if (Get.isRegistered<ProductController>()) {
        _productController = Get.find<ProductController>();
      }
      if (Get.isRegistered<CustomerController>()) {
        _customerController = Get.find<CustomerController>();
      }
      if (Get.isRegistered<OrderController>()) {
        _orderController = Get.find<OrderController>();
      }

      _startStoreStream();
      _startCategoryStream();
      _startProductStream();

      _authSub = _auth.authStateChanges().listen((user) async {
        if (!mounted) return;

        if (user != null) {
          await _loadCustomerFromAuth(user);
        } else if (widget.customer == null && !_restoringCredentialSession) {
          setState(() {
            _loggedInCustomer = null;
          });
          await _notificationSub?.cancel();
          _notificationSub = null;
          _notificationsCount.value = 0;
        }

        if (mounted) {
          setState(() => _initializing = false);
        }
      });

      if (widget.customer != null) {
        _loggedInCustomer = widget.customer;
        _restoringCredentialSession = false;
        await _startCustomerServices(widget.customer!);
      } else if (_auth.currentUser != null) {
        _restoringCredentialSession = false;
        await _loadCustomerFromAuth(_auth.currentUser!);
      } else {
        await _restoreCredentialSession();
        _restoringCredentialSession = false;
      }

      if (mounted) {
        setState(() => _initializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  void _startStoreStream() {
    _storeSub?.cancel();

    _storeSub = _firestore
        .collection('stores')
        .doc(_resolvedStoreId)
        .snapshots()
        .listen(
          (doc) {
        if (!mounted) return;

        if (!doc.exists) {
          setState(() {
            _storeExists = false;
            _error = 'store_not_found'.tr;
          });
          return;
        }

        final data = doc.data() ?? {};

        setState(() {
          _storeExists = true;
          _storeName = (data['name'] ?? data['store_name'] ?? 'store'.tr).toString();
          _storeLogo = (data['logo_url'] ?? data['logo'] ?? data['image'])?.toString();
          _currency = (data['currency'] ?? data['currency_symbol'] ?? _currency).toString();
          _error = null;
          _online = true;
        });
      },
      onError: (error) {
        debugPrint('Store stream error: $error');
        if (!mounted) return;

        setState(() {
          _online = false;
          _error = 'store_connection_error'.tr;
        });
      },
    );
  }

  void _startCategoryStream() {
    _categorySub?.cancel();

    _categorySub = _firestore
        .collection('categories')
        .doc(_resolvedStoreId)
        .snapshots()
        .listen(
          (doc) {
        final data = doc.data() ?? {};
        final raw = data['custom_categories_data'];
        final result = <CustomCategory>[];

        if (raw is List) {
          for (final item in raw) {
            try {
              if (item is Map) {
                result.add(
                  CustomCategory.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                );
              }
            } catch (e) {
              debugPrint('Category parse error: $e');
            }
          }
        }

        if (!mounted) return;

        setState(() {
          _categories = result;
          if (_selectedCategoryIndex > _categories.length) {
            _selectedCategoryIndex = 0;
          }
        });
      },
      onError: (error) {
        debugPrint('Category stream error: $error');
        if (!mounted) return;
        setState(() => _categories = []);
      },
    );
  }

  void _startProductStream() {
    _productSub?.cancel();

    _productSub = _firestore
        .collection('products')
        .where('store_id', isEqualTo: _resolvedStoreId)
        .snapshots()
        .listen(
          (snapshot) {
        final result = <Product>[];

        for (final doc in snapshot.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = (data['id'] ?? doc.id).toString();
            data['price'] = _toDouble(data['price']);
            data['rating'] = _toDouble(data['rating']);
            data['stock'] = _toInt(data['stock']);
            data['reviewCount'] = _toInt(data['reviewCount']);
            data['name'] = (data['name'] ?? '').toString();
            data['description'] = (data['description'] ?? '').toString();
            data['category'] = (data['category'] ?? '').toString();
            data['imagePath'] = (data['imagePath'] ?? 'assets/images/product_placeholder.png').toString();
            data['additionalImages'] = List<String>.from(data['additionalImages'] ?? []);
            data['isAvailable'] = data['isAvailable'] ?? true;

            if (data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
            }
            data['createdAt'] ??= DateTime.now().toIso8601String();

            result.add(Product.fromJson(data));
          } catch (e) {
            debugPrint('Product parse error ${doc.id}: $e');
          }
        }

        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (!mounted) return;

        setState(() {
          _products = result;
          _online = true;
        });

        final pc = _productController;
        if (pc != null) {
          pc.products.assignAll(result);
          pc.filteredProducts.assignAll(result);
          pc.filterProducts();
        }
      },
      onError: (error) {
        debugPrint('Product stream error: $error');
        if (!mounted) return;
        setState(() {
          _online = false;
          _error = 'products_load_error'.tr;
        });
      },
    );
  }

  Future<void> _loadCustomerFromAuth(User user) async {
    try {
      final uid = user.uid;
      DocumentSnapshot<Map<String, dynamic>> doc = await _firestore.collection('customers').doc(uid).get();

      if (!doc.exists) {
        final email = user.email?.trim().toLowerCase();
        if (email != null && email.isNotEmpty) {
          final q = await _firestore
              .collection('customers')
              .where('email', isEqualTo: email)
              .where('store_id', isEqualTo: _resolvedStoreId)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            doc = q.docs.first;
          }
        }
      }

      if (!doc.exists) {
        if (widget.customer == null && mounted) {
          setState(() {
            _loggedInCustomer = null;
            _error = 'customer_account_not_found'.tr;
          });
        }
        return;
      }

      final data = doc.data() ?? {};
      final store = (data['store_id'] ?? data['storeId'] ?? '').toString().trim();
      final active = data['isActive'] ?? true;

      if (store.isNotEmpty && store != _resolvedStoreId) {
        throw StateError('account_not_linked'.tr);
      }

      if (active == false) {
        throw StateError('account_inactive'.tr);
      }

      final customer = Customer(
        id: doc.id,
        name: (data['name'] ?? '').toString(),
        phone: (data['phone'] ?? user.phoneNumber ?? '').toString(),
        password: '',
        isActive: true,
        loginMethod: 'firebase_auth',
        storeId: _resolvedStoreId,
      );

      if (!mounted) return;

      setState(() {
        _loggedInCustomer = customer;
        _error = null;
      });

      if (_customerController != null) {
        _customerController!.customers.removeWhere((c) => c.id == customer.id);
        _customerController!.customers.add(customer);
      }

      await _startCustomerServices(customer);
    } catch (e) {
      debugPrint('Customer profile error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _startCustomerServices(Customer customer) async {
    await _notificationSub?.cancel();
    _notificationSub = null;

    if (customer.id.isEmpty) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('customers').doc(customer.id).set(
          {
            'fcmToken': token,
            'store_id': _resolvedStoreId,
            'lastActive': FieldValue.serverTimestamp(),
            'isOnline': true,
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('FCM token update error: $e');
    }

    _notificationSub = _firestore
        .collection('notifications')
        .where('storeId', isEqualTo: _resolvedStoreId)
        .where('customerId', isEqualTo: customer.id)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
        if (!mounted) return;

        _notificationsCount.value = snapshot.docs.length;

        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null) continue;

          _showTopNotification(
            title: (data['title'] ?? 'new_notification'.tr).toString(),
            message: (data['body'] ?? '').toString(),
          );

          _playNotificationSound();
        }
      },
      onError: (error) {
        debugPrint('Notification stream error: $error');
      },
    );
  }

  Future<void> _logout() async {
    try {
      final customer = _customer;
      if (customer != null && customer.id.isNotEmpty) {
        await _firestore.collection('customers').doc(customer.id).set(
          {
            'isOnline': false,
            'lastActive': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await _notificationSub?.cancel();
      _notificationSub = null;
      await _clearCredentialSession();
      await _auth.signOut();

      if (!mounted) return;

      setState(() {
        _loggedInCustomer = null;
        _cart.clear();
        _cartTotal.value = 0;
        _notificationsCount.value = 0;
      });
    } catch (e) {
      _showError('logout_error'.tr);
    }
  }

  Future<void> _saveCredentialSession(Customer customer) async {
    final expiresAt = DateTime.now().add(_sessionDuration).millisecondsSinceEpoch;

    try {
      await _secureStorage.write(key: _sessionCustomerIdKey, value: customer.id);
      await _secureStorage.write(key: _sessionStoreIdKey, value: _resolvedStoreId);
      await _secureStorage.write(key: _sessionExpiresAtKey, value: expiresAt.toString());

      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(
        const Duration(minutes: 1),
            (_) => _checkCredentialSession(),
      );
    } catch (e) {
      debugPrint('Save customer session error: $e');
    }
  }

  Future<void> _restoreCredentialSession() async {
    try {
      final customerId = await _secureStorage.read(key: _sessionCustomerIdKey);
      final sessionStoreId = await _secureStorage.read(key: _sessionStoreIdKey);
      final expiresRaw = await _secureStorage.read(key: _sessionExpiresAtKey);

      if (customerId == null || customerId.trim().isEmpty ||
          sessionStoreId == null || sessionStoreId != _resolvedStoreId ||
          expiresRaw == null || expiresRaw.trim().isEmpty) {
        return;
      }

      final expiresAt = int.tryParse(expiresRaw.trim());
      if (expiresAt == null) {
        await _clearCredentialSession();
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= expiresAt) {
        await _clearCredentialSession();
        return;
      }

      final doc = await _firestore.collection('customers').doc(customerId).get();
      if (!doc.exists) {
        await _clearCredentialSession();
        return;
      }

      final data = doc.data() ?? {};
      final customerStore = (data['store_id'] ?? data['storeId'] ?? '').toString().trim();

      if (customerStore != _resolvedStoreId) {
        await _clearCredentialSession();
        return;
      }

      if ((data['isActive'] ?? true) == false) {
        await _clearCredentialSession();
        return;
      }

      final name = (data['name'] ?? '').toString().trim();
      final password = (data['password'] ?? '').toString().trim();

      if (name.isEmpty || password.isEmpty) {
        await _clearCredentialSession();
        return;
      }

      final customer = Customer(
        id: doc.id,
        name: name,
        phone: (data['phone'] ?? '').toString(),
        password: password,
        isActive: true,
        loginMethod: 'credentials',
        storeId: _resolvedStoreId,
      );

      if (!mounted) return;

      setState(() {
        _loggedInCustomer = customer;
        _error = null;
      });

      if (_customerController != null) {
        _customerController!.customers.removeWhere((c) => c.id == customer.id);
        _customerController!.customers.add(customer);
      }

      await _startCustomerServices(customer);
      _startSessionTimer(expiresAt);
    } catch (e, stack) {
      debugPrint('Restore customer session error: $e');
      debugPrint(stack.toString());
      await _clearCredentialSession();
    }
  }

  void _startSessionTimer(int expiresAt) {
    _sessionTimer?.cancel();
    final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch;

    if (remaining <= 0) {
      _expireCredentialSession();
      return;
    }

    _checkCredentialSession();

    _sessionTimer = Timer.periodic(
      const Duration(minutes: 5),
          (_) => _checkCredentialSession(),
    );
  }

  Future<void> _checkCredentialSession() async {
    final expiresRaw = await _secureStorage.read(key: _sessionExpiresAtKey);
    final expiresAt = int.tryParse(expiresRaw ?? '');
    if (expiresAt == null || DateTime.now().millisecondsSinceEpoch >= expiresAt) {
      await _expireCredentialSession();
    }
  }

  Future<void> _expireCredentialSession() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;

    final customer = _customer;
    if (customer != null && customer.id.isNotEmpty) {
      try {
        await _firestore.collection('customers').doc(customer.id).set(
          {
            'isOnline': false,
            'lastActive': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }

    await _clearCredentialSession();
    await _notificationSub?.cancel();
    _notificationSub = null;

    if (!mounted) return;

    setState(() {
      _loggedInCustomer = null;
      _notificationsCount.value = 0;
      _cart.clear();
      _cartTotal.value = 0;
    });

    _showError('session_expired'.tr);
  }

  Future<void> _clearCredentialSession() async {
    try {
      await _secureStorage.delete(key: _sessionCustomerIdKey);
      await _secureStorage.delete(key: _sessionStoreIdKey);
      await _secureStorage.delete(key: _sessionExpiresAtKey);
    } catch (e) {
      debugPrint('Clear customer session error: $e');
    }
  }

  Future<void> _markNotificationRead(DocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      await doc.reference.update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Mark notification read error: $e');
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final customer = _customer;
    if (customer == null) return;

    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('storeId', isEqualTo: _resolvedStoreId)
          .where('customerId', isEqualTo: customer.id)
          .where('isRead', isEqualTo: false)
          .limit(400)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      _showError('notifications_update_error'.tr);
    }
  }

  void _showCustomerNotifications() {
    final customer = _customer;
    if (customer == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * .72,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_rounded, color: _gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'notifications'.tr,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: _markAllNotificationsRead,
                      child: Text('mark_all_read'.tr),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore
                      .collection('notifications')
                      .where('storeId', isEqualTo: _resolvedStoreId)
                      .where('customerId', isEqualTo: customer.id)
                      .orderBy('createdAt', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _emptyState(Icons.cloud_off_rounded, 'notifications_load_error'.tr);
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: _gold));
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return _emptyState(Icons.notifications_none_rounded, 'no_notifications'.tr);
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final read = data['isRead'] == true;

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _markNotificationRead(doc),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: read ? const Color(0xFFF8F9FB) : const Color(0xFFFFFBEC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: read ? Colors.black.withOpacity(.06) : _gold.withOpacity(.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: read ? Colors.black.withOpacity(.05) : _gold.withOpacity(.13),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    _notificationIcon(data['type']),
                                    color: read ? Colors.grey : _gold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (data['title'] ?? 'notification'.tr).toString(),
                                        style: TextStyle(
                                          fontWeight: read ? FontWeight.w600 : FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        (data['body'] ?? '').toString(),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          height: 1.45,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 5),
                                    decoration: const BoxDecoration(
                                      color: _gold,
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
        );
      },
    );
  }

  IconData _notificationIcon(dynamic type) {
    switch (type?.toString()) {
      case 'order_created':
        return Icons.receipt_long_rounded;
      case 'order_preparing':
        return Icons.restaurant_rounded;
      case 'order_ready':
        return Icons.check_circle_rounded;
      case 'order_delivered':
        return Icons.local_shipping_rounded;
      case 'order_cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification2.mp3'));
    } catch (_) {}
  }

  void _showTopNotification({required String title, required String message}) {
    if (!mounted) return;

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      borderRadius: 18,
      backgroundColor: _navy,
      colorText: Colors.white,
      icon: const Icon(Icons.notifications_active_rounded, color: _goldLight),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _submitOrder() async {
    final customer = _customer;

    if (customer == null) {
      _showError('login_required'.tr);
      return;
    }

    if (_cart.isEmpty) {
      _showError('cart_empty'.tr);
      return;
    }

    setState(() => _loadingOrder = true);

    try {
      final orderRef = _firestore.collection('orders').doc();
      final fcmToken = await FirebaseMessaging.instance.getToken();

      final items = _cart.map((item) {
        return {
          'productId': item.productId,
          'productName': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
        };
      }).toList();

      await orderRef.set({
        'id': orderRef.id,
        'customerId': customer.id,
        'customerName': customer.name,
        'customerPhone': customer.phone,
        'customerEmail': _auth.currentUser?.email ?? '',
        'items': items,
        'totalAmount': _cartTotal.value,
        'status': 'pending',
        'isRead': false,
        'storeId': _resolvedStoreId,
        'store_id': _resolvedStoreId,
        'customerToken': fcmToken ?? '',
        'accessMethod': 'credentials',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _cart.clear();
      _cartTotal.value = 0;

      Navigator.of(context).pop();

      Get.snackbar(
        'order_sent'.tr,
        'order_sent_success'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: _navy,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle_rounded, color: _goldLight),
      );
    } on FirebaseException catch (e) {
      _showError(
        e.code == 'permission-denied'
            ? 'no_order_permission'.tr
            : '${'order_send_error'.tr}: ${e.message ?? e.code}',
      );
    } catch (e) {
      debugPrint('Order upload error: $e');
      _showError('order_send_error'.tr);
    } finally {
      if (mounted) {
        setState(() => _loadingOrder = false);
      }
    }
  }

  void _addToCart(Product product, {int quantity = 1}) {
    if (!product.isAvailable) {
      _showError('product_unavailable'.tr);
      return;
    }

    if (product.stock > 0 && quantity > product.stock) {
      quantity = product.stock;
    }

    final index = _cart.indexWhere((e) => e.productId == product.id);

    if (index == -1) {
      _cart.add(
        OrderItem(
          productId: product.id,
          productName: product.name,
          price: product.price,
          quantity: quantity,
          total: product.price * quantity,
        ),
      );
    } else {
      final old = _cart[index];
      final nextQty = old.quantity + quantity;
      final limited = product.stock > 0 ? nextQty.clamp(1, product.stock) : nextQty;

      _cart[index] = OrderItem(
        productId: old.productId,
        productName: old.productName,
        price: product.price,
        quantity: limited,
        total: product.price * limited,
      );
    }

    _refreshCartTotal();

    Get.snackbar(
      'added_to_cart'.tr,
      product.name,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(14),
      borderRadius: 16,
      backgroundColor: _navy,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
      icon: const Icon(Icons.shopping_cart_checkout_rounded, color: _goldLight),
    );
  }

  void _changeCartQuantity(OrderItem item, int delta) {
    final index = _cart.indexWhere((e) => e.productId == item.productId);
    if (index == -1) return;

    final product = _findProduct(item.productId);
    final newQty = item.quantity + delta;

    if (newQty <= 0) {
      _cart.removeAt(index);
    } else {
      final limited = product != null && product.stock > 0 ? newQty.clamp(1, product.stock) : newQty;
      _cart[index] = OrderItem(
        productId: item.productId,
        productName: item.productName,
        price: item.price,
        quantity: limited,
        total: item.price * limited,
      );
    }

    _refreshCartTotal();
  }

  Product? _findProduct(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  void _refreshCartTotal() {
    _cartTotal.value = _cart.fold<double>(0, (sum, item) => sum + item.total);
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PremiumCartSheet(
          cart: _cart,
          total: _cartTotal,
          oc: _orderController ?? OrderController(),
          loggedInCustomer: _loggedInCustomer,
          currency: _currency,
          uploadOrder: _uploadOrderToCloud,
        );
      },
    );
  }

  Future<void> _uploadOrderToCloud(Order order) async {
    try {
      final orderRef = _firestore.collection('orders').doc();
      final fcmToken = await FirebaseMessaging.instance.getToken();

      final items = order.items.map((item) {
        return {
          'productId': item.productId,
          'productName': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
        };
      }).toList();

      await orderRef.set({
        'id': orderRef.id,
        'customerId': order.customerId,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'customerEmail': _auth.currentUser?.email ?? '',
        'items': items,
        'totalAmount': order.totalAmount,
        'notes': order.notes,
        'status': 'pending',
        'isRead': false,
        'storeId': _resolvedStoreId,
        'store_id': _resolvedStoreId,
        'customerToken': fcmToken ?? '',
        'accessMethod': 'credentials',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Upload order error: $e');
      rethrow;
    }
  }

  String _normalizePhone(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();

    for (final ch in value.trim().split('')) {
      final a = arabic.indexOf(ch);
      final p = persian.indexOf(ch);
      if (a >= 0) {
        buffer.write(a);
      } else if (p >= 0) {
        buffer.write(p);
      } else {
        buffer.write(ch);
      }
    }

    return buffer.toString().replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findCustomerByPhone(String phone) async {
    final candidates = <DocumentSnapshot<Map<String, dynamic>>>[];
    final numericPhone = int.tryParse(phone);

    if (numericPhone != null) {
      final q = await _firestore
          .collection('customers')
          .where('phone', isEqualTo: numericPhone)
          .limit(50)
          .get();
      candidates.addAll(q.docs);
    }

    final stringQuery = await _firestore
        .collection('customers')
        .where('phone', isEqualTo: phone)
        .limit(50)
        .get();
    candidates.addAll(stringQuery.docs);

    final unique = <String, DocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in candidates) doc.id: doc,
    };

    for (final doc in unique.values) {
      final data = doc.data() ?? {};
      final customerStore = (data['store_id'] ?? data['storeId'] ?? '').toString().trim();
      final customerPhone = _normalizePhone((data['phone'] ?? '').toString());
      final isActive = data['isActive'] ?? true;

      if (isActive != false && customerPhone == phone && customerStore == _resolvedStoreId) {
        return doc;
      }
    }

    return null;
  }

  Future<void> _verifyCustomerPhone() async {
    FocusScope.of(context).unfocus();

    final phone = _normalizePhone(_loginPhoneController.text);

    if (phone.length < 7) {
      setState(() {
        _error = 'invalid_phone'.tr;
        _phoneVerified = false;
        _verifiedCustomerData = null;
        _verifiedCustomerId = null;
      });
      return;
    }

    if (_resolvedStoreId.isEmpty) {
      setState(() {
        _error = 'invalid_store_id'.tr;
      });
      return;
    }

    setState(() {
      _verifyingPhone = true;
      _error = null;
    });

    try {
      final doc = await _findCustomerByPhone(phone);

      if (doc == null) {
        if (!mounted) return;
        setState(() {
          _verifyingPhone = false;
          _phoneVerified = false;
          _verifiedCustomerData = null;
          _verifiedCustomerId = null;
          _error = 'phone_not_registered'.tr;
        });
        return;
      }

      final data = doc.data() ?? {};
      final isActive = data['isActive'] ?? true;

      if (isActive == false) {
        if (!mounted) return;
        setState(() {
          _verifyingPhone = false;
          _phoneVerified = false;
          _verifiedCustomerData = null;
          _verifiedCustomerId = null;
          _error = 'account_inactive_contact_store'.tr;
        });
        return;
      }

      if (!mounted) return;
      final storedName = (data['name'] ?? '').toString().trim();
      final storedPassword = (data['password'] ?? '').toString().trim();
      final hasPassword = storedPassword.isNotEmpty;

      if (!mounted) return;
      setState(() {
        _verifyingPhone = false;
        _phoneVerified = true;
        _verifiedCustomerId = doc.id;
        _verifiedCustomerData = data;
        _error = null;
        _registerNameController.text = storedName;
        _loginPasswordController.clear();
        _registerPasswordController.clear();
        _registerConfirmPasswordController.clear();
      });

      Get.snackbar(
        'verified'.tr,
        'phone_registered'.tr,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(14),
        borderRadius: 16,
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        icon: const Icon(Icons.verified_rounded, color: Colors.white),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Phone verification error: $e');
      if (!mounted) return;
      setState(() {
        _verifyingPhone = false;
        _phoneVerified = false;
        _verifiedCustomerData = null;
        _verifiedCustomerId = null;
        _error = 'phone_verify_error'.tr;
      });
    }
  }

  void _resetPhoneVerification() {
    setState(() {
      _phoneVerified = false;
      _verifiedCustomerData = null;
      _verifiedCustomerId = null;
      _loginPasswordController.clear();
      _registerNameController.clear();
      _registerPasswordController.clear();
      _registerConfirmPasswordController.clear();
      _passwordVisible = false;
      _error = null;
    });
  }

  Future<void> _loginWithExistingCustomer() async {
    if (_verifiedCustomerId == null || _verifiedCustomerData == null) return;

    final password = _loginPasswordController.text;
    if (password.isEmpty) {
      _showError('password_required'.tr);
      return;
    }

    final storedHash = (_verifiedCustomerData!['password'] ?? '').toString().trim();
    if (storedHash.isEmpty) {
      _showError('account_not_registered'.tr);
      return;
    }

    if (Customer.hashPassword(password) != storedHash) {
      _showError('wrong_password'.tr);
      return;
    }

    await _finishCredentialLogin();
  }

  Future<void> _completeCustomerRegistration() async {
    if (_verifiedCustomerId == null || _verifiedCustomerData == null) return;

    final name = _registerNameController.text.trim();
    final password = _registerPasswordController.text;
    final confirm = _registerConfirmPasswordController.text;

    if (name.isEmpty) {
      _showError('name_required'.tr);
      return;
    }
    if (password.length < 6) {
      _showError('password_short'.tr);
      return;
    }
    if (password != confirm) {
      _showError('password_mismatch'.tr);
      return;
    }

    final currentData = _verifiedCustomerData!;
    final existingPassword = (currentData['password'] ?? '').toString().trim();
    if (existingPassword.isNotEmpty) {
      _showError('account_exists_login'.tr);
      return;
    }

    setState(() {
      _authenticating = true;
      _error = null;
    });

    try {
      final customerId = _verifiedCustomerId!;
      final phone = (currentData['phone'] ?? _loginPhoneController.text).toString();
      final passwordHash = Customer.hashPassword(password);

      await _firestore.collection('customers').doc(customerId).set({
        'id': customerId,
        'name': name,
        'phone': phone,
        'password': passwordHash,
        'isActive': true,
        'loginMethod': 'credentials',
        'lastActive': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));

      final updatedData = Map<String, dynamic>.from(currentData);
      updatedData.addAll({
        'id': customerId,
        'name': name,
        'phone': phone,
        'password': passwordHash,
        'isActive': true,
        'loginMethod': 'credentials',
      });

      _verifiedCustomerData = updatedData;
      await _finishCredentialLogin();
    } catch (e) {
      debugPrint('Customer registration error: $e');
      if (mounted) {
        setState(() => _authenticating = false);
      }
      _showError('registration_error'.tr);
    }
  }

  Future<void> _finishCredentialLogin() async {
    if (_verifiedCustomerId == null || _verifiedCustomerData == null) return;

    final data = _verifiedCustomerData!;
    final customer = Customer(
      id: _verifiedCustomerId!,
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? _loginPhoneController.text).toString(),
      password: (data['password'] ?? '').toString(),
      isActive: data['isActive'] ?? true,
      loginMethod: 'credentials',
      storeId: (data['store_id'] ?? data['storeId'] ?? _resolvedStoreId).toString(),
    );

    setState(() {
      _authenticating = true;
      _error = null;
      _loggedInCustomer = customer;
    });

    try {
      if (_customerController != null) {
        _customerController!.customers.removeWhere((c) => c.id == customer.id);
        _customerController!.customers.add(customer);
      }

      await _startCustomerServices(customer);
      await _saveCredentialSession(customer);

      if (!mounted) return;
      setState(() {
        _authenticating = false;
        _phoneVerified = false;
        _verifiedCustomerData = null;
        _verifiedCustomerId = null;
        _loginPasswordController.clear();
      });

      Get.snackbar(
        'login_success'.tr,
        '${'welcome_message'.tr} ${customer.name.isNotEmpty ? customer.name : ''}',
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(14),
        borderRadius: 16,
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Customer login completion error: $e');
      if (mounted) {
        setState(() {
          _authenticating = false;
          _loggedInCustomer = null;
        });
      }
      _showError('login_error'.tr);
    }
  }

  Widget _buildLoginTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _gold),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _gold, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildLoginScreen() {
    final verifiedName = (_verifiedCustomerData?['name'] ?? '').toString().trim();
    final storedPassword = (_verifiedCustomerData?['password'] ?? '').toString().trim();
    final hasPassword = _phoneVerified && storedPassword.isNotEmpty;
    final needsRegistration = _phoneVerified && storedPassword.isEmpty;

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ✅ زر تغيير اللغة في شاشة الدخول
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Obx(() {
                      return TextButton.icon(
                        onPressed: _toggleCustomerLanguage,
                        icon: const Icon(Icons.language_rounded, size: 18),
                        label: Text(
                          _customerLocale.value == 'en' ? 'العربية' : 'English',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }),
                  ),
                  _brandMark(),
                  const SizedBox(height: 20),
                  Text(
                    _storeName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _navy),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !_phoneVerified
                        ? 'enter_phone_verify'.tr
                        : needsRegistration
                        ? 'complete_registration'.tr
                        : 'enter_password_continue'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 25),
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildLoginTextField(
                    controller: _loginPhoneController,
                    label: 'phone_number'.tr,
                    hint: 'phone_hint'.tr,
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    enabled: !_phoneVerified && !_verifyingPhone && !_authenticating,
                    suffixIcon: _phoneVerified
                        ? const Icon(Icons.verified_rounded, color: Colors.green)
                        : null,
                  ),
                  const SizedBox(height: 12),

                  if (!_phoneVerified)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (_verifyingPhone || _authenticating) ? null : _verifyCustomerPhone,
                        icon: _verifyingPhone
                            ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.verified_user_rounded),
                        label: Text(
                          _verifyingPhone ? 'verifying'.tr : 'verify_phone'.tr,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: (needsRegistration ? Colors.green : Colors.blue).withOpacity(.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (needsRegistration ? Colors.green : Colors.blue).withOpacity(.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            needsRegistration ? Icons.person_add_alt_1_rounded : Icons.check_circle_rounded,
                            color: needsRegistration ? Colors.green : Colors.blue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              needsRegistration
                                  ? 'phone_added_complete_registration'.tr
                                  : verifiedName.isNotEmpty
                                  ? '${'account_found_for'.tr} $verifiedName'
                                  : 'account_found'.tr,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: needsRegistration ? Colors.green.shade800 : Colors.blue.shade800,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _authenticating ? null : _resetPhoneVerification,
                            child: Text('change'.tr),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (hasPassword) ...[
                      _buildLoginTextField(
                        controller: _loginPasswordController,
                        label: 'password'.tr,
                        hint: 'enter_password'.tr,
                        icon: Icons.lock_rounded,
                        obscureText: !_passwordVisible,
                        keyboardType: TextInputType.visiblePassword,
                        enabled: !_authenticating,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          ),
                          onPressed: _authenticating ? null : () => setState(() => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _authenticating ? null : _loginWithExistingCustomer,
                          icon: _authenticating
                              ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            _authenticating ? 'logging_in'.tr : 'login'.tr,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _navy,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ],

                    if (needsRegistration) ...[
                      _buildLoginTextField(
                        controller: _registerNameController,
                        label: 'name'.tr,
                        hint: 'enter_name'.tr,
                        icon: Icons.person_rounded,
                        enabled: !_authenticating,
                      ),
                      const SizedBox(height: 12),
                      _buildLoginTextField(
                        controller: _registerPasswordController,
                        label: 'create_password'.tr,
                        hint: 'password_min'.tr,
                        icon: Icons.lock_outline_rounded,
                        obscureText: !_passwordVisible,
                        keyboardType: TextInputType.visiblePassword,
                        enabled: !_authenticating,
                      ),
                      const SizedBox(height: 12),
                      _buildLoginTextField(
                        controller: _registerConfirmPasswordController,
                        label: 'confirm_password'.tr,
                        hint: 'reenter_password'.tr,
                        icon: Icons.lock_reset_rounded,
                        obscureText: !_passwordVisible,
                        keyboardType: TextInputType.visiblePassword,
                        enabled: !_authenticating,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          ),
                          onPressed: _authenticating ? null : () => setState(() => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _authenticating ? null : _completeCustomerRegistration,
                          icon: _authenticating
                              ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.person_add_rounded),
                          label: Text(
                            _authenticating ? 'creating_account'.tr : 'create_and_login'.tr,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'phone_verify_notice'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandMark() {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_goldLight, _gold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.shopping_bag_rounded,
        size: 38,
        color: Colors.white,
      ),
    );
  }

  Widget _buildShoppingScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF070C14) : _page,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildStoreHeader(isDark),
            _buildCartBar(isDark),
            _buildSearchBar(isDark),
            _buildViewButtons(isDark),
            const SizedBox(height: 4),
            Expanded(
              child: _buildCatalog(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => _searchQuery.value = value,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'search_products_hint'.tr,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Obx(
                () => _searchQuery.value.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
              onPressed: () {
                _searchController.clear();
                _searchQuery.value = '';
              },
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF101827) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildViewButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
              colors: [
                const Color(0xFF1B2435).withOpacity(0.8),
                const Color(0xFF0D1320).withOpacity(0.8),
              ],
            )
                : LinearGradient(
              colors: [
                Colors.white.withOpacity(0.9),
                const Color(0xFFF0F2F5).withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _viewButton(Icons.grid_view_rounded, 1, isDark, tooltip: 'products_view'.tr),
              const SizedBox(width: 4),
              _viewButton(Icons.view_list_rounded, 0, isDark, tooltip: 'list_view'.tr),
              const SizedBox(width: 4),
              _viewButton(Icons.category_rounded, 2, isDark, tooltip: 'categories_view'.tr),
              if (_viewMode == 1) ...[
                const SizedBox(width: 4),
                _productSizeButton(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 48,
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: widget.showBackButton,
      titleSpacing: 14,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_goldLight, _gold]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'my_store_service'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                Text(
                  _storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Obx(() {
          return TextButton(
            onPressed: _toggleCustomerLanguage,
            child: Text(
              _customerLocale.value == 'en' ? 'عربي' : 'EN',
              style: const TextStyle(
                color: _goldLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }),
        Obx(
              () => Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _showCustomerNotifications,
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'notifications'.tr,
              ),
              if (_notificationsCount.value > 0)
                Positioned(
                  top: 8,
                  right: 6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      '${_notificationsCount.value > 99 ? 99 : _notificationsCount.value}',
                      style: const TextStyle(color: _navy, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: _showAccountMenu,
          icon: const Icon(Icons.account_circle_outlined),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  void _showAccountMenu() {
    final customer = _customer;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 28,
                backgroundColor: _navy,
                child: Text(
                  (customer?.name.isNotEmpty == true ? customer!.name.characters.first : 'c'.tr).toUpperCase(),
                  style: const TextStyle(color: _goldLight, fontWeight: FontWeight.w900, fontSize: 21),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                customer?.name ?? 'customer'.tr,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              if ((customer?.phone ?? '').isNotEmpty)
                Text(
                  customer!.phone,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              const SizedBox(height: 18),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                tileColor: const Color(0xFFF7F8FA),
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: Text(
                  'logout'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _navy2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _storeLogoWidget(),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _online ? Colors.greenAccent : Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_online ? Colors.greenAccent : Colors.redAccent).withOpacity(.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _online ? 'live_products'.tr : 'unstable_connection'.tr,
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withOpacity(.08)),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_rounded, color: _goldLight, size: 18),
                const SizedBox(height: 2),
                Text(
                  '${_products.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _storeLogoWidget() {
    if (_storeLogo != null && _storeLogo!.trim().isNotEmpty) {
      final path = _storeLogo!.trim();

      if (path.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Image.network(
            path,
            width: 58,
            height: 58,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _logoPlaceholder(),
          ),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Image.asset(
          path,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _logoPlaceholder(),
        ),
      );
    }

    return _logoPlaceholder();
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_goldLight, _gold]),
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 27),
    );
  }

  Widget _buildCartBar(bool isDark) {
    return Obx(
          () => Padding(
        padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
        child: InkWell(
          onTap: _showCart,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: _cart.isEmpty ? null : const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [_navy, _navy2],
              ),
              color: _cart.isEmpty ? (isDark ? const Color(0xFF101827) : Colors.white) : null,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _cart.isEmpty
                    ? (isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.06))
                    : _gold.withOpacity(.55),
                width: _cart.isEmpty ? 1 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _cart.isEmpty ? Colors.black.withOpacity(.05) : _gold.withOpacity(.13),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: _cart.isEmpty ? _navy : _gold.withOpacity(.18),
                    borderRadius: BorderRadius.circular(12),
                    border: _cart.isEmpty ? null : Border.all(color: _gold.withOpacity(.35)),
                  ),
                  child: const Icon(Icons.shopping_cart_rounded, color: _goldLight, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _cart.isEmpty
                        ? 'cart_empty'.tr
                        : '${_cart.length} ${_cart.length == 1 ? 'item'.tr : 'items'.tr} ${'in_cart'.tr}',
                    style: TextStyle(
                      color: _cart.isEmpty ? (isDark ? Colors.white : _navy) : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${_cartTotal.value.toStringAsFixed(2)} $_currency',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _gold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: _gold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalog(bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (_viewMode == 2)
          _buildCategoryCardsSliver(isDark)
        else ...[
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(child: _buildCategories(isDark)),
          if (_error != null && _products.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _errorState())
          else if (_filteredProducts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(
                Icons.inventory_2_outlined,
                _searchQuery.value.isEmpty ? 'no_products'.tr : 'no_search_results'.tr,
              ),
            )
          else
            _buildProductSliver(isDark),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _productSizeButton(bool isDark) {
    final isLarge = _productSizeMode == 0;

    return Tooltip(
      message: isLarge ? 'small_view'.tr : 'large_view'.tr,
      child: InkWell(
        onTap: () {
          setState(() {
            _productSizeMode = _productSizeMode == 0 ? 1 : 0;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 35,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101827) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withOpacity(.06)),
          ),
          child: Icon(
            isLarge ? Icons.zoom_out_map_rounded : Icons.zoom_in_map_rounded,
            color: isDark ? Colors.white70 : _navy,
            size: 16,
          ),
        ),
      ),
    );
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.value.trim().toLowerCase();
    Iterable<Product> result = _products;

    if (_selectedCategoryIndex > 0 && _selectedCategoryIndex - 1 < _categories.length) {
      final category = _categories[_selectedCategoryIndex - 1];
      final names = <String>{category.name};

      for (final sub in category.subCategories) {
        names.add(sub.name);
        for (final child in sub.subCategories ?? const <SubCategory>[]) {
          names.add(child.name);
        }
      }

      result = result.where((p) => names.contains(p.category));
    }

    if (query.isNotEmpty) {
      result = result.where(
            (p) => p.name.toLowerCase().contains(query) || p.description.toLowerCase().contains(query),
      );
    }

    return result.toList();
  }

  Widget _buildCategories(bool isDark) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = _selectedCategoryIndex == index;
          final name = index == 0 ? 'all'.tr : _categories[index - 1].name;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                gradient: selected ? const LinearGradient(colors: [_navy, _navy2]) : null,
                color: selected ? null : (isDark ? const Color(0xFF101827) : Colors.white),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: selected ? Colors.transparent : Colors.black.withOpacity(.06),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                name,
                style: TextStyle(
                  color: selected ? Colors.white : (isDark ? Colors.white70 : _navy),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _viewButton(IconData icon, int mode, bool isDark, {String? tooltip}) {
    final selected = _viewMode == mode;

    final button = InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 35,
        height: 38,
        decoration: BoxDecoration(
          color: selected ? _navy : (isDark ? const Color(0xFF101827) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.black.withOpacity(.06),
          ),
        ),
        child: Icon(
          icon,
          color: selected ? _goldLight : (isDark ? Colors.white70 : _navy),
          size: 16,
        ),
      ),
    );

    if (tooltip == null || tooltip.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildCategoryCardsSliver(bool isDark) {
    if (_categories.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _emptyState(Icons.category_outlined, 'no_categories'.tr),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1200 ? 5 : width >= 900 ? 4 : width >= 600 ? 3 : 2;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final category = _categories[index];
            return _categoryImageCard(category, isDark);
          },
          childCount: _categories.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: width < 600 ? .92 : 1.02,
        ),
      ),
    );
  }

  Widget _categoryImageCard(CustomCategory category, bool isDark) {
    final imagePath = (category.imagePath ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Get.to(
                () => SalesCategoryDetailPage(
              category: category,
              cart: _cart,
              total: _cartTotal,
              loggedInCustomer: _loggedInCustomer,
              onCartTap: _showCart,
            ),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101827) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _gold.withOpacity(.20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCategoryImage(imagePath, isDark),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(.08),
                      Colors.black.withOpacity(.72),
                    ],
                    stops: const [0.42, 0.62, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(blurRadius: 5, color: Colors.black54)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _navy.withOpacity(.82),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${category.subCategories.length} ${'sub_categories'.tr}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryImage(String imagePath, bool isDark) {
    if (imagePath.isEmpty) {
      return _categoryImagePlaceholder(isDark);
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _categoryImagePlaceholder(isDark),
      );
    }

    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _categoryImagePlaceholder(isDark),
      );
    }

    if (imagePath.startsWith('blob:')) {
      return ImageHelper.displayImage(
        imagePath: imagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: _categoryImagePlaceholder(isDark),
      );
    }

    return _categoryImagePlaceholder(isDark);
  }

  Widget _categoryImagePlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF14213A), Color(0xFF0B1220)]
              : const [Color(0xFFF8F3E5), Color(0xFFEFE7D1)],
        ),
      ),
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _gold.withOpacity(.16),
            shape: BoxShape.circle,
            border: Border.all(color: _gold.withOpacity(.35)),
          ),
          child: const Icon(Icons.category_rounded, color: _gold, size: 31),
        ),
      ),
    );
  }

  Widget _buildProductSliver(bool isDark) {
    final products = _filteredProducts;

    if (_viewMode == 0) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
            padding: EdgeInsets.fromLTRB(14, index == 0 ? 8 : 4, 14, 4),
            child: _productListCard(products[index], isDark),
          ),
          childCount: products.length,
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;

    int columns;

    if (_productSizeMode == 0) {
      columns = width >= 1400 ? 4 : width >= 1100 ? 3 : width >= 700 ? 3 : 2;
    } else {
      columns = width >= 1400 ? 6 : width >= 1100 ? 5 : width >= 700 ? 4 : 3;
    }

    final aspectRatio = _productSizeMode == 0 ? .68 : .78;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            return _productCard(products[index], isDark);
          },
          childCount: products.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 11,
          mainAxisSpacing: 11,
          childAspectRatio: aspectRatio,
        ),
      ),
    );
  }

  Widget _productCard(Product product, bool isDark) {
    return InkWell(
      onTap: product.isAvailable ? () => _showPremiumProductView(product) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 13,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _productImage(product, double.infinity, double.infinity),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _navy.withOpacity(.92),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${product.price.toStringAsFixed(0)} $_currency',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  if (!product.isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(.5),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'unavailable'.tr,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        product.description.isEmpty ? 'featured_product'.tr : product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          fontSize: 9.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 34,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: product.isAvailable ? () => _addToCart(product) : null,
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                        label: Text(
                          'add_to_cart'.tr,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                          padding: EdgeInsets.zero,
                        ),
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

  Widget _productListCard(Product product, bool isDark) {
    return InkWell(
      onTap: product.isAvailable ? () => _showPremiumProductView(product) : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101827) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _productImage(product, 82, 82),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.description.isEmpty ? 'featured_product'.tr : product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${product.price.toStringAsFixed(2)} $_currency',
                    style: const TextStyle(color: _gold, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: product.isAvailable ? () => _addToCart(product) : null,
              style: IconButton.styleFrom(backgroundColor: _navy),
              icon: const Icon(Icons.add_rounded, color: _goldLight),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumProductView(Product product) {
    final List<String> images = [];

    if (product.imagePath.isNotEmpty) {
      images.add(product.imagePath);
    }

    if (product.additionalImages.isNotEmpty) {
      images.addAll(product.additionalImages);
    }

    if (images.isEmpty) {
      images.add('assets/images/product_placeholder.png');
    }

    final PageController pageController = PageController();
    final RxInt currentIndex = 0.obs;
    final isAddedToCart = _cart.any((item) => item.productId == product.id);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close'.tr,
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return PremiumProductExpandedView(
          product: product,
          images: images,
          pageController: pageController,
          currentIndex: currentIndex,
          cart: _cart,
          total: _cartTotal,
          isDark: Theme.of(context).brightness == Brightness.dark,
          currency: _currency,
          parentContext: context,
          onAddToCart: () {
            _addToCart(product);
          },
          isAddedToCart: isAddedToCart,
        );
      },
    ).then((_) {
      pageController.dispose();
    });
  }

  Widget _productImage(Product product, double width, double height) {
    final path = product.imagePath.trim();

    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _imagePlaceholder();
        },
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }

    try {
      return ImageHelper.displayImage(
        imagePath: path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: _imagePlaceholder(),
      );
    } catch (_) {
      return _imagePlaceholder();
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navy2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Center(
        child: Icon(Icons.shopping_bag_rounded, color: _goldLight, size: 29),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 62, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _error ?? 'error_occurred'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _error = null);
                _startStoreStream();
                _startCategoryStream();
                _startProductStream();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retry'.tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _gold.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _gold, size: 36),
          ),
          const SizedBox(height: 13),
          Text(
            text,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    Get.snackbar(
      'warning'.tr,
      message,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(14),
      borderRadius: 16,
      backgroundColor: _navy,
      colorText: Colors.white,
      icon: const Icon(Icons.info_outline_rounded, color: _goldLight),
      duration: const Duration(seconds: 3),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _page,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _brandMark(),
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: _gold),
                const SizedBox(height: 14),
                Text(
                  'connecting_to_store'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_storeExists && _error != null && _customer == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _page,
          body: _errorState(),
        ),
      );
    }

    if (!_isLoggedIn) {
      return _buildLoginScreen();
    }

    return _buildShoppingScreen();
  }
}