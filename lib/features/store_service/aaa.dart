import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mystore/features/store_service/order_controller.dart';
import 'package:mystore/features/store_service/product_controller.dart';
import 'customer_controller.dart';
import 'subscription_page.dart';
import 'store_register_page.dart';
import 'store_home.dart';
import 'activation_codes_page.dart';
import 'package:mystore/core/services/locale_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoreLoginPage extends StatefulWidget {
  const StoreLoginPage({super.key});

  @override
  State<StoreLoginPage> createState() => _StoreLoginPageState();
}

class _StoreLoginPageState extends State<StoreLoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _linkController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscure = true;
  bool _isOnline = true;
  bool _showLinkField = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final String _demoUsername = '1';
  final String _demoPassword = '000000';
  final String _adminUsername = 'الحمزة';
  final String _adminPassword = 'الحمزة';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    _checkConnectivity();

    ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _linkController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => _isOnline = result != ConnectivityResult.none);
  }

  // ==================== الدخول العادي ====================
  /// ✅ دالة التحقق من تطابق الحساب مع بيانات Hive
  Future<bool> _isSameAccount(String email, String storeId) async {
    final settingsBox = Hive.box('settings');

    final savedEmail = settingsBox.get('store_email', defaultValue: '')?.toString() ?? '';
    final savedStoreId = settingsBox.get('store_id', defaultValue: '')?.toString() ?? '';

    // إذا Hive فارغ - حساب جديد
    if (savedEmail.isEmpty && savedStoreId.isEmpty) {
      return true;
    }

    // ✅ مطابقة بالبريد الإلكتروني أو store_id
    if (savedEmail.isNotEmpty && savedEmail == email) {
      return true;
    }

    if (savedStoreId.isNotEmpty && savedStoreId == storeId) {
      return true;
    }

    return false;
  }

  /// ✅ مسح شامل لكل بيانات Hive
  Future<void> _clearAllHiveData() async {
    print('🔄 مسح شامل لجميع بيانات Hive...');

    try {
      // ✅ 1. مسح جميع الصناديق
      final boxNames = Hive.box('settings').keys.toList();

      for (var boxName in ['products', 'customers', 'orders', 'settings', 'box_name']) {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          await box.clear();
          print('✅ تم مسح $boxName');
        }
      }

      // ✅ 2. إعادة تعيين الإعدادات الأساسية
      final settingsBox = Hive.box('settings');
      final newStoreId = 'store_${DateTime.now().millisecondsSinceEpoch}';
      settingsBox.put('store_id', newStoreId);
      settingsBox.put('store_logged_in', false);

      // ✅ 3. إعادة تحميل المتحكمات فارغة
      try {
        final pc = Get.find<ProductController>();
        final cc = Get.find<CustomerController>();
        final oc = Get.find<OrderController>();

        pc.products.clear();
        cc.customers.clear();
        oc.orders.clear();
      } catch (e) {
        print('⚠️ خطأ في إعادة تحميل المتحكمات: $e');
      }

      print('✅ تم المسح الشامل بنجاح');

    } catch (e) {
      print('❌ خطأ في المسح الشامل: $e');
    }
  }

  /// ✅ دالة التحقق والمسح
  Future<void> _clearHiveDataIfDifferentAccount(String email, String storeId) async {
    final isSame = await _isSameAccount(email, storeId);

    if (!isSame) {
      await _clearAllHiveData();
    } else {
      print('✅ نفس الحساب');
    }
  }

  /// ✅ دالة تسجيل الدخول الكاملة
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final settingsBox = Hive.box('settings');

    // ✅ 1. التحقق من حساب الحمزة (الأدمن)
    if (input == _adminUsername && password == _adminPassword) {
      // ✅ مسح بيانات الحساب السابق
      await _clearHiveDataIfDifferentAccount(_adminUsername, 'admin');
      settingsBox.put('store_logged_in', true);
      settingsBox.put('is_admin', true);
      settingsBox.put('store_name', _adminUsername);
      settingsBox.put('store_id', 'admin');

      setState(() => _isLoading = false);
      _navigateAfterLogin(isAdmin: true);
      return;
    }

    // ✅ 2. التحقق من الحساب التجريبي
    if (input == _demoUsername && password == _demoPassword) {
      await _clearHiveDataIfDifferentAccount('demo', 'demo');
      settingsBox.put('store_logged_in', true);
      settingsBox.put('is_admin', false);
      settingsBox.put('store_name', 'حساب تجريبي');
      settingsBox.put('store_id', 'demo');
      settingsBox.put('trial_end_date', DateTime.now().add(const Duration(days: 14)).toIso8601String());
      settingsBox.put('store_subscribed', false);

      setState(() => _isLoading = false);
      _navigateAfterLogin(isDemo: true);
      return;
    }

    // ✅ 3. البحث في Firebase Firestore (يدعم العربية)
    try {
      QuerySnapshot snapshot;

      if (input.contains('@')) {
        // البحث بالبريد الإلكتروني
        snapshot = await FirebaseFirestore.instance
            .collection('stores')
            .where('email', isEqualTo: input)
            .get();
      } else {
        // البحث بالاسم
        snapshot = await FirebaseFirestore.instance
            .collection('stores')
            .where('name', isEqualTo: input)
            .get();

        // البحث بالاسم مع تجاهل حالة الأحرف
        if (snapshot.docs.isEmpty) {
          final allStores = await FirebaseFirestore.instance
              .collection('stores')
              .get();

          final matchingDoc = allStores.docs.where((doc) {
            final data = doc.data();
            final name = data['name']?.toString() ?? '';
            return name.trim().toLowerCase() == input.trim().toLowerCase();
          }).firstOrNull;

          if (matchingDoc != null) {
            final data = matchingDoc.data();
            final storedPassword = data['password']?.toString() ?? '';
            final storeEmail = data['email']?.toString() ?? '';
            final storeId = matchingDoc.id;

            if (storedPassword.isNotEmpty && storedPassword == password) {
              // ✅ التحقق من تطابق الحساب
              await _clearHiveDataIfDifferentAccount(storeEmail, storeId);

              settingsBox.put('store_email', storeEmail);
              settingsBox.put('store_password', password);
              settingsBox.put('store_phone', data['phone']?.toString() ?? '');
              settingsBox.put('store_name', data['name']?.toString() ?? input);
              settingsBox.put('store_id', storeId);
              settingsBox.put('store_subscribed', data['subscribed'] ?? false);
              settingsBox.put('store_logged_in', true);

              setState(() => _isLoading = false);
              _navigateAfterLogin();
              return;
            } else {
              setState(() => _isLoading = false);
              Get.snackbar('error'.tr, 'wrong_credentials'.tr,
                  backgroundColor: Colors.red, colorText: Colors.white);
              return;
            }
          }
        }

        // البحث بالهاتف
        if (snapshot.docs.isEmpty) {
          snapshot = await FirebaseFirestore.instance
              .collection('stores')
              .where('phone', isEqualTo: input)
              .get();
        }
      }

      if (snapshot.docs.isNotEmpty) {
        final storeDoc = snapshot.docs.first;
        final data = storeDoc.data() as Map<String, dynamic>;
        final storedPassword = data['password']?.toString() ?? '';
        final storeEmail = data['email']?.toString() ?? input;
        final storeId = storeDoc.id;

        if (storedPassword.isNotEmpty && storedPassword == password) {
          // ✅ التحقق من تطابق الحساب مع Hive
          await _clearHiveDataIfDifferentAccount(storeEmail, storeId);
          // ✅ حفظ بيانات الحساب الجديد
          settingsBox.put('store_email', storeEmail);
          settingsBox.put('store_password', password);
          settingsBox.put('store_phone', data['phone']?.toString() ?? '');
          settingsBox.put('store_name', data['name']?.toString() ?? input);
          settingsBox.put('store_id', storeId);
          settingsBox.put('store_subscribed', data['subscribed'] ?? false);
          settingsBox.put('store_logged_in', true);

          setState(() => _isLoading = false);
          _navigateAfterLogin();
          return;
        } else {
          setState(() => _isLoading = false);
          Get.snackbar('error'.tr, 'wrong_credentials'.tr,
              backgroundColor: Colors.red, colorText: Colors.white);
          return;
        }
      }
    } catch (e) {
      print('⚠️ خطأ في البحث في Firestore: $e');
    }

    // ✅ 4. محاولة المصادقة عبر Firebase Authentication
    if (input.contains('@')) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: input,
          password: password,
        );

        if (userCredential.user != null) {
          final userEmail = userCredential.user!.email ?? input;
          final userId = userCredential.user!.uid;

          // ✅ التحقق من تطابق الحساب
          await _clearHiveDataIfDifferentAccount(userEmail, userId);

          settingsBox.put('store_email', userEmail);
          settingsBox.put('store_password', password);
          settingsBox.put('store_id', userId);
          settingsBox.put('store_subscribed', true);
          settingsBox.put('store_logged_in', true);

          setState(() => _isLoading = false);
          _navigateAfterLogin();
          return;
        }
      } catch (e) {
        print('⚠️ خطأ في مصادقة Firebase Auth: $e');
      }
    }

    // ❌ إذا فشل كل شيء
    setState(() => _isLoading = false);
    Get.snackbar(
      'error'.tr,
      'wrong_credentials'.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }


  Future<void> _navigateAfterLogin({bool isAdmin = false, bool isDemo = false}) async {
    final settingsBox = Hive.box('settings');
    settingsBox.put('store_logged_in', true);
    settingsBox.put('is_admin', isAdmin);

    if (isDemo) {
      settingsBox.put('trial_end_date', DateTime.now().add(const Duration(days: 14)).toIso8601String());
      settingsBox.put('store_subscribed', false);
      settingsBox.put('subscription_type', 'trial');
      Get.offAll(() => const StoreServiceHome());
      return;
    }

    if (isAdmin) {
      Get.offAll(() => const ActivationCodesPage());
      return;
    }

    final isSubscribed = settingsBox.get('store_subscribed', defaultValue: false);
    final trialEndDate = settingsBox.get('trial_end_date');

    if (isSubscribed) {
      Get.offAll(() => const StoreServiceHome());
    } else if (trialEndDate != null) {
      final endDate = DateTime.tryParse(trialEndDate.toString()) ?? DateTime.now();
      if (DateTime.now().isBefore(endDate)) {
        Get.offAll(() => const StoreServiceHome());
      } else {
        Get.offAll(() => const SubscriptionPage());
      }
    } else {
      Get.offAll(() => const SubscriptionPage());
    }
  }

  void _changeLanguage() {
    final currentLocale = Get.locale;
    if (currentLocale?.languageCode == 'ar') {
      LocaleService.changeLocale('en');
    } else {
      LocaleService.changeLocale('ar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Get.locale?.languageCode == 'ar';
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1B2D), Color(0xFF1A2332), Color(0xFF2D3A4E)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              // ✅ ملء الشاشة بدون تمرير
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 500 ? 100 : 20,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      // 🌍 زر تغيير اللغة + اسم التطبيق
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ).createShader(b),
                            child: Text(
                              'my_store_service'.tr,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: Text(isArabic ? 'EN' : 'عربي',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              onPressed: _changeLanguage,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isSmallScreen ? 6 : 12),

                      // الشعار
                      Image.asset(
                        'assets/images/logo.png',
                        width: isSmallScreen ? 70 : 90,
                        height: isSmallScreen ? 70 : 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.store_rounded, color: Colors.white, size: 40);
                        },
                      ),

                      SizedBox(height: isSmallScreen ? 6 : 12),

                      // ✅ مساحة مرنة تدفع البطاقة للأسفل (هامش كبير من الأسفل)
                      const Spacer(),

                      // ✅ بطاقة تسجيل الدخول
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 450),
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('login'.tr,
                                style: TextStyle(fontSize: isSmallScreen ? 18 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A2332))),
                            SizedBox(height: isSmallScreen ? 12 : 16),

                            // ✅ حقل اسم المستخدم (يدعم البحث بالعربية)
                            TextFormField(
                              controller: _emailController,
                              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'username_or_email_phone'.tr,
                                prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF1A2332)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 10 : 14),

                            // ✅ حقل كلمة المرور
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'password'.tr,
                                prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF1A2332)),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 14 : 20),

                            // ✅ زر تسجيل الدخول
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A2332),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text('login'.tr, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),

                            // ✅ زر الدخول المتعدد (يظهر حقل الرابط)
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _showLinkField = !_showLinkField);
                              },
                              icon: const Icon(Icons.link_rounded, size: 18),
                              label: const Text('الدخول المتعدد', style: TextStyle(fontSize: 13, color: Color(0xFF2196F3))),
                            ),

                            // ✅ حقل الرابط (يظهر فقط عند الضغط على الدخول المتعدد)
                            if (_showLinkField) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _linkController,
                                      decoration: InputDecoration(
                                        hintText: 'ألصق الرابط هنا',
                                        prefixIcon: const Icon(Icons.link_rounded, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // ✅ زر الكاميرا لتصوير QR Code
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2196F3), size: 28),
                                    onPressed: () => _scanQRCode(),
                                  ),
                                  // ✅ زر اللصق
                                  IconButton(
                                    icon: const Icon(Icons.paste_rounded, color: Colors.grey, size: 22),
                                    onPressed: () async {
                                      final clipboard = await Clipboard.getData('text/plain');
                                      if (clipboard?.text != null) {
                                        _linkController.text = clipboard!.text!;
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],

                            SizedBox(height: isSmallScreen ? 8 : 12),

                            // ✅ زر إنشاء حساب
                            TextButton(
                              onPressed: () => Get.to(() => const StoreRegisterPage()),
                              child: Text('no_account_create'.tr,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1A2332))),
                            ),
                          ],
                        ),
                      ),

                      // ✅ هامش كبير من الأسفل
                      SizedBox(height: isSmallScreen ? 30 : 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ مسح QR Code بالكاميرا
  void _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          onScan: (code) {
            _linkController.text = code;
          },
        ),
      ),
    );
  }
}

// ✅ شاشة تصوير QR Code
class ScannerScreen extends StatefulWidget {
  final Function(String) onScan;

  const ScannerScreen({super.key, required this.onScan});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مسح رمز الدخول', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  widget.onScan(barcode.rawValue!);
                  Navigator.pop(context);
                  break;
                }
              }
            },
          ),
          // ✅ إطار توضيحي
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}