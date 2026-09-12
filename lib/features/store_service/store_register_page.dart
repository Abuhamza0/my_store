// lib/features/store_service/store_register_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreRegisterPage extends StatefulWidget {
  const StoreRegisterPage({super.key});

  @override
  State<StoreRegisterPage> createState() => _StoreRegisterPageState();
}

class _StoreRegisterPageState extends State<StoreRegisterPage> {
  // ---------- الحقول الأساسية ----------
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();



  // ---------- حقل الهاتف الإضافي (اختياري) ----------
  final _phoneController = TextEditingController();
  bool _showPhoneField = false;
  String _countryCode = '+967';

  // ---------- متغيرات الحالة ----------
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // ============================================================
  //              فترة التجربة المجانية (14 يوم)
  // ============================================================
  static const int TRIAL_DAYS = 14;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  /// ✅ تنسيق رقم الهاتف بالصيغة الدولية
  String _formatPhoneNumber() {
    String phone = _phoneController.text.trim();
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }
    if (!phone.startsWith('+')) {
      if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }
      phone = '$_countryCode$phone';
    }
    return phone;
  }

  /// ✅ التحقق من صحة كود التفعيل
  ///
  /// - إذا لم يُدخل المستخدم كوداً: نُكمل بـ trial
  /// - إذا أدخل كوداً: نتحقق من صيغته فقط (بدون Firebase)
  ///   لأن التحقق الحقيقي يتم عند استخدام الكود لاحقاً
  ///
  /// صيغة الكود: 4 مجموعات من 4 أحرف/أرقام، مفصولة بـ -
  /// مثال: NITH-MA1B-2C3D-4E5F

  /// ✅ التسجيل بالبريد الإلكتروني مع حفظ كود التفعيل
  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isSaving = true);

    // ✅ حساب تواريخ التجربة
    final now = DateTime.now();
    final trialEndDate = now.add(const Duration(days: TRIAL_DAYS));

    try {
      // 1. إنشاء الحساب في Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      final user = userCredential.user;
      if (user == null) throw Exception('create_user_failed'.tr);

      final uid = user.uid;
      print('✅ تم إنشاء الحساب - UID: $uid');

      // 2. تجهيز رقم الهاتف
      String formattedPhone = '';
      if (_phoneController.text.trim().isNotEmpty) {
        formattedPhone = _formatPhoneNumber();
      }

      // 3. تجهيز بيانات التجربة والاشتراك
      final trialData = {
        // معلومات التجربة
        'trial_started_at': Timestamp.fromDate(now),
        'trial_ends_at': Timestamp.fromDate(trialEndDate),
        'trial_days': TRIAL_DAYS,
        'is_trial_active': true,

        // معلومات الاشتراك
        'is_subscribed': false,
        'subscription_type': 'trial',
        'subscription_started_at': null,
        'subscription_ends_at': null,
      };

      // 4. حفظ بيانات المستخدم في Firestore
      try {
        // ✅ store_owners
        await FirebaseFirestore.instance
            .collection('store_owners')
            .doc(uid)
            .set({
          'store_id': uid,
          'email': email,
          'name': username,
          'phone': formattedPhone,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));

        // ✅ users — مع بيانات التجربة الكاملة
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': username,
          'email': email,
          'phone': formattedPhone,
          'store_id': uid,
          ...trialData,
          'created_at': FieldValue.serverTimestamp(),
        });

        // ✅ stores — مع بيانات التجربة الكاملة
        await FirebaseFirestore.instance.collection('stores').doc(uid).set({
          'uid': uid,
          'name': username,
          'email': email,
          'phone': formattedPhone,
          'store_id': uid,
          ...trialData,
          'created_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore save failed: $e');
      }

      // 5. إرسال رابط التحقق
      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('Email verification failed: $e');
      }

      // 6. حفظ البيانات محلياً في Hive
      final settingsBox = Hive.box('settings');
      settingsBox.put('store_email', email);
      settingsBox.put('store_name', username);
      settingsBox.put('store_password', password);
      settingsBox.put('store_id', uid);
      settingsBox.put('store_phone', formattedPhone);
      settingsBox.put('store_subscribed', false);
      settingsBox.put('subscription_type', 'trial');
      settingsBox.put('store_logged_in', true);
      settingsBox.put('is_admin', false);

      // ✅ حفظ تواريخ التجربة محلياً
      settingsBox.put('trial_started_at', now.toIso8601String());
      settingsBox.put('trial_ends_at', trialEndDate.toIso8601String());
      settingsBox.put('trial_days', TRIAL_DAYS);
      settingsBox.put('trial_end_date', trialEndDate.toIso8601String()); // للتوافق

      setState(() => _isSaving = false);

      // 7. عرض رسالة نجاح مع تفاصيل
      _showSuccessDialog(username, trialEndDate);

    } on FirebaseAuthException catch (e) {
      setState(() => _isSaving = false);
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'email_already_in_use'.tr;
          break;
        case 'weak-password':
          msg = 'weak_password'.tr;
          break;
        case 'invalid-email':
          msg = 'invalid_email_format'.tr;
          break;
        case 'operation-not-allowed':
          msg = 'registration_disabled'.tr;
          break;
        default:
          msg = '${'registration_failed'.tr}: ${e.message ?? ''}';
      }
      Get.snackbar(
        'error'.tr,
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      Get.snackbar(
        'error'.tr,
        '${'registration_failed'.tr}: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  // ============================================================
  //                  حوار النجاح مع التفاصيل
  // ============================================================
  void _showSuccessDialog(
      String storeName,
      DateTime trialEndDate,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'account_created'.tr,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- فترة التجربة ----------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_rounded,
                          color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'trial_period'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'start_date'.tr}: ${_formatDate(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    '${'end_date'.tr}: ${_formatDate(trialEndDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${TRIAL_DAYS} ${'days_free'.tr}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Get.offAllNamed('/subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2332),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'continue'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Get.locale?.languageCode == 'ar';
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2332), Color(0xFF2D3A4E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الشعار
                  Image.asset(
                    'assets/images/logo.png',
                    width: isSmallScreen ? 90 : 120,
                    height: isSmallScreen ? 90 : 120,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.add_business_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 20),

                  // العنوان
                  Text(
                    'create_account_title'.tr,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'create_account_subtitle'.tr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 24),

                  // بطاقة التسجيل
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 18 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // 1. البريد الإلكتروني
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16),
                            decoration: InputDecoration(
                              labelText: 'email_label'.tr,
                              hintText: 'email_hint'.tr,
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.email_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFF1A2332), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: isSmallScreen ? 10 : 14,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'email_required'.tr;
                              }
                              if (!v.contains('@') || !v.contains('.')) {
                                return 'invalid_email_format'.tr;
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 14),

                          // 2. اسم المستخدم
                          TextFormField(
                            controller: _usernameController,
                            textDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16),
                            decoration: InputDecoration(
                              labelText: 'username_label'.tr,
                              hintText: 'username_hint'.tr,
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFf093fb),
                                      Color(0xFFf5576c)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFF1A2332), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: isSmallScreen ? 10 : 14,
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'username_required'.tr
                                : null,
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 14),

                          // 3. كلمة المرور
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16),
                            decoration: InputDecoration(
                              labelText: 'password_label'.tr,
                              hintText: 'password_hint'.tr,
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4facfe),
                                      Color(0xFF00f2fe)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.lock_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.grey,
                                  size: isSmallScreen ? 18 : 22,
                                ),
                                onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFF1A2332), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: isSmallScreen ? 10 : 14,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'password_required'.tr;
                              }
                              if (v.length < 6) {
                                return 'password_short'.tr;
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 14),

                          // 4. تأكيد كلمة المرور
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            textDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16),
                            decoration: InputDecoration(
                              labelText: 'confirm_password_label'.tr,
                              hintText: 'confirm_password_hint'.tr,
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF43e97b),
                                      Color(0xFF38f9d7)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.lock_outline,
                                    color: Colors.white, size: 20),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.grey,
                                  size: isSmallScreen ? 18 : 22,
                                ),
                                onPressed: () => setState(() =>
                                _obscureConfirm = !_obscureConfirm),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFF1A2332), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: isSmallScreen ? 10 : 14,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'confirm_password_required'.tr;
                              }
                              if (v != _passwordController.text) {
                                return 'password_mismatch'.tr;
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: isSmallScreen ? 14 : 18),


                          // ==================================================
                          // 6. حقل الهاتف الإضافي (اختياري)
                          // ==================================================
                          if (_showPhoneField) ...[
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              'add_phone_optional'.tr,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: isSmallScreen ? 11 : 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 95,
                                  child: TextFormField(
                                    initialValue: _countryCode,
                                    keyboardType: TextInputType.phone,
                                    textDirection: TextDirection.ltr,
                                    style:
                                    const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText: 'country_code'.tr,
                                      hintText: '+967',
                                      prefixIcon: const Icon(Icons.public,
                                          size: 16),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(14)),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 12),
                                    ),
                                    onChanged: (v) => _countryCode =
                                    v.startsWith('+') ? v : '+$v',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    textDirection: TextDirection.ltr,
                                    style:
                                    const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText:
                                      'phone_number_label'.tr,
                                      hintText: 'phone_hint'.tr,
                                      prefixIcon: const Icon(
                                          Icons.phone_android_rounded,
                                          color: Color(0xFF1A2332)),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(14)),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showPhoneField = false;
                                    _phoneController.clear();
                                  });
                                },
                                child: Text('remove_phone'.tr,
                                    style: const TextStyle(
                                        color: Colors.red)),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setState(
                                        () => _showPhoneField = true),
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF1A2332),
                                ),
                                label: Text(
                                  'add_phone_optional'.tr,
                                  style: const TextStyle(
                                      color: Color(0xFF1A2332)),
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: isSmallScreen ? 18 : 24),

                          // ==================================================
                          // 7. زر إنشاء الحساب
                          // ==================================================
                          SizedBox(
                            width: double.infinity,
                            height: isSmallScreen ? 46 : 52,
                            child: ElevatedButton.icon(
                              onPressed:
                              _isSaving ? null : _registerWithEmail,
                              icon: _isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Icon(Icons.person_add_rounded,
                                  color: Colors.white),
                              label: Text(
                                _isSaving
                                    ? 'saving'.tr
                                    : 'create_account_btn'.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A2332),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    label: Text(
                      'back_to_login'.tr,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}