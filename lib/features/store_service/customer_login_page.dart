import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'customer_controller.dart';
import 'remote_order_screen.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key, required String deepLink});

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final CustomerController _customerController = Get.find();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ✅ تسجيل الدخول
  void _login() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();

      // البحث عن العميل
      final customer = _customerController.customers.firstWhereOrNull(
            (c) => c.phone == phone && c.isActive,
      );

      if (customer == null) {
        setState(() => _isLoading = false);
        Get.snackbar('خطأ', 'رقم الهاتف غير مسجل', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      // التحقق من كلمة المرور
      if (!customer.verifyPassword(password)) {
        setState(() => _isLoading = false);
        Get.snackbar('خطأ', 'كلمة المرور غير صحيحة', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      // ✅ تسجيل الدخول الناجح
      setState(() => _isLoading = false);
      Get.off(() => RemoteOrderScreen(customer: customer, accessMethod: 'credentials'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1D325E), Color(0xFF2A4B8C), Color(0xFF1D325E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    // ✅ الشعار
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: const Icon(Icons.shopping_cart_rounded, color: Color(0xFF1D325E), size: 50),
                    ),
                    const SizedBox(height: 16),
                    const Text('متجري', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text('تسوق بسهولة وأمان', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                    const SizedBox(height: 40),

                    // ✅ بطاقة تسجيل الدخول
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Text('تسجيل الدخول', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1D325E))),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text('أدخل رقم هاتفك وكلمة المرور', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                            ),
                            const SizedBox(height: 32),

                            // ✅ رقم الهاتف
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'رقم الهاتف',
                                hintText: 'مثال: 770123456',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF1D325E).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.phone_android_rounded, color: Color(0xFF1D325E)),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1D325E), width: 2)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'الرجاء إدخال رقم الهاتف' : null,
                            ),
                            const SizedBox(height: 16),

                            // ✅ كلمة المرور
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                hintText: 'أدخل كلمة المرور',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF1D325E).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.lock_rounded, color: Color(0xFF1D325E)),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF1D325E), width: 2)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'الرجاء إدخال كلمة المرور' : null,
                            ),
                            const SizedBox(height: 24),

                            // ✅ زر الدخول
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _login,
                                icon: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.login_rounded, color: Colors.white),
                                label: Text(_isLoading ? 'جاري الدخول...' : 'دخول', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D325E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ✅ معلومات إضافية
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 16),
                                    const SizedBox(width: 8),
                                    Text('سجل دخولك برقم هاتفك وكلمة المرور', style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    Text('نظام سوفت', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('الحل الذكي لإدارة الأعمال', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}