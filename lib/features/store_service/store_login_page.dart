// store_login_page.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mystore/features/store_service/order_controller.dart';
import 'package:mystore/features/store_service/product_controller.dart';
import '../../core/services/session_service.dart';
import '../../core/services/store_id_service.dart';
import '../../core/services/pairing_service.dart';
import 'Backup_Restore_Page.dart';
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
  static const _navy = Color(0xFF091426);
  static const _navy2 = Color(0xFF10213D);
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFF4D77A);
  static const _surface = Color(0xFFF8F9FC);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscure = true;
  bool _isOnline = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Worker? _localeWorker;
  StreamSubscription<dynamic>? _connectivitySubscription;

  final String _demoUsername = '1';
  final String _demoPassword = '000000';
  final String _adminUsername = 'الحمزة';
  final String _adminPassword = 'الحمزة';

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, .055),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
    _checkConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (dynamic result) {
        bool online;
        if (result is List<ConnectivityResult>) {
          online = result.any((item) => item != ConnectivityResult.none);
        } else {
          online = result != ConnectivityResult.none;
        }
        if (mounted && _isOnline != online) {
          setState(() => _isOnline = online);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isOnline = false);
      },
    );

    _localeWorker = ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _localeWorker?.dispose();
    _connectivitySubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final dynamic result = await Connectivity().checkConnectivity();
      final bool online = result is List<ConnectivityResult>
          ? result.any((item) => item != ConnectivityResult.none)
          : result != ConnectivityResult.none;
      if (!mounted) return;
      setState(() => _isOnline = online);
    } catch (_) {
      if (mounted) setState(() => _isOnline = false);
    }
  }

  Future<bool> _isSameAccount(String email, String storeId) async {
    final settingsBox = Hive.box('settings');
    final savedEmail =
        settingsBox.get('store_email', defaultValue: '')?.toString() ?? '';
    final savedStoreId =
        settingsBox.get('store_id', defaultValue: '')?.toString() ?? '';

    if (savedEmail.isEmpty && savedStoreId.isEmpty) return true;
    if (savedEmail.isNotEmpty && savedEmail == email) return true;
    if (savedStoreId.isNotEmpty && savedStoreId == storeId) return true;
    return false;
  }

  Future<void> _clearAllHiveData() async {
    debugPrint('🔄 Clearing all Hive data...');
    try {
      for (final boxName in ['products', 'customers', 'orders', 'settings']) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
        }
      }

      final settingsBox = Hive.box('settings');
      await settingsBox.put(
        'store_id',
        'store_${DateTime.now().millisecondsSinceEpoch}',
      );
      await settingsBox.put('store_logged_in', false);

      try {
        Get.find<ProductController>().products.clear();
        Get.find<CustomerController>().customers.clear();
        Get.find<OrderController>().orders.clear();
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ Clear error: $e');
    }
  }

  Future<void> _clearHiveDataIfDifferentAccount(
      String email,
      String storeId,
      ) async {
    final isSame = await _isSameAccount(email, storeId);
    if (!isSame) await _clearAllHiveData();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final settingsBox = Hive.box('settings');

    // 1. حساب التجربة (Demo)
    if (input == _demoUsername && password == _demoPassword) {
      await _clearHiveDataIfDifferentAccount('demo', 'demo');
      await settingsBox.put('store_logged_in', true);
      await settingsBox.put('is_admin', false);
      await settingsBox.put('store_name', 'demo_account'.tr);
      await settingsBox.put('store_id', 'demo');
      await settingsBox.put(
        'trial_end_date',
        DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      );
      await settingsBox.put('store_subscribed', false);

      if (!mounted) return;
      setState(() => _isLoading = false);
      _navigateAfterLogin(isDemo: true);
      return;
    }

    try {
      String email = input;

      // 2. البحث عن البريد الإلكتروني باسم المستخدم في Firestore
      if (!input.contains('@')) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isEqualTo: input)
            .limit(1)
            .get();

        if (userDoc.docs.isNotEmpty) {
          email = userDoc.docs.first.data()['email']?.toString().trim() ?? '';
        } else {
          final altUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .where('store_name', isEqualTo: input)
              .limit(1)
              .get();

          if (altUserDoc.docs.isNotEmpty) {
            email =
                altUserDoc.docs.first.data()['email']?.toString().trim() ?? '';
          }
        }
      }

      // 3. التأكد من صيغة البريد
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (email.isEmpty || !emailRegex.hasMatch(email)) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Get.snackbar('error'.tr, 'wrong_credentials'.tr);
        return;
      }

      // 4. تسجيل الدخول عبر Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      final user = userCredential.user;
      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Get.snackbar('error'.tr, 'wrong_credentials'.tr);
        return;
      }

      final uid = user.uid;

      // 5. جلب بيانات المستخدم من Firestore
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final foundData = doc.data() ?? {};
      final storeEmail = foundData['email']?.toString() ?? email;
      final storeName = foundData['name']?.toString() ??
          foundData['store_name']?.toString() ??
          email;

      const adminStoreId = 'Yfb0ds0mYJeVanXbRnH2VfvkPYG2';

      // 6. التحقق هل الحساب أدمن
      final bool isAdmin = (uid == adminStoreId) ||
          (foundData['role']?.toString() == 'admin') ||
          (foundData['is_admin'] == true);

      await _clearHiveDataIfDifferentAccount(storeEmail, uid);

      await settingsBox.put('store_email', storeEmail);
      await settingsBox.put('store_password', password);
      await settingsBox.put('store_name', storeName);
      await settingsBox.put('store_id', uid);
      await settingsBox.put(
        'store_subscribed',
        foundData['is_subscribed'] ?? true,
      );
      await settingsBox.put('store_logged_in', true);
      await settingsBox.put('is_admin', isAdmin);

      if (isAdmin) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _navigateAfterLogin(isAdmin: true);
        return;
      }

      // فحص الجلسات
      final otherDevice = await SessionService.getActiveOtherDevice();
      if (otherDevice != null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await _showOtherDeviceDialog();
        return;
      }

      await SessionService.startSession();

      if (!mounted) return;
      setState(() => _isLoading = false);
      _navigateAfterLogin(isAdmin: false);
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Auth error: ${e.code} - ${e.message}');
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.snackbar('error'.tr, 'wrong_credentials'.tr);
    } catch (e) {
      debugPrint('⚠️ Unexpected Login error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.snackbar('error'.tr, 'login_failed'.tr);
    }
  }

  Future<void> _showOtherDeviceDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'account_on_other_device'.tr,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'multi_device_login_message'.tr,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogCtx, true),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: Text('multi_device_login'.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _showPairingQrCode();
    }
  }

  Future<void> _navigateAfterLogin({
    bool isAdmin = false,
    bool isDemo = false,
  }) async {
    final settingsBox = Hive.box('settings');
    await settingsBox.put('store_logged_in', true);
    await settingsBox.put('is_admin', isAdmin);

    if (isAdmin) {
      Get.offAll(() => const ActivationCodesPage());
      return;
    }

    if (isDemo) {
      await settingsBox.put(
        'trial_end_date',
        DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      );
      await settingsBox.put('store_subscribed', false);
      await settingsBox.put('subscription_type', 'trial');
      Get.offAll(() => const BackupRestorePage());
      return;
    }

    Get.offAll(() => const BackupRestorePage());
  }

  void _changeLanguage() {
    final currentLocale = Get.locale;
    if (currentLocale?.languageCode == 'ar') {
      LocaleService.changeLocale('en');
    } else {
      LocaleService.changeLocale('ar');
    }
  }

  Future<void> _showPairingQrCode() async {
    if (Get.isDialogOpen ?? false) return;

    String storeId;
    String deviceId;

    try {
      storeId = StoreIdService.getStoreId();
      if (storeId.isEmpty) {
        storeId = await StoreIdService.loadStoreIdFromCloud();
      }
      deviceId = await SessionService.getDeviceId();
    } catch (e) {
      debugPrint('❌ Error getting storeId/deviceId: $e');
      Get.snackbar('error'.tr, 'pairing_failed'.tr);
      return;
    }

    if (storeId.isEmpty) {
      Get.snackbar('error'.tr, 'store_id_missing'.tr);
      return;
    }

    String code;
    try {
      code = await PairingService.createPairingCode(storeId, deviceId);
    } catch (e) {
      debugPrint('❌ Failed to create pairing code: $e');
      Get.snackbar('error'.tr, 'pairing_failed'.tr);
      return;
    }

    if (code.isEmpty || !mounted) {
      Get.snackbar('error'.tr, 'pairing_failed'.tr);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'pair_new_device'.tr,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'scan_from_main_device'.tr,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withOpacity(.35)),
              ),
              child: QrImageView(
                data: code,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              '${'code'.tr}: $code',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('close'.tr),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎨 BUILD — نسخة الهاتف فقط
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isArabic = Get.locale?.languageCode == 'ar';
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 720;

    return Scaffold(
      backgroundColor: _navy,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _LoginBackdrop(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // ✅ هامش أفقي ذكي: أصغر على الشاشات الصغيرة
                    final horizontalPadding =
                    constraints.maxWidth < 360 ? 16.0 : 20.0;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: compact ? 10 : 22,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight -
                              (compact ? 20 : 44),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildBrandHeader(compact: compact),
                            SizedBox(height: compact ? 16 : 26),
                            _buildLoginCard(
                              context,
                              isArabic: isArabic,
                              compact: compact,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // زر اللغة — أعلى اليمين للعربية، أعلى اليسار للإنجليزية
          Positioned(
            top: 14,
            right: isArabic ? 14 : null,
            left: isArabic ? null : 14,
            child: _buildLanguageButton(isArabic),
          ),
          // شارة الاتصال — الجهة المعاكسة
          Positioned(
            top: 14,
            left: isArabic ? 14 : null,
            right: isArabic ? null : 14,
            child: _buildConnectionBadge(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎯 هيدر العلامة التجارية (نسخة مصغّرة للهاتف)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBrandHeader({required bool compact, bool large = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // الشعار
        Container(
          width: large ? 82 : (compact ? 66 : 76),
          height: large ? 82 : (compact ? 66 : 76),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.07),
            shape: BoxShape.circle,
            border: Border.all(color: _gold.withOpacity(.38)),
            boxShadow: [
              BoxShadow(
                color: _gold.withOpacity(.14),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.store_rounded,
              color: _goldLight,
              size: 38,
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        // اسم التطبيق
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_goldLight, _gold],
          ).createShader(bounds),
          child: Text(
            'my_store_service'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: large ? 24 : (compact ? 20 : 22),
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'nitham_soft'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(.48),
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🃏 بطاقة تسجيل الدخول
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLoginCard(
      BuildContext context, {
        required bool isArabic,
        required bool compact,
      }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      padding: EdgeInsets.all(compact ? 20 : 26),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.975),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.28),
            blurRadius: 50,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: _gold.withOpacity(.06),
            blurRadius: 70,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // أيقونة القفل
            Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_gold.withOpacity(.22), _gold.withOpacity(.06)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _gold.withOpacity(.28)),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withOpacity(.12),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: _navy,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'login'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'welcome_back'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 18 : 24),
            // حقل المستخدم
            _buildField(
              controller: _emailController,
              label: 'username_or_email_phone'.tr,
              icon: Icons.person_outline_rounded,
              textDirection:
              isArabic ? TextDirection.rtl : TextDirection.ltr,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'required_field'.tr;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // حقل كلمة المرور
            _buildField(
              controller: _passwordController,
              label: 'password'.tr,
              icon: Icons.password_rounded,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              suffix: IconButton(
                tooltip:
                _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'required_field'.tr;
                }
                return null;
              },
            ),
            SizedBox(height: compact ? 16 : 20),
            _buildLoginButton(),
            const SizedBox(height: 12),
            _buildPairingButton(),
            const SizedBox(height: 6),
            Container(height: 1, color: Colors.black.withOpacity(.055)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Get.to(() => const StoreRegisterPage()),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: Text(
                'no_account_create'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎨 الحقول
  // ═══════════════════════════════════════════════════════════════

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextDirection textDirection,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textDirection: textDirection,
      validator: validator,
      style: const TextStyle(
        color: _navy,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: _navy, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(.055)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(.055)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [_navy, _navy2],
          ),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _isLoading
                ? const SizedBox(
              key: ValueKey('loading'),
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor:
                AlwaysStoppedAnimation<Color>(_goldLight),
              ),
            )
                : Row(
              key: const ValueKey('login'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'login'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: _goldLight,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPairingButton() {
    return TextButton.icon(
      onPressed: _isLoading ? null : _showPairingQrCode,
      style: TextButton.styleFrom(
        foregroundColor: _navy,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      icon: const Icon(Icons.qr_code_2_rounded, size: 20),
      label: Text(
        'multi_device_login'.tr,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔘 أزرار علوية (لغة + اتصال)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLanguageButton(bool isArabic) {
    return Material(
      color: Colors.white.withOpacity(.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _changeLanguage,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                color: _goldLight,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'EN' : 'عربي',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBadge() {
    final color =
    _isOnline ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(.55), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'online'.tr : 'offline'.tr,
            style: TextStyle(
              color: _isOnline
                  ? const Color(0xFFB7F7C9)
                  : const Color(0xFFFFB8B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  🌌 الخلفية
// ═══════════════════════════════════════════════════════════════

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  static const _navy = Color(0xFF091426);
  static const _navy2 = Color(0xFF10213D);
  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_navy, _navy2, _navy],
              stops: [0, .48, 1],
            ),
          ),
        ),
        Positioned(
          top: -180,
          right: -130,
          child: _glow(430, _gold.withOpacity(.10)),
        ),
        Positioned(
          bottom: -210,
          left: -170,
          child: _glow(500, Colors.blue.withOpacity(.07)),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _GridPainter()),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }

  static Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..strokeWidth = 1;

    const gap = 42.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}