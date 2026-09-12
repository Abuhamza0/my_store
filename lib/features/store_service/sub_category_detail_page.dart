import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'custom_category_model.dart';
import 'product_controller.dart';
import 'add_product_page.dart';
import 'sub_category_products_page.dart';
import 'package:mystore/core/services/locale_service.dart';

class SubCategoryDetailPage extends StatefulWidget {
  final CustomCategory category;
  final SubCategory subCategory;

  const SubCategoryDetailPage({
    super.key,
    required this.category,
    required this.subCategory,
  });

  @override
  State<SubCategoryDetailPage> createState() => _SubCategoryDetailPageState();
}

class _SubCategoryDetailPageState extends State<SubCategoryDetailPage> {
  final ProductController _pc = Get.find<ProductController>();

  @override
  void initState() {
    super.initState();
    ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });
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
      }
      catsBox.put(
          'custom_categories_data', allCats.map((c) => c.toJson()).toList());
    }
  }

  void _showAddSubSubCategoryDialog(SubCategory parentSub, bool isDark) {
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 20,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'add_category_in'.trParams({'name': parentSub.name}),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A2332),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'category_name_label'.tr,
                  hintText: 'category_name_hint'.tr,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.category_rounded,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'cancel'.tr,
                        style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isNotEmpty) {
                          parentSub.subCategories ??= [];
                          parentSub.subCategories!
                              .add(SubCategory(name: nameCtrl.text.trim()));
                          _saveCategory();
                          Navigator.pop(context);
                          setState(() {});
                          Get.snackbar(
                            'success'.tr,
                            'category_added'.tr,
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.teal,
                            colorText: Colors.white,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'ok'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = _pc.products
        .where((p) => p.category == widget.subCategory.name)
        .toList();
    final subCategories = widget.subCategory.subCategories ?? [];
    final subCatsCount = subCategories.length;
    final productsCount = products.length;

    final cardColors = [
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.lightGreen,
      Colors.purple,
    ];

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.subCategory.name),
        backgroundColor: const Color(0xFF1A2332),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => Get.to(
                      () => AddProductPage(categoryName: widget.subCategory.name)),
              icon: const Icon(Icons.add_shopping_cart_rounded,
                  color: Colors.white, size: 18),
              label: Text(
                'add_product_btn'.tr,
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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2332), Color(0xFF2D3A4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A2332).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.label_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.subCategory.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(
                      Icons.folder_rounded,
                      '$subCatsCount ${'categories_count'.tr}',
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      Icons.shopping_bag_rounded,
                      '$productsCount ${'products_count'.tr}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showAddSubSubCategoryDialog(widget.subCategory, isDark),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                label: Text(
                  'add_category_btn'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: subCategories.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_rounded,
                      size: 70, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'no_subcategories'.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'add_category_hint'.tr,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: subCategories.length,
              itemBuilder: (context, index) {
                final subCat = subCategories[index];
                final subCatProducts = _pc.products
                    .where((p) => p.category == subCat.name)
                    .length;
                final colorIndex =
                    subCat.name.hashCode.abs() % cardColors.length;
                final baseColor = cardColors[colorIndex];

                return Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? baseColor.withOpacity(0.12)
                        : baseColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? baseColor.withOpacity(0.25)
                          : baseColor.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Get.to(() =>
                            SubCategoryProductsPage(
                              subCategory: subCat,
                              categoryName:
                              '${widget.category.name} - ${widget.subCategory.name}',
                            )),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    subCat.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark
                                          ? baseColor.withOpacity(0.9)
                                          : baseColor.withOpacity(0.85),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$subCatProducts ${'products_count'.tr}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}