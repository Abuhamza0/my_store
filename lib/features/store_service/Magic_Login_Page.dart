import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'store_home.dart';
import 'store_login_page.dart';

class MagicLoginPage extends StatefulWidget {
  final String email;
  final String password;
  final String? storeId;

  const MagicLoginPage({
    super.key,
    required this.email,
    required this.password,
    this.storeId,
  });

  @override
  State<MagicLoginPage> createState() => _MagicLoginPageState();
}

class _MagicLoginPageState extends State<MagicLoginPage> {
  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  // ✅ الدخول التلقائي عند فتح الرابط
  void _autoLogin() async {
    final box = Hive.box('settings');

    // ✅ 1. التحقق من وجود بيانات المتجر في Hive
    if (widget.email.isEmpty || widget.password.isEmpty) {
      Get.snackbar('خطأ', 'بيانات الدخول غير صالحة',
          backgroundColor: Colors.red, colorText: Colors.white);
      Future.delayed(const Duration(seconds: 2), () {
        Get.offAll(() => const StoreLoginPage());
      });
      return;
    }

    // ✅ 2. محاولة تسجيل الدخول عبر Firebase Auth
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      if (userCredential.user != null) {
        // ✅ تم تسجيل الدخول بنجاح
        box.put('store_logged_in', true);
        box.put('store_email', widget.email);
        box.put('store_password', widget.password);
        box.put('store_id', userCredential.user!.uid);

        // ✅ جلب بيانات المتجر من Firestore
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('stores')
              .where('email', isEqualTo: widget.email)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            box.put('store_phone', data['phone']?.toString() ?? '');
            box.put('store_name', data['name']?.toString() ?? '');
            box.put('store_subscribed', data['subscribed'] ?? false);
          }
        } catch (e) {
          print('⚠️ خطأ في جلب بيانات المتجر: $e');
        }

        // ✅ التوجه مباشرة إلى الصفحة الرئيسية
        Get.offAll(() => const StoreServiceHome());
        return;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // ✅ إذا لم يوجد في Auth، حاول البحث في Firestore
        _loginViaFirestore(widget.email, widget.password);
        return;
      } else if (e.code == 'wrong-password') {
        Get.snackbar('خطأ', 'كلمة المرور غير صحيحة',
            backgroundColor: Colors.red, colorText: Colors.white);
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAll(() => const StoreLoginPage());
        });
        return;
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تسجيل الدخول: ${e.message}',
            backgroundColor: Colors.red, colorText: Colors.white);
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAll(() => const StoreLoginPage());
        });
        return;
      }
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ غير متوقع',
          backgroundColor: Colors.red, colorText: Colors.white);
      Future.delayed(const Duration(seconds: 2), () {
        Get.offAll(() => const StoreLoginPage());
      });
      return;
    }
  }

  // ✅ تسجيل الدخول عبر Firestore (إذا لم يوجد في Auth)
  void _loginViaFirestore(String email, String password) async {
    final box = Hive.box('settings');

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('email', isEqualTo: email)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final storedPassword = data['password']?.toString() ?? '';

        if (storedPassword == password) {
          // ✅ تم العثور على المتجر وكلمة المرور صحيحة
          box.put('store_logged_in', true);
          box.put('store_email', email);
          box.put('store_password', password);
          box.put('store_phone', data['phone']?.toString() ?? '');
          box.put('store_name', data['name']?.toString() ?? '');
          box.put('store_id', snapshot.docs.first.id);
          box.put('store_subscribed', data['subscribed'] ?? false);

          // ✅ التوجه مباشرة إلى الصفحة الرئيسية
          Get.offAll(() => const StoreServiceHome());
          return;
        } else {
          Get.snackbar('خطأ', 'كلمة المرور غير صحيحة',
              backgroundColor: Colors.red, colorText: Colors.white);
          Future.delayed(const Duration(seconds: 2), () {
            Get.offAll(() => const StoreLoginPage());
          });
          return;
        }
      } else {
        Get.snackbar('خطأ', 'لم يتم العثور على المتجر',
            backgroundColor: Colors.red, colorText: Colors.white);
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAll(() => const StoreLoginPage());
        });
        return;
      }
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء البحث في Firestore',
          backgroundColor: Colors.red, colorText: Colors.white);
      Future.delayed(const Duration(seconds: 2), () {
        Get.offAll(() => const StoreLoginPage());
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A2332),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, color: Colors.white, size: 80),
            SizedBox(height: 24),
            Text(
              'جاري تسجيل الدخول...',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Color(0xFFFFD700)),
          ],
        ),
      ),
    );
  }
}