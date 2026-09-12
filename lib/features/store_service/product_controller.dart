import 'package:flutter/material.dart'; // ✅ لـ debugPrint و Colors
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ استيراد FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ استيراد Firestore
import 'product_model.dart';

class ProductController extends GetxController {
  final Box _productBox = Hive.box('products');

  final products = <Product>[].obs;
  final filteredProducts = <Product>[].obs;
  final selectedCategory = 'الكل'.obs;
  final searchQuery = ''.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
    _listenToFirestoreProducts(); // ✅ الاستماع للتحديثات من السحابة
  }

  // ✅ دالة الحصول على الـ UID (المعرف الموحد لصاحب المتجر)
  String _getStoreId() {
    // 1. الأولوية القصوى: قراءة uid من الحساب
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      // حفظ uid في Hive لضمان توفرها دائماً
      Hive.box('settings').put('store_id', uid);
      return uid;
    }

    // 2. احتياطي: قراءة store_id المحفوظة في Hive
    final storedId = Hive.box('settings').get('store_id', defaultValue: '');
    if (storedId.toString().isNotEmpty) {
      return storedId.toString();
    }

    // 3. احتياطي أخير: توليد من البريد الإلكتروني (لا يُفضل)
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return email.isNotEmpty
        ? email.trim().replaceAll('@', '_').replaceAll('.', '_')
        : 'default_store';
  }

  // ✅ الاستماع للمنتجات من السحابة باستخدام store_id (uid)
  void _listenToFirestoreProducts() {
    try {
      final storeId = _getStoreId();
      if (storeId.isEmpty || storeId == 'default_store') return;

      FirebaseFirestore.instance
          .collection('products')
          .where('store_id', isEqualTo: storeId) // ✅ استخدام store_id
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          final doc = change.doc; // ✅ الحصول على المستند من التغيير

          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            try {
              // ✅ طريقة آمنة للوصول للبيانات
              final data = doc.data(); // تعيد Map<String, dynamic> أو null
              if (data == null) continue; // تخطي إذا كانت null

              final productData = Map<String, dynamic>.from(data);
              productData['id'] ??= doc.id; // ✅ الوصول للمعرف عبر doc.id

              final product = Product.fromJson(productData);
              final index = products.indexWhere((p) => p.id == product.id);

              if (index != -1) {
                products[index] = product;
              } else {
                products.add(product);
              }

              // ✅ حفظ في Hive
              _productBox.put(product.id, product.toJson());
            } catch (e) {
              print('❌ خطأ في معالجة منتج: $e');
            }
          } else if (change.type == DocumentChangeType.removed) {
            final id = doc.id; // ✅ الوصول للمعرف عبر doc.id
            products.removeWhere((p) => p.id == id);
            _productBox.delete(id);
          }
        }
        filterProducts();
        update();
      }, onError: (error) {
        print('❌ خطأ في الاستماع للسحابة: $error');
      });
    } catch (e) {
      print('❌ فشل إنشاء listener: $e');
    }
  }

  Future<void> addProduct(Product product) async {
    // ✅ الحصول على storeId (uid)
    final storeId = _getStoreId();

    // ✅ حفظ محلياً
    await _productBox.put(product.id, product.toJson());
    products.add(product);
    filterProducts();

    // ✅ حفظ في السحابة مع store_id
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .set({
        ...product.toJson(),
        'store_id': storeId, // ✅ إضافة store_id
      }, SetOptions(merge: true));
      print('✅ تم حفظ المنتج في السحابة - storeId: $storeId');
    } catch (e) {
      print('❌ خطأ في حفظ المنتج في السحابة: $e');
    }

    Get.snackbar(
      'نجاح',
      'تم إضافة المنتج بنجاح',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  Future<void> updateProduct(Product product) async {
    // ✅ الحصول على storeId (uid)
    final storeId = _getStoreId();

    await _productBox.put(product.id, product.toJson());
    final index = products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      products[index] = product;
    }
    filterProducts();

    // ✅ حفظ في السحابة مع store_id
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .set({
        ...product.toJson(),
        'store_id': storeId, // ✅ إضافة store_id
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ خطأ في تحديث المنتج في السحابة: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    await _productBox.delete(productId);
    products.removeWhere((p) => p.id == productId);
    filterProducts();

    // ✅ حذف من السحابة
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();
    } catch (e) {
      print('❌ خطأ في حذف المنتج من السحابة: $e');
    }
  }

  /// تحميل المنتجات من Hive
  void loadProducts() {
    try {
      final box = Hive.box('products');
      products.clear();

      for (var key in box.keys) {
        try {
          final data = box.get(key);
          if (data != null && data is Map) {
            final fixedData = _fixMapData(data);

            // ✅ تأكد أن id موجود كنص
            if (!fixedData.containsKey('id')) {
              fixedData['id'] = key.toString();
            }

            // ✅ تأكد أن id نصي
            if (fixedData['id'] is! String) {
              fixedData['id'] = fixedData['id'].toString();
            }

            final product = Product.fromJson(Map<String, dynamic>.from(fixedData));
            products.add(product);
          }
        } catch (e) {
          print('❌ خطأ في تحميل منتج: $e');
        }
      }

      print('✅ تم تحميل ${products.length} منتج');
      update();
    } catch (e) {
      print('❌ خطأ في تحميل المنتجات: $e');
    }
  }

  /// إصلاح البيانات القادمة من Hive
  Map _fixMapData(Map data) {
    final fixed = <dynamic, dynamic>{};
    data.forEach((key, value) {
      // ✅ تحويل المفتاح إلى String إذا لزم الأمر
      final stringKey = key is String ? key : key.toString();

      if (value is String) {
        final lower = value.toLowerCase().trim();
        if (lower == 'true') {
          fixed[stringKey] = true;
        } else if (lower == 'false') {
          fixed[stringKey] = false;
        } else {
          final intValue = int.tryParse(value);
          if (intValue != null) {
            fixed[stringKey] = intValue;
          } else {
            final doubleValue = double.tryParse(value);
            if (doubleValue != null) {
              fixed[stringKey] = doubleValue;
            } else {
              fixed[stringKey] = value;
            }
          }
        }
      } else if (value is Map) {
        fixed[stringKey] = _fixMapData(value);
      } else if (value is List) {
        fixed[stringKey] = value.map((e) {
          if (e is Map) return _fixMapData(e);
          return e;
        }).toList();
      } else {
        fixed[stringKey] = value;
      }
    });
    return fixed;
  }

  void filterProducts() {
    List<Product> result = products;

    // ✅ تصفية حسب الفئة (لـ store_home فقط - ليس له تأثير في sales_screen)
    if (selectedCategory.value != 'الكل' && selectedCategory.value != 'all') {
      result = result.where((p) => p.category == selectedCategory.value).toList();
    }

    // ✅ تصفية حسب البحث (يعمل في الجميع)
    if (searchQuery.value.isNotEmpty) {
      result = result.where((p) =>
      p.name.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          p.description.toLowerCase().contains(searchQuery.value.toLowerCase())
      ).toList();
    }

    filteredProducts.value = result;
  }

  int get totalProducts => products.length;

  double get averageRating {
    if (products.isEmpty) return 0.0;
    final total = products.fold(0.0, (sum, p) => sum + p.rating);
    return total / products.length;
  }
}