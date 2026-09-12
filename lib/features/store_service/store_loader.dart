import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sales_screen.dart';
import 'store_login_page.dart';

class StoreLoader extends StatefulWidget {
  final String storeId;

  const StoreLoader({super.key, required this.storeId});

  @override
  State<StoreLoader> createState() => _StoreLoaderState();
}

class _StoreLoaderState extends State<StoreLoader> {
  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    final box = Hive.box('settings');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .get();

      if (!doc.exists) {
        Get.snackbar('خطأ', 'المتجر غير موجود', backgroundColor: Colors.red, colorText: Colors.white);
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAll(() => const StoreLoginPage());
        });
        return;
      }

      final data = doc.data()!;

      // حفظ بيانات المتجر الأساسية
      box.put('store_id', widget.storeId);
      box.put('store_name', data['name'] ?? 'متجري');
      box.put('store_email', data['email'] ?? '');
      box.put('store_phone', data['phone'] ?? '');
      box.put('store_logged_in', true);

      // ==========================================
      // 1. تحميل الفئات (Categories)
      // ==========================================
      try {
        final categoriesSnapshot = await FirebaseFirestore.instance
            .collection('stores')
            .doc(widget.storeId)
            .collection('categories')
            .get();

        final categories = categoriesSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        box.put('custom_categories_data', categories);
      } catch (e) {
        print("⚠️ خطأ في تحميل الفئات (لكن التطبيق لم يتوقف): $e");
        // في حالة الفشل، نخزن قائمة فارغة
        box.put('custom_categories_data', <Map>[]);
      }

      // ==========================================
      // 2. تحميل المنتجات (Products)
      // ==========================================
      try {
        final productsSnapshot = await FirebaseFirestore.instance
            .collection('stores')
            .doc(widget.storeId)
            .collection('products')
            .get();

        final products = productsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        final productsBox = Hive.box('products');
        productsBox.clear();
        for (var product in products) {
          try {
            productsBox.put(product['id'], product);
          } catch (e) {
            print("⚠️ تخطي منتج بسبب خطأ في الصيغة: $e");
          }
        }
      } catch (e) {
        print("⚠️ خطأ في تحميل المنتجات (لكن التطبيق لم يتوقف): $e");
      }

      // ==========================================
      // 3. تحميل العملاء (Customers)
      // ==========================================
      try {
        final customersSnapshot = await FirebaseFirestore.instance
            .collection('stores')
            .doc(widget.storeId)
            .collection('customers')
            .get();

        final customers = customersSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        final customersBox = Hive.box('customers');
        customersBox.clear();
        for (var customer in customers) {
          try {
            customersBox.put(customer['id'], customer);
          } catch (e) {
            print("⚠️ تخطي عميل بسبب خطأ في الصيغة: $e");
          }
        }
      } catch (e) {
        print("⚠️ خطأ في تحميل العملاء (لكن التطبيق لم يتوقف): $e");
      }

      // ==========================================
      // 4. الانتقال إلى صفحة المبيعات
      // ==========================================
      Get.offAll(() => SalesScreen(storeIdFromUrl: widget.storeId));

    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل بيانات المتجر: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      Future.delayed(const Duration(seconds: 2), () {
        Get.offAll(() => const StoreLoginPage());
      });
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
              'جاري تحميل بيانات المتجر...',
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