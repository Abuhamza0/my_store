import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'custom_category_model.dart';
import 'product_controller.dart';
import 'product_model.dart';
import 'add_product_page.dart';
import 'sub_category_products_page.dart';
import 'package:mystore/utils/image_helper.dart';
import 'package:mystore/core/services/locale_service.dart';

class CategoryDetailPage extends StatefulWidget {
  final CustomCategory category;

  const CategoryDetailPage({super.key, required this.category});

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  final _searchController = TextEditingController();
  final ProductController _pc = Get.find<ProductController>();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });
  }

  List<SubCategory> get _filteredSubCategories {
    if (_searchQuery.isEmpty) return widget.category.subCategories;
    return widget.category.subCategories
        .where((sub) =>
        sub.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<Product> get _searchedProducts {
    if (_searchQuery.isEmpty) return [];
    return _pc.products
        .where((p) =>
    p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.description.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    final catsBox = Hive.box('settings');
    final savedData =
    catsBox.get('custom_categories_data', defaultValue: <Map>[]);
    if (savedData is List) {
      final allCats = savedData
          .map((j) => CustomCategory.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      final idx = allCats.indexWhere((c) => c.id == widget.category.id);
      if (idx != -1) {
        allCats[idx] = widget.category;
      } else {
        allCats.add(widget.category);
      }
      catsBox.put(
          'custom_categories_data', allCats.map((c) => c.toJson()).toList());
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickCategoryImage() async {
    final imagePath = await ImageHelper.pickImage();
    if (imagePath != null && mounted) {
      setState(() {
        widget.category.imagePath = imagePath;
      });
      _saveCategory();
      if (mounted) {
        Get.snackbar(
          'success'.tr,
          'image_updated'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  void _showAddSubCategoryDialog() {
    final nameCtrl = TextEditingController();
    String? img;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'add_sub_category_title'.trParams({'name': widget.category.name}),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'sub_category_name_label'.tr,
                  prefixIcon: const Icon(Icons.label_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final p = await ImageHelper.pickImage();
                  if (p != null && mounted) {
                    setSt(() => img = p);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: img != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImageHelper.displayImage(
                      imagePath: img,
                      height: 60,
                      placeholder: const Icon(Icons.image_rounded,
                          color: Colors.grey),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded,
                          color: Colors.grey, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'image_optional'.tr,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  widget.category.subCategories.add(
                    SubCategory(name: nameCtrl.text.trim(), imagePath: img),
                  );
                  _saveCategory();
                  Navigator.pop(ctx);
                  Get.snackbar(
                    'success'.tr,
                    'sub_category_added'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label:
              Text('add'.tr, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2332),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShapeSelectionPopup(SubCategory subCategory) {
    subCategory.subCategories ??= [];

    bool isDialogActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380, maxHeight: 580),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A2332)
                    : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🌟 هيدر فاخر
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667eea).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // أيقونة
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: subCategory.imagePath != null && subCategory.imagePath!.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: ImageHelper.displayImage(
                              imagePath: subCategory.imagePath,
                              width: 56, height: 56,
                              placeholder: const Icon(Icons.category_rounded, color: Colors.white, size: 28),
                            ),
                          )
                              : const Icon(Icons.category_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subCategory.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'choose_preferred_shape'.tr,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // 📋 قائمة الأشكال
                  Flexible(
                    child: subCategory.subCategories!.isEmpty
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.inventory_2_outlined, size: 25, color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 10),
                            Text('no_shapes_yet'.tr, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('add_first_shape_hint'.tr, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                          ],
                        ),
                      ),
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: subCategory.subCategories!.length,
                      itemBuilder: (context, index) {
                        final shape = subCategory.subCategories![index];
                        return _buildShapeTile(
                          shape: shape,
                          subCategory: subCategory,
                          setDialogState: setDialogState,
                          isDialogActive: isDialogActive,
                        );
                      },
                    ),
                  ),

                  // 🔘 أزرار الإجراءات
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.15)
                          : Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: Text('close'.tr, style: const TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showAddShapeDialog(subCategory);
                                },
                                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                label: Text('add_shape'.tr, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF9800),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ✨ زر إضافة منتج
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Get.to(() => AddProductPage(categoryName: subCategory.name));
                            },
                            icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 16),
                            label: Text(
                              '${'add_product_to'.tr} ${subCategory.name}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A2332),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 2,
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
    ).then((_) {
      isDialogActive = false;
    });
  }
  Widget _buildShapeTile({
    required SubCategory shape,
    required SubCategory subCategory,
    required void Function(void Function()) setDialogState,
    required bool isDialogActive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6), // ✅ تصغير المسافة
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.03)])
            : LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
        borderRadius: BorderRadius.circular(14), // ✅ تصغير الانحناء
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _showFlavorSelectionPopup(shape);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // ✅ تصغير padding
          child: Row(
            children: [
              // صورة مصغرة
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ImageHelper.displayImage(
                  imagePath: shape.imagePath,
                  width: 38, height: 38, // ✅ تصغير من 55 إلى 38
                  placeholder: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.style_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // اسم الشكل
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shape.name,
                      style: TextStyle(
                        fontSize: 12, // ✅ تصغير من 15 إلى 12
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A2332),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'tap_to_view'.tr,
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade400), // ✅ تصغير
                    ),
                  ],
                ),
              ),
              // أزرار التحكم مصغرة
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.teal, size: 14), // ✅ تصغير
                onPressed: () async {
                  await _pickShapeImage(shape);
                  _saveCategory();
                  if (isDialogActive) setDialogState(() {});
                },
                tooltip: 'edit_image'.tr,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26), // ✅ تصغير
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 14), // ✅ تصغير
                onPressed: () {
                  if (isDialogActive) {
                    _confirmDeleteShape(subCategory, shape, () {
                      if (isDialogActive) setDialogState(() {});
                    } as void Function(void Function()));
                  }
                },
                tooltip: 'delete'.tr,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26), // ✅ تصغير
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 12), // ✅ تصغير
            ],
          ),
        ),
      ),
    );
  }

  void _showAddShapeDialog(SubCategory parentSub) {
    final nameCtrl = TextEditingController();
    String? img;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFFF9800), size: 40),
              const SizedBox(height: 8),
              Text(
                'add_new_shape'.trParams({'parent': parentSub.name}),
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'shape_name_label'.tr,
                  hintText: 'shape_name_hint'.tr,
                  prefixIcon: const Icon(Icons.style_rounded,
                      color: Color(0xFFFF9800)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final p = await ImageHelper.pickImage();
                  if (p != null && mounted) {
                    setSt(() => img = p);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF9800).withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFFF9800).withOpacity(0.05),
                  ),
                  child: img != null
                      ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ImageHelper.displayImage(
                          imagePath: img,
                          height: 100,
                          width: double.infinity,
                          placeholder: Container(
                            height: 100,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_rounded,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'tap_to_change_image'.tr,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                      : Column(
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 40,
                        color: const Color(0xFFFF9800).withOpacity(0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'add_shape_image'.tr,
                        style: TextStyle(
                          color: const Color(0xFFFF9800).withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'image_optional'.tr,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  parentSub.subCategories ??= [];
                  parentSub.subCategories!.add(
                    SubCategory(
                      name: nameCtrl.text.trim(),
                      imagePath: img,
                    ),
                  );
                  _saveCategory();
                  Navigator.pop(ctx);
                  _showShapeSelectionPopup(parentSub);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      Get.snackbar(
                        'success'.tr,
                        'shape_added_successfully'.tr,
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                      );
                    }
                  });
                }
              },
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label:
              Text('add'.tr, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickShapeImage(SubCategory shape) async {
    final imagePath = await ImageHelper.pickImage();
    if (imagePath != null && mounted) {
      setState(() {
        shape.imagePath = imagePath;
      });
    }
  }

  void _confirmDeleteShape(SubCategory parentSub, SubCategory shape,
      void Function(void Function()) setDialogState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('delete_shape_confirm'.trParams({'name': shape.name})),
        content: Text('delete_shape_warning'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              parentSub.subCategories!.remove(shape);
              _saveCategory();
              Navigator.pop(ctx);
              setDialogState(() {});
              Get.snackbar(
                'deleted'.tr,
                'shape_deleted'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
            Text('delete'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSubs = _filteredSubCategories;
    final searchedProducts = _searchedProducts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ==================== ✅ AppBar ساحر ====================
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1A2332),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Get.back(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _pickCategoryImage,
                      child: Hero(
                        tag: 'category_${widget.category.id}',
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ImageHelper.displayImage(
                              imagePath: widget.category.imagePath,
                              width: 42,
                              height: 42,
                              placeholder: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.2),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.store_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.category.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // ✅ خلفية متدرجة ساحرة
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1A2332),
                          Color(0xFF2D3F5F),
                          Color(0xFF1A2332),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // ✅ نقاط زخرفية
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.03),
                      ),
                    ),
                  ),
                  // ✅ خطوط زخرفية
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF667eea).withOpacity(0.8),
                            const Color(0xFF764ba2).withOpacity(0.8),
                            const Color(0xFFf093fb).withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white70, size: 20),
                onPressed: _pickCategoryImage,
                tooltip: 'change_image'.tr,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: _showAddSubCategoryDialog,
                  icon: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
                  label: Text(
                    'add_new_category'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          // ==================== شريط البحث ====================
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style:
                TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'search_categories_products'.tr,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF667eea)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // ==================== المحتوى ====================
          if (_searchQuery.isEmpty && filteredSubs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.label_off_rounded,
                          size: 50, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'no_subcategories'.tr,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'tap_add_subcategory'.tr,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddSubCategoryDialog,
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: Text(
                        'add_new_category'.tr,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // ========== الأصناف ==========
            if (filteredSubs.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${'subcategories_label'.tr} (${filteredSubs.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A2332),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverPadding(
                padding: const EdgeInsets.all(12), // ✅ padding أقل
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,        // ✅ 4 مجلدات في الصف
                    childAspectRatio: 1.1,   // ✅ مناسب لـ 4 أعمدة
                    crossAxisSpacing: 14,    // مسافة أفقية
                    mainAxisSpacing: 22,     // مسافة رأسية
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                        _buildSubCategoryCard(filteredSubs[index], isDark),
                    childCount: filteredSubs.length,
                  ),
                ),
              ),
            ),

            // ========== المنتجات (نتائج البحث) ==========
            if (_searchQuery.isNotEmpty && searchedProducts.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${'products_label'.tr} (${searchedProducts.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A2332),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...searchedProducts
                        .map((p) => _buildProductTile(p, isDark)),
                  ],
                ),
              ),

            // ========== لا توجد نتائج ==========
            if (_searchQuery.isNotEmpty &&
                filteredSubs.isEmpty &&
                searchedProducts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 70, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'no_results'.tr,
                        style:
                        const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
  // ==================== ✅ نافذة اختيار النكهة ====================
  void _showFlavorSelectionPopup(SubCategory shape) {
    shape.flavors ??= [];

    bool isDialogActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380, maxHeight: 580),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A2332)
                    : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9800).withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🌟 هيدر فاخر
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Icon(Icons.local_drink_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${'select_flavor_for'.tr} ${shape.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'choose_preferred_flavor'.tr,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // 📋 قائمة النكهات
                  Flexible(
                    child: shape.flavors!.isEmpty
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.local_drink_outlined, size: 25, color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 10),
                            Text('no_flavors_yet'.tr, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('add_first_flavor_hint'.tr, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                          ],
                        ),
                      ),
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: shape.flavors!.length,
                      itemBuilder: (context, index) {
                        final flavor = shape.flavors![index];
                        return _buildFlavorTile(
                          flavor: flavor,
                          shape: shape,
                          setDialogState: setDialogState,
                          isDialogActive: isDialogActive,
                        );
                      },
                    ),
                  ),

                  // 🔘 أزرار الإجراءات
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.15)
                          : Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Get.to(() => SubCategoryProductsPage(
                                    subCategory: shape,
                                    categoryName: '${widget.category.name} - ${shape.name}',
                                  ));
                                },
                                icon: const Icon(Icons.grid_view_rounded, size: 14),
                                label: Text('view_all'.tr, style: const TextStyle(fontSize: 10)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1A2332),
                                  side: const BorderSide(color: Color(0xFF1A2332), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showAddFlavorDialog(shape);
                                },
                                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                label: Text('add_flavor'.tr, style: const TextStyle(color: Colors.white, fontSize: 10)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ✨ زر إضافة منتج
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Get.to(() => AddProductPage(categoryName: shape.name));
                            },
                            icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 16),
                            label: Text(
                              '${'add_product_to'.tr} ${shape.name}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A2332),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 2,
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
    ).then((_) {
      isDialogActive = false;
    });
  }

// ✅ بطاقة النكهة
  Widget _buildFlavorTile({
    required Flavor flavor,
    required SubCategory shape,
    required void Function(void Function()) setDialogState,
    required bool isDialogActive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flavorColor = _getFlavorColor(flavor.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.03)])
            : LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: flavorColor.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Get.to(() => SubCategoryProductsPage(
            subCategory: shape,
            categoryName: '${widget.category.name} - ${shape.name}',
            selectedFlavor: flavor.name,
          ));
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [flavorColor.withOpacity(0.3), flavorColor.withOpacity(0.1)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: flavorColor.withOpacity(0.4), width: 1.2),
                ),
                child: Icon(_getFlavorIcon(flavor.name), color: flavorColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flavor.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A2332),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'tap_to_view_products'.tr,
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.teal, size: 14),
                onPressed: () {
                  _showEditFlavorDialog(flavor, shape, () {
                    if (isDialogActive) {
                      _saveCategory();
                      setDialogState(() {});
                    }
                  });
                },
                tooltip: 'edit'.tr,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 14),
                onPressed: () {
                  _confirmDeleteFlavor(shape, flavor, () {
                    if (isDialogActive) {
                      _saveCategory();
                      setDialogState(() {});
                    }
                  });
                },
                tooltip: 'delete'.tr,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 12),
            ],
          ),
        ),
      ),
    );
  }

// ✅ دوال مساعدة للألوان والأيقونات
  Color _getFlavorColor(String flavorName) {
    final name = flavorName.toLowerCase();
    if (name.contains('فراولة') || name.contains('strawberry') || name.contains('توت') || name.contains('berry')) {
      return Colors.red;
    } else if (name.contains('مانجو') || name.contains('mango') || name.contains('برتقال') || name.contains('orange')) {
      return Colors.orange;
    } else if (name.contains('نعناع') || name.contains('mint') || name.contains('منتول') || name.contains('menthol')) {
      return Colors.green;
    } else if (name.contains('عنب') || name.contains('grape')) {
      return Colors.purple;
    } else if (name.contains('ليمون') || name.contains('lemon')) {
      return Colors.amber;
    } else if (name.contains('بطيخ') || name.contains('watermelon')) {
      return Colors.pink;
    } else if (name.contains('تفاح') || name.contains('apple')) {
      return Colors.red.shade300;
    } else if (name.contains('خوخ') || name.contains('peach')) {
      return Colors.deepOrange.shade200;
    } else {
      return Colors.teal;
    }
  }

  IconData _getFlavorIcon(String flavorName) {
    final name = flavorName.toLowerCase();
    if (name.contains('نعناع') || name.contains('mint') || name.contains('منتول')) {
      return Icons.eco_rounded;
    } else if (name.contains('ثلج') || name.contains('ice') || name.contains('بارد')) {
      return Icons.ac_unit_rounded;
    } else {
      return Icons.local_drink_rounded;
    }
  }

// ✅ إضافة نكهة جديدة
  void _showAddFlavorDialog(SubCategory shape) {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.local_drink_rounded,
                color: Color(0xFF4CAF50), size: 40),
            const SizedBox(height: 8),
            Text(
              'add_new_flavor'.trParams({'shape': shape.name}),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'flavor_name_label'.tr,
            hintText: 'flavor_name_hint'.tr,
            prefixIcon: const Icon(Icons.local_drink_rounded,
                color: Color(0xFF4CAF50)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                shape.flavors ??= [];
                final exists = shape.flavors!.any(
                      (f) => f.name.toLowerCase() == nameCtrl.text.trim().toLowerCase(),
                );
                if (!exists) {
                  shape.flavors!.add(
                    Flavor(name: nameCtrl.text.trim()),
                  );
                  _saveCategory();
                  Navigator.pop(ctx);
                  _showFlavorSelectionPopup(shape);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      Get.snackbar(
                        'success'.tr,
                        'flavor_added_successfully'.tr,
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                      );
                    }
                  });
                } else {
                  Get.snackbar(
                    'warning'.tr,
                    'flavor_already_exists'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                }
              }
            },
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            label: Text('add'.tr, style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

// ✅ تعديل نكهة
  void _showEditFlavorDialog(Flavor flavor, SubCategory shape, VoidCallback onSave) {
    final nameCtrl = TextEditingController(text: flavor.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'edit_flavor'.tr,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'flavor_name_label'.tr,
            prefixIcon: const Icon(Icons.edit_rounded, color: Colors.teal),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                flavor.name = nameCtrl.text.trim();
                Navigator.pop(ctx);
                onSave();
                Get.snackbar(
                  'success'.tr,
                  'flavor_updated'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            label: Text('save'.tr, style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
// ✅ حذف نكهة
  void _confirmDeleteFlavor(SubCategory shape, Flavor flavor, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('delete_flavor_confirm'.trParams({'name': flavor.name})),
        content: Text('delete_flavor_warning'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              shape.flavors!.remove(flavor);
              Navigator.pop(ctx);
              onDelete();
              Get.snackbar(
                'deleted'.tr,
                'flavor_deleted'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  // ==================== ✅ بطاقة الصنف - مجلد مفتوح مصغر ====================
  Widget _buildSubCategoryCard(SubCategory sub, bool isDark) {
    // ألوان المجلدات الأصلية
    final colors = [
      const Color(0xFFFFB74D), const Color(0xFFFFD54F),
      const Color(0xFFFFCC80), const Color(0xFFFFE082),
      const Color(0xFFFFAB40), const Color(0xFFFFCA28),
      const Color(0xFFFFD740), const Color(0xFFFFC107),
      const Color(0xFFFFB300), const Color(0xFFFFE57F),
      const Color(0xFFFFCC02), const Color(0xFFFFA726),
    ];

    final colorIndex = sub.name.hashCode.abs() % colors.length;
    final folderColor = colors[colorIndex];
    final shapesCount = sub.subCategories?.length ?? 0;

    return GestureDetector(
      onTap: () => _showShapeSelectionPopup(sub),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        height: 120,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: folderColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 🎨 1. رسم المجلد
            Positioned.fill(
              child: CustomPaint(
                painter: MaterialFlatFolderPainter(color: folderColor),
              ),
            ),

            // 🔢 2. عداد الأشكال (في الأعلى يسار الواجهة الأمامية)
            Positioned(
              left: 20,
              bottom: 42, // مكان مرتفع قليلاً فوق النص
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.insert_drive_file_rounded,
                      color: Colors.deepOrangeAccent,
                      size: 10,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$shapesCount',
                      style: const TextStyle(
                        color: Colors.deepOrangeAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 📝 3. اسم الصنف (في الأسفل بشكل مباشر لضمان ظهوره دائماً)
            Positioned(
              left: 20,
              right: 14,
              bottom: 12,
              child: Text(
                sub.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.deepPurple,
                  height: 1.15,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ==================== ✅ بطاقة المنتج في البحث ====================
  Widget _buildProductTile(Product product, bool isDark) {
    final currency =
    Hive.box('settings').get('currency', defaultValue: 'SAR');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.03),
          ],
        )
            : const LinearGradient(
          colors: [Colors.white, Color(0xFFF8F9FA)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$currency${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFFFA500),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF667eea), size: 16),
          ),
        ],
      ),
    );
  }
}
class MaterialFlatFolderPainter extends CustomPainter {
  final Color color;

  MaterialFlatFolderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const double r = 8.0; // درجة انحناء زوايا المجلد

    // 🎨 إعداد الألوان: الغلاف الأمامي فاتح (اللون الأصلي)، والخلفي أغمق قليلاً
    final Color frontColor = color;
    final Color backColor = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness - 0.12).clamp(0.0, 1.0))
        .toColor();

    final Paint backPaint = Paint()..color = backColor..style = PaintingStyle.fill;
    final Paint frontPaint = Paint()..color = frontColor..style = PaintingStyle.fill;

    // 📏 أبعاد لسان المجلد الخلفي
    final double tabHeight = h * 0.22;
    final double tabWidth = w * 0.35;
    final double slantWidth = w * 0.08;

    // 📁 1. رسم الغلاف الخلفي
    final Path backPath = Path()
      ..moveTo(0, h - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0) // الزاوية العلوية اليسرى للسان
      ..lineTo(tabWidth - r, 0)
      ..quadraticBezierTo(tabWidth, 0, tabWidth + r * 0.5, r * 0.5) // بداية الميلان
      ..lineTo(tabWidth + slantWidth - r * 0.5, tabHeight - r * 0.5) // خط الميلان
      ..quadraticBezierTo(tabWidth + slantWidth, tabHeight, tabWidth + slantWidth + r, tabHeight) // نهاية الميلان
      ..lineTo(w - r, tabHeight) // الخط العلوي الأيمن
      ..quadraticBezierTo(w, tabHeight, w, tabHeight + r) // الزاوية العلوية اليمنى
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h) // الزاوية السفلية اليمنى
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r) // الزاوية السفلية اليسرى
      ..close();

    canvas.drawPath(backPath, backPaint);

    // 📏 أبعاد الغلاف الأمامي المائل
    final double flapTop = h * 0.36; // ارتفاع الغلاف الأمامي
    final double slantLeft = w * 0.15; // مقدار ميلان الحافة اليسرى

    // 📁 2. رسم الغلاف الأمامي (الجزء الأفتح)
    final Path frontPath = Path()
      ..moveTo(r, h) // نقطة البداية: الزاوية السفلية اليسرى
      ..quadraticBezierTo(0, h, 0, h - r) // الانحناء السفلي الأيسر مطابق للغلاف الخلفي
      ..lineTo(slantLeft, flapTop + r) // الخط المائل المتجه للأعلى واليمين
      ..quadraticBezierTo(slantLeft + r * 0.2, flapTop, slantLeft + r * 1.2, flapTop) // الزاوية العلوية اليسرى
      ..lineTo(w - r, flapTop) // الخط العلوي الأفقي
      ..quadraticBezierTo(w, flapTop, w, flapTop + r) // الزاوية العلوية اليمنى
      ..lineTo(w, h - r) // الخط العمودي الأيمن
      ..quadraticBezierTo(w, h, w - r, h) // الزاوية السفلية اليمنى
      ..close();

    // إضافة ظل داخلي خفيف جداً يفصل الطبقتين بلطف (اختياري، يضيف واقعية)
    canvas.drawShadow(frontPath, Colors.black.withOpacity(0.15), 1.0, true);
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}