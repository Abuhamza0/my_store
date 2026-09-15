// add_product_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mystore/utils/image_helper.dart';
import 'package:mystore/core/services/locale_service.dart';
import '../../core/services/image_upload_service.dart';
import 'product_model.dart';
import 'product_controller.dart';
import 'custom_category_model.dart';

// ═══════════════════════════════════════════════════════════════
//  🎨 لوحة ألوان فاخرة
// ═══════════════════════════════════════════════════════════════
abstract class _Lux {
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF0D97A);
  static const Color goldDeep = Color(0xFF9A7B1F);
  static const Color champagne = Color(0xFFE8D9A8);
  static const Color midnight = Color(0xFF0A1322);
  static const Color navy = Color(0xFF0F1A2B);
  static const Color navySoft = Color(0xFF182945);
  static const Color navyCard = Color(0xFF111A2A);
  static const Color bgDark = Color(0xFF060A12);
  static const Color bgLight = Color(0xFFF5F7FB);
  static const Color emerald = Color(0xFF10B981);
  static const Color ruby = Color(0xFFE11D48);
  static const Color sapphire = Color(0xFF2563EB);
  static const Color amber = Color(0xFFF59E0B);
  static const Color violet = Color(0xFF7C3AED);

  static const LinearGradient royalGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
  );

  static const LinearGradient midnightSky = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy, navySoft, midnight],
  );
}

class AddProductPage extends StatefulWidget {
  final Product? product;
  final String? categoryName;
  final String? flavor;

  const AddProductPage({
    super.key,
    this.product,
    this.categoryName,
    this.flavor,
  });

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _sectionController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _typeController = TextEditingController();
  final _flavorController = TextEditingController();

  final ProductController _productController = Get.find();
  final ImagePicker _picker = ImagePicker();
  final List<String> _selectedImages = [];

  String? _selectedImagePath;
  bool _isSaving = false;
  bool _showSaveButton = false;
  String _currency = 'SAR';

  List<CustomCategory> _allCategories = [];
  List<String> _sectionSuggestions = [];
  List<String> _subCategorySuggestions = [];
  List<String> _typeSuggestions = [];
  List<String> _flavorSuggestions = [];
  List<String> _nameSuggestions = [];

  List<Product> _recentProducts = [];

  bool _hasMultipleSizes = false;
  List<ProductSize> _sizes = [];

  bool _imagesExpanded = true;

  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _stockFocus = FocusNode();
  final _descFocus = FocusNode();
  final _sectionFocus = FocusNode();
  final _subCategoryFocus = FocusNode();
  final _typeFocus = FocusNode();
  final _flavorFocus = FocusNode();

  Worker? _productsWorker;

  String _getStoreId() {
    final email = Hive.box('settings')
        .get('store_email', defaultValue: '')
        ?.toString() ??
        '';
    return email.isNotEmpty
        ? email.trim().replaceAll('@', '_').replaceAll('.', '_')
        : 'default_store';
  }

  @override
  void initState() {
    super.initState();

    _currency = Hive.box('settings')
        .get('currency', defaultValue: 'SAR')
        ?.toString() ??
        'SAR';

    _loadCategories();
    _ensureProductsLoaded();
    _loadLocalAndCloudSuggestions();

    _productsWorker = ever<List<Product>>(
      _productController.products,
          (_) {
        if (mounted) _loadLocalAndCloudSuggestions();
      },
    );

    ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });

    _prefillFields();
    _loadRecentProducts();

    _nameController.addListener(_checkRequiredFields);
    _priceController.addListener(_checkRequiredFields);
    _typeController.addListener(_checkRequiredFields);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRequiredFields();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  ✅ إظهار/إخفاء زر الحفظ
  // ═══════════════════════════════════════════════════════════════
  void _checkRequiredFields() {
    if (!mounted) return;

    final nameOk = _nameController.text.trim().isNotEmpty;
    final priceOk =
        (double.tryParse(_priceController.text.trim()) ?? 0) > 0;
    final categoryOk = _typeController.text.trim().isNotEmpty;

    final shouldShow = nameOk && priceOk && categoryOk;

    if (shouldShow != _showSaveButton) {
      setState(() => _showSaveButton = shouldShow);
    }
  }

  void _prefillFields() {
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toString();
      _stockController.text = widget.product!.stock.toString();
      _sectionController.text =
          _findSectionForCategory(widget.product!.category);
      _subCategoryController.text =
          _findSubCategoryForCategory(widget.product!.category);
      _typeController.text = widget.product!.category;
      _flavorController.text = widget.product!.flavor ?? '';

      _selectedImagePath = widget.product!.imagePath !=
          'assets/images/product_placeholder.png'
          ? widget.product!.imagePath
          : null;

      _selectedImages.clear();
      for (final img in widget.product!.additionalImages) {
        if (img != _selectedImagePath) {
          _selectedImages.add(img);
        }
      }
    } else if (widget.categoryName != null) {
      _typeController.text = widget.categoryName!;
      _subCategoryController.text =
          _findSubCategoryForCategory(widget.categoryName!);
      _sectionController.text =
          _findSectionForCategory(widget.categoryName!);
    }

    if (widget.flavor != null && widget.flavor!.isNotEmpty) {
      _flavorController.text = widget.flavor!;
    }
  }

  Future<void> _ensureProductsLoaded() async {
    try {
      if (_productController.products.isEmpty) {
        try {
          // ignore: avoid_dynamic_calls
          await (_productController as dynamic).loadProducts();
        } catch (_) {
          try {
            // ignore: avoid_dynamic_calls
            await (_productController as dynamic).refresh();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('❌ _ensureProductsLoaded: $e');
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkRequiredFields);
    _priceController.removeListener(_checkRequiredFields);
    _typeController.removeListener(_checkRequiredFields);

    _productsWorker?.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _sectionController.dispose();
    _subCategoryController.dispose();
    _typeController.dispose();
    _flavorController.dispose();
    _nameFocus.dispose();
    _priceFocus.dispose();
    _stockFocus.dispose();
    _descFocus.dispose();
    _sectionFocus.dispose();
    _subCategoryFocus.dispose();
    _typeFocus.dispose();
    _flavorFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  🚪 تأكيد الخروج
  // ═══════════════════════════════════════════════════════════════
  Future<void> _handleBackPress() async {
    final hasData = _nameController.text.trim().isNotEmpty ||
        _priceController.text.trim().isNotEmpty ||
        _typeController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _selectedImagePath != null ||
        _selectedImages.isNotEmpty;

    if (!hasData) {
      Get.back();
      return;
    }

    final result = await Get.dialog<String>(
      barrierDismissible: false,
      Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _Lux.amber.withOpacity(0.20),
                      _Lux.amber.withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border:
                  Border.all(color: _Lux.amber.withOpacity(0.40)),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _Lux.amber,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'warning'.tr,
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _Lux.midnight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'product_not_saved'.tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),

              // ✅ حفظ وخروج
              SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _Lux.royalGold,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _Lux.gold.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Get.back(result: 'save_and_exit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded,
                        color: Colors.white, size: 20),
                    label: Text(
                      'save_and_exit'.tr,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ✅ خروج بدون حفظ
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => Get.back(result: 'exit'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _Lux.ruby.withOpacity(0.50)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded,
                      color: _Lux.ruby, size: 18),
                  label: Text(
                    'exit_without_save'.tr,
                    style: GoogleFonts.cairo(
                      color: _Lux.ruby,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ✅ إلغاء
              SizedBox(
                width: double.infinity,
                height: 42,
                child: TextButton(
                  onPressed: () => Get.back(result: 'cancel'),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'cancel'.tr,
                    style: GoogleFonts.cairo(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    switch (result) {
      case 'save_and_exit':
        await _saveProduct(popAfterSave: true);
        break;
      case 'exit':
        Get.back();
        break;
      case 'cancel':
      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  المنطق البرمجي
  // ═══════════════════════════════════════════════════════════════

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile>? pickedFiles =
      await _picker.pickMultiImage(imageQuality: 80);
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        for (var file in pickedFiles) {
          final bytes = await file.readAsBytes();
          final base64 = base64Encode(bytes);
          if (mounted) {
            setState(() {
              _selectedImages.add('data:image/jpeg;base64,$base64');
            });
          }
        }
        if (_selectedImagePath == null && _selectedImages.isNotEmpty) {
          _selectedImagePath = _selectedImages.first;
        }
      }
    } catch (e) {
      debugPrint('❌ Error picking multiple images: $e');
    }
  }

  void _loadCategories() {
    try {
      final savedData = Hive.box('settings')
          .get('custom_categories_data', defaultValue: <Map>[]);
      if (savedData is List) {
        _allCategories = savedData
            .map((j) =>
            CustomCategory.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadLocalAndCloudSuggestions() async {
    final sections = <String>{};
    final subCategories = <String>{};
    final types = <String>{};
    final flavors = <String>{};
    final names = <String>{};

    for (var cat in _allCategories) {
      if (cat.name.trim().isNotEmpty) sections.add(cat.name.trim());
      for (var sub in cat.subCategories) {
        if (sub.name.trim().isNotEmpty) {
          subCategories.add(sub.name.trim());
        }
        if (sub.subCategories != null) {
          for (var type in sub.subCategories!) {
            if (type.name.trim().isNotEmpty) types.add(type.name.trim());
          }
        }
        if (sub.flavors != null) {
          for (var flavor in sub.flavors!) {
            if (flavor.name.trim().isNotEmpty) {
              flavors.add(flavor.name.trim());
            }
          }
        }
      }
    }

    try {
      for (var p in _productController.products) {
        if (p.name.trim().isNotEmpty) names.add(p.name.trim());
        if (p.category.trim().isNotEmpty) types.add(p.category.trim());
        if (p.flavor != null && p.flavor!.trim().isNotEmpty) {
          flavors.add(p.flavor!.trim());
        }
      }
    } catch (e) {
      debugPrint('⚠️ productController read error: $e');
    }

    try {
      if (Hive.isBoxOpen('products')) {
        final box = Hive.box('products');
        for (var key in box.keys) {
          final data = box.get(key);
          if (data is Map) {
            if (data['name'] != null &&
                data['name'].toString().trim().isNotEmpty) {
              names.add(data['name'].toString().trim());
            }
            if (data['category'] != null &&
                data['category'].toString().trim().isNotEmpty) {
              types.add(data['category'].toString().trim());
            }
            if (data['flavor'] != null &&
                data['flavor'].toString().trim().isNotEmpty) {
              flavors.add(data['flavor'].toString().trim());
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Hive products read error: $e');
    }

    _applySuggestions(sections, subCategories, types, flavors, names);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .limit(500)
          .get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['name'] != null &&
            data['name'].toString().trim().isNotEmpty) {
          names.add(data['name'].toString().trim());
        }
        if (data['category'] != null &&
            data['category'].toString().trim().isNotEmpty) {
          types.add(data['category'].toString().trim());
        }
        if (data['flavor'] != null &&
            data['flavor'].toString().trim().isNotEmpty) {
          flavors.add(data['flavor'].toString().trim());
        }
      }
      _applySuggestions(sections, subCategories, types, flavors, names);
    } catch (e) {
      debugPrint('⚠️ Cloud suggestions error: $e');
    }
  }

  void _applySuggestions(
      Set<String> sections,
      Set<String> subCategories,
      Set<String> types,
      Set<String> flavors,
      Set<String> names,
      ) {
    if (!mounted) return;
    setState(() {
      _sectionSuggestions =
      sections.where((s) => s.isNotEmpty).toList()..sort();
      _subCategorySuggestions =
      subCategories.where((s) => s.isNotEmpty).toList()..sort();
      _typeSuggestions =
      types.where((s) => s.isNotEmpty).toList()..sort();
      _flavorSuggestions =
      flavors.where((s) => s.isNotEmpty).toList()..sort();
      _nameSuggestions =
      names.where((s) => s.isNotEmpty).toList()..sort();
    });
  }

  void _loadRecentProducts() {
    _recentProducts = _productController.products.toList()
      ..sort((a, b) => (b.id ?? '').compareTo(a.id ?? ''));
    if (mounted) setState(() {});
  }

  Future<void> _showRecentProducts() async {
    final selectedProduct = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: _Lux.royalGold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'recent_products'.tr,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _Lux.midnight,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _recentProducts.isEmpty
                    ? Center(
                  child: Text(
                    'no_products'.tr,
                    style: GoogleFonts.cairo(
                        color: Colors.grey.shade600),
                  ),
                )
                    : ListView.builder(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _recentProducts.length,
                  itemBuilder: (context, index) {
                    final p = _recentProducts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.grey.shade200, width: 1),
                      ),
                      child: ListTile(
                        leading: p.imagePath.isNotEmpty
                            ? ClipRRect(
                          borderRadius:
                          BorderRadius.circular(10),
                          child: ImageHelper.displayImage(
                            imagePath: p.imagePath,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: _Lux.royalGold,
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                          child: const Icon(
                              Icons.image_rounded,
                              color: Colors.white),
                        ),
                        title: Text(p.name,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        subtitle: Text(p.category,
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: _Lux.royalGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${p.price} $_currency',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.pop(ctx, p),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedProduct != null) {
      setState(() {
        _nameController.text = selectedProduct.name;
        _descriptionController.text = selectedProduct.description;
        _priceController.text = selectedProduct.price.toString();
        _stockController.text = selectedProduct.stock.toString();
        _sectionController.text =
            _findSectionForCategory(selectedProduct.category);
        _subCategoryController.text =
            _findSubCategoryForCategory(selectedProduct.category);
        _typeController.text = selectedProduct.category;
        _flavorController.text = selectedProduct.flavor ?? '';
        _selectedImagePath =
        selectedProduct.imagePath != 'assets/images/product_placeholder.png'
            ? selectedProduct.imagePath
            : null;
      });
      _checkRequiredFields();
    }
  }

  String _findSectionForCategory(String categoryName) {
    for (var cat in _allCategories) {
      for (var sub in cat.subCategories) {
        if (sub.name == categoryName) return cat.name;
        if (sub.subCategories != null) {
          for (var type in sub.subCategories!) {
            if (type.name == categoryName) return cat.name;
          }
        }
      }
    }
    return '';
  }

  String _findSubCategoryForCategory(String categoryName) {
    for (var cat in _allCategories) {
      for (var sub in cat.subCategories) {
        if (sub.name == categoryName) return sub.name;
        if (sub.subCategories != null) {
          for (var type in sub.subCategories!) {
            if (type.name == categoryName) return sub.name;
          }
        }
      }
    }
    return '';
  }

  Future<void> _saveProduct({bool popAfterSave = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      Get.snackbar(
        'error'.tr,
        'price_invalid'.tr,
        backgroundColor: _Lux.ruby,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String mainImage =
          _selectedImagePath ?? 'assets/images/product_placeholder.png';

      if (mainImage.startsWith('data:image')) {
        final bytes = base64Decode(mainImage.split(',').last);
        final uploadedUrl = await ImageUploadService().uploadBytes(
          bytes: bytes,
          fileName:
          'product_${DateTime.now().millisecondsSinceEpoch}_main.jpg',
          folder: 'products',
        );
        if (uploadedUrl != null) mainImage = uploadedUrl;
      }

      final additionalImages = <String>[];
      for (final img in _selectedImages) {
        if (img == _selectedImagePath) continue;

        if (img.startsWith('data:image')) {
          final bytes = base64Decode(img.split(',').last);
          final url = await ImageUploadService().uploadBytes(
            bytes: bytes,
            fileName:
            'product_${DateTime.now().millisecondsSinceEpoch}_${additionalImages.length}.jpg',
            folder: 'products',
          );
          if (url != null) additionalImages.add(url);
        } else if (img.startsWith('http')) {
          additionalImages.add(img);
        }
      }

      final productId = widget.product?.id ??
          FirebaseFirestore.instance.collection('products').doc().id;

      final product = Product(
        id: productId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        category: _typeController.text.trim().isNotEmpty
            ? _typeController.text.trim()
            : (widget.product?.category ??
            widget.categoryName ??
            'general'.tr),
        imagePath: mainImage,
        isAvailable: true,
        stock: int.tryParse(_stockController.text.trim()) ?? 0,
        rating: widget.product?.rating ?? 0.0,
        reviewCount: widget.product?.reviewCount ?? 0,
        flavor: _flavorController.text.trim().isNotEmpty
            ? _flavorController.text.trim()
            : null,
        hasMultipleSizes: _hasMultipleSizes,
        sizes: _hasMultipleSizes ? _sizes : null,
        additionalImages: additionalImages,
      );

      if (widget.product != null) {
        await _productController.updateProduct(product);
      } else {
        await _productController.addProduct(product);
      }

      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .set({
          'name': product.name,
          'price': product.price,
          'category': product.category,
          'description': product.description,
          'imagePath': mainImage,
          'additionalImages': additionalImages,
          'flavor': product.flavor,
          'stock': product.stock,
          'storeId': _getStoreId(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('❌ Error saving to cloud: $e');
      }

      if (product.flavor != null && product.flavor!.isNotEmpty) {
        _addFlavorToCategory(product.category, product.flavor!);
      }

      await _loadLocalAndCloudSuggestions();

      if (!mounted) return;
      setState(() => _isSaving = false);

      // ✅ إذا كان "حفظ وخروج" → اخرج فوراً
      if (popAfterSave) {
        if (mounted) Get.back();
        return;
      }

      final addAnother = await Get.dialog<bool>(
        AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: _Lux.royalGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('saved_successfully'.tr,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('add_another_product'.tr,
              style: GoogleFonts.cairo(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('no'.tr,
                  style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: _Lux.royalGold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                ),
                child: Text('yes'.tr,
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );

      if (addAnother == true) {
        setState(() {
          _nameController.clear();
          _descriptionController.clear();
          _priceController.clear();
          _stockController.clear();
          _flavorController.clear();
          _selectedImagePath = null;
          _selectedImages.clear();
          _imagesExpanded = true;
          _showSaveButton = false;
        });
      } else {
        Get.back();
      }
    } catch (e) {
      debugPrint('❌ Save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        Get.snackbar(
          'error'.tr,
          'save_failed'.tr,
          backgroundColor: _Lux.ruby,
          colorText: Colors.white,
        );
      }
    }
  }

  void _addFlavorToCategory(String typeName, String flavorName) {
    final settingsBox = Hive.box('settings');
    final savedData =
    settingsBox.get('custom_categories_data', defaultValue: <Map>[]);
    if (savedData is List) {
      final allCats = savedData
          .map((j) =>
          CustomCategory.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      bool updated = false;

      for (var cat in allCats) {
        for (var sub in cat.subCategories) {
          if (sub.subCategories != null) {
            for (var type in sub.subCategories!) {
              if (type.name == typeName) {
                type.flavors ??= [];
                final exists = type.flavors!.any((f) =>
                f.name.toLowerCase() == flavorName.toLowerCase());
                if (!exists) {
                  type.flavors!.add(Flavor(name: flavorName));
                  updated = true;
                }
              }

              if (type.subCategories != null) {
                for (var subType in type.subCategories!) {
                  if (subType.name == typeName) {
                    subType.flavors ??= [];
                    final exists = subType.flavors!.any((f) =>
                    f.name.toLowerCase() ==
                        flavorName.toLowerCase());
                    if (!exists) {
                      subType.flavors!.add(Flavor(name: flavorName));
                      updated = true;
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (updated) {
        settingsBox.put(
          'custom_categories_data',
          allCats.map((c) => c.toJson()).toList(),
        );

        if (Get.isRegistered<ProductController>()) {
          Get.find<ProductController>().refresh();
        }
      }
    }
  }

  void _showSelectionList(
      String title, List<String> items, TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _Lux.midnight,
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                  child: Text(
                    'no_suggestions'.tr,
                    style: GoogleFonts.cairo(
                        color: Colors.grey.shade600),
                  ),
                )
                    : ListView.builder(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _Lux.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: _Lux.goldDeep),
                      ),
                      title: Text(item,
                          style:
                          GoogleFonts.cairo(fontSize: 14)),
                      onTap: () {
                        controller.text = item;
                        controller.selection =
                            TextSelection.fromPosition(
                              TextPosition(
                                  offset: controller.text.length),
                            );
                        Navigator.pop(ctx);
                        _checkRequiredFields();
                        if (mounted) setState(() {});
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

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'add_image'.tr,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _Lux.midnight,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _imageOption(
                      Icons.camera_alt_rounded,
                      'camera'.tr,
                      _Lux.sapphire,
                          () {
                        Navigator.pop(ctx);
                        _pickFromCamera();
                      },
                    ),
                    _imageOption(
                      Icons.photo_library_rounded,
                      'gallery'.tr,
                      _Lux.emerald,
                          () {
                        Navigator.pop(ctx);
                        _pickFromGallery();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageOption(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: _Lux.midnight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? img = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 80);
      if (img != null && mounted) {
        final bytes = await img.readAsBytes();
        final base64Image = base64Encode(bytes);
        setState(() {
          _selectedImagePath = 'data:image/jpeg;base64,$base64Image';
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? img = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 60);
      if (img != null && mounted) {
        final bytes = await img.readAsBytes();
        final base64Image = base64Encode(bytes);
        setState(() {
          _selectedImagePath = 'data:image/jpeg;base64,$base64Image';
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎨 البناء
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ اعتراض زر الرجوع في النظام
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: isDark ? _Lux.bgDark : _Lux.bgLight,
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImagesSection(isDark),
                      const SizedBox(height: 20),
                      _buildSectionTitle(
                        icon: Icons.category_rounded,
                        title: 'التصنيف',
                        color: _Lux.violet,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildLuxField(
                        label: 'section'.tr,
                        controller: _sectionController,
                        focusNode: _sectionFocus,
                        hint: 'select_section'.tr,
                        icon: Icons.folder_rounded,
                        iconColor: _Lux.violet,
                        suggestions: _sectionSuggestions,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildLuxField(
                        label: 'sub_category'.tr,
                        controller: _subCategoryController,
                        focusNode: _subCategoryFocus,
                        hint: 'select_sub_category'.tr,
                        icon: Icons.folder_open_rounded,
                        iconColor: _Lux.sapphire,
                        suggestions: _subCategorySuggestions,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildLuxField(
                        label: 'type_size'.tr,
                        controller: _typeController,
                        focusNode: _typeFocus,
                        hint: 'select_type'.tr,
                        icon: Icons.category_rounded,
                        iconColor: _Lux.amber,
                        suggestions: _typeSuggestions,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildLuxField(
                        label: 'flavor'.tr,
                        controller: _flavorController,
                        focusNode: _flavorFocus,
                        hint: 'select_flavor'.tr,
                        icon: Icons.local_drink_rounded,
                        iconColor: _Lux.emerald,
                        suggestions: _flavorSuggestions,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        icon: Icons.info_rounded,
                        title: 'المعلومات',
                        color: _Lux.sapphire,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildLuxField(
                        label: 'product_name'.tr,
                        controller: _nameController,
                        focusNode: _nameFocus,
                        hint: 'product_name'.tr,
                        icon: Icons.shopping_bag_rounded,
                        iconColor: _Lux.gold,
                        suggestions: _nameSuggestions,
                        isDark: isDark,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'required_field'.tr
                            : null,
                        isRequired: true,
                      ),
                      const SizedBox(height: 12),
                      _buildLuxField(
                        label: 'product_description'.tr,
                        controller: _descriptionController,
                        focusNode: _descFocus,
                        hint: 'product_description'.tr,
                        icon: Icons.description_rounded,
                        iconColor: _Lux.violet,
                        suggestions: const [],
                        isDark: isDark,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        icon: Icons.attach_money_rounded,
                        title: 'السعر والمخزون',
                        color: _Lux.emerald,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLuxField(
                              label: 'price'.tr,
                              controller: _priceController,
                              focusNode: _priceFocus,
                              hint: '0.00',
                              icon: Icons.attach_money_rounded,
                              iconColor: _Lux.emerald,
                              suggestions: const [],
                              isDark: isDark,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'required_field'.tr;
                                }
                                final n = double.tryParse(v.trim());
                                if (n == null || n <= 0) {
                                  return 'price_invalid'.tr;
                                }
                                return null;
                              },
                              isRequired: true,
                              suffix: _currency,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildLuxField(
                              label: 'stock'.tr,
                              controller: _stockController,
                              focusNode: _stockFocus,
                              hint: '0',
                              icon: Icons.inventory_2_rounded,
                              iconColor: _Lux.amber,
                              suggestions: const [],
                              isDark: isDark,
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎯 الهيدر
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(bool isDark) {
    final isEditing = widget.product != null;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 14,
        right: 14,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        gradient: _Lux.midnightSky,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _Lux.gold.withOpacity(0.08),
            blurRadius: 26,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: _Lux.gold.withOpacity(0.22),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: _handleBackPress,
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: _Lux.royalGold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _Lux.gold.withOpacity(0.40),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              isEditing ? Icons.edit_rounded : Icons.add_box_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Colors.white, _Lux.champagne, Colors.white],
                  ).createShader(rect),
                  child: Text(
                    isEditing
                        ? 'edit_product_title'.tr
                        : 'add_product_title'.tr,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  isEditing
                      ? 'تحديث بيانات المنتج'
                      : 'أدخل بيانات المنتج الجديد',
                  style: GoogleFonts.cairo(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _iconButton(
            icon: Icons.history_rounded,
            onTap: _showRecentProducts,
            tooltip: 'view_previous'.tr,
          ),
          const SizedBox(width: 8),
          _buildHeaderSaveButton(),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  💾 زر الحفظ في الهيدر
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeaderSaveButton() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      scale: _showSaveButton ? 1.0 : 0.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _showSaveButton ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showSaveButton,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _isSaving ? null : _saveProduct,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: _isSaving
                      ? LinearGradient(
                    colors: [
                      Colors.grey.shade400,
                      Colors.grey.shade600,
                    ],
                  )
                      : _Lux.royalGold,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _Lux.gold.withOpacity(
                        _isSaving ? 0.15 : 0.45,
                      ),
                      blurRadius: 14,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.20),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    else
                      const Icon(
                        Icons.save_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isSaving ? 'saving'.tr : 'save'.tr,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🖼️ قسم الصور (مُصغَّر)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildImagesSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _Lux.navyCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? _Lux.gold.withOpacity(0.12)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () =>
                setState(() => _imagesExpanded = !_imagesExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: _Lux.royalGold,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'product_images'.tr,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : _Lux.midnight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _Lux.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_selectedImages.length + (_selectedImagePath != null ? 1 : 0)}',
                      style: GoogleFonts.cairo(
                        color: _Lux.goldDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: _imagesExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color:
                      isDark ? Colors.white54 : Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: _imagesExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  _buildImagePicker(isDark),
                  const SizedBox(height: 10),
                  _buildMultipleImagesGallery(isDark),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 120, // ✅ كان 170
        decoration: BoxDecoration(
          gradient: _selectedImagePath == null
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
              _Lux.navyCard,
              _Lux.navySoft.withOpacity(0.6),
            ]
                : [
              _Lux.champagne.withOpacity(0.3),
              _Lux.gold.withOpacity(0.08),
            ],
          )
              : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _Lux.gold.withOpacity(0.30),
            width: 1.5,
          ),
        ),
        child: _selectedImagePath != null
            ? Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ImageHelper.displayImage(
                imagePath: _selectedImagePath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorWidget:
                const Icon(Icons.broken_image, size: 40),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.65),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'الصورة الرئيسية',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () =>
                    setState(() => _selectedImagePath = null),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _Lux.ruby,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: _Lux.ruby.withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44, // ✅ كان 56
              height: 44,
              decoration: BoxDecoration(
                gradient: _Lux.royalGold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _Lux.gold.withOpacity(0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  color: Colors.white, size: 22), // ✅ كان 28
            ),
            const SizedBox(height: 8),
            Text(
              'add_image'.tr,
              style: GoogleFonts.cairo(
                color: isDark ? Colors.white70 : _Lux.midnight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'اضغط لاختيار صورة رئيسية',
              style: GoogleFonts.cairo(
                color: Colors.grey.shade500,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleImagesGallery(bool isDark) {
    return SizedBox(
      height: 70, // ✅ كان 90
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length + 1,
        itemBuilder: (context, index) {
          if (index == _selectedImages.length) {
            return GestureDetector(
              onTap: _pickMultipleImages,
              child: Container(
                width: 62, // ✅ كان 80
                height: 62,
                decoration: BoxDecoration(
                  color: _Lux.gold.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _Lux.gold.withOpacity(0.40),
                    width: 1.4,
                  ),
                ),
                child: const Icon(Icons.add_a_photo_rounded,
                    color: _Lux.goldDeep, size: 20), // ✅ كان 24
              ),
            );
          }
          final image = _selectedImages[index];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImageHelper.displayImage(
                    imagePath: image,
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 3,
                  right: 3,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        final removed = _selectedImages.removeAt(index);
                        if (removed == _selectedImagePath) {
                          _selectedImagePath =
                          _selectedImages.isNotEmpty
                              ? _selectedImages.first
                              : null;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _Lux.ruby,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 10),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🏷️ عنوان القسم
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.4)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : _Lux.midnight,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎨 حقل إدخال فاخر مع RawAutocomplete
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLuxField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required List<String> suggestions,
    required bool isDark,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    bool isRequired = false,
    int maxLines = 1,
    String? suffix,
  }) {
    final effectiveFocus = focusNode ?? FocusNode();
    final showAutocomplete = suggestions.isNotEmpty && maxLines == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : _Lux.midnight,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _Lux.ruby,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
        showAutocomplete
            ? RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: effectiveFocus,
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query =
            textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return suggestions;
            final startsWith = suggestions
                .where((s) => s.toLowerCase().startsWith(query))
                .toList();
            final contains = suggestions
                .where((s) =>
            !s.toLowerCase().startsWith(query) &&
                s.toLowerCase().contains(query))
                .toList();
            return [...startsWith, ...contains];
          },
          onSelected: (value) {
            controller.text = value;
            controller.selection =
                TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
            _checkRequiredFields();
            if (mounted) setState(() {});
          },
          fieldViewBuilder: (context, textController, fNode,
              onFieldSubmitted) {
            return _buildFieldDecoration(
              controller: textController,
              focusNode: fNode,
              hint: hint,
              isDark: isDark,
              icon: icon,
              iconColor: iconColor,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              validator: validator,
              maxLines: maxLines,
              suffix: suffix,
              onChanged: (_) {},
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.arrow_drop_down_circle_rounded,
                  color: iconColor,
                  size: 22,
                ),
                onPressed: () => _showSelectionList(
                    label, suggestions, controller),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                color: isDark ? _Lux.navyCard : Colors.white,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxHeight: 220, maxWidth: 400),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 16, color: iconColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white
                                        : _Lux.midnight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        )
            : _buildFieldDecoration(
          controller: controller,
          focusNode: effectiveFocus,
          hint: hint,
          isDark: isDark,
          icon: icon,
          iconColor: iconColor,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          maxLines: maxLines,
          suffix: suffix,
          onChanged: (_) {},
        ),
      ],
    );
  }

  Widget _buildFieldDecoration({
    required TextEditingController controller,
    required FocusNode? focusNode,
    required String hint,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required String? Function(String?)? validator,
    required int maxLines,
    required String? suffix,
    required ValueChanged<String> onChanged,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      style: GoogleFonts.cairo(
        fontSize: 14,
        color: isDark ? Colors.white : _Lux.midnight,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(
          color: Colors.grey.shade500,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        // ✅ المظهر الجديد: حقل نص واضح
        filled: true,
        fillColor: isDark
            ? const Color(0xFF0E1622)
            : const Color(0xFFFAFBFC),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 14 : 15,
        ),
        // ✅ حدود أوضح
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: iconColor, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Lux.ruby, width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Lux.ruby, width: 2.0),
        ),
        // ✅ أيقونة داخل الحقل
        prefixIcon: Icon(
          icon,
          color: iconColor.withOpacity(0.75),
          size: 19,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 30,
        ),
        suffixIcon: suffixIcon ??
            (suffix != null
                ? Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              child: Text(
                suffix,
                style: GoogleFonts.cairo(
                  color: iconColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
                : null),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 50,
          minHeight: 30,
        ),
      ),
    );
  }
}