import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'custom_category_model.dart';
import 'product_controller.dart';
import 'product_model.dart';
import 'add_product_page.dart';
import 'package:mystore/utils/image_helper.dart';
import 'package:mystore/core/services/locale_service.dart';
import '../../core/services/sync_service.dart';

class SubCategoryProductsPage extends StatefulWidget {
  final SubCategory subCategory;
  final String categoryName;
  final String? selectedFlavor;

  const SubCategoryProductsPage({
    super.key,
    required this.subCategory,
    required this.categoryName,
    this.selectedFlavor,
  });

  @override
  State<SubCategoryProductsPage> createState() =>
      _SubCategoryProductsPageState();
}

class _SubCategoryProductsPageState extends State<SubCategoryProductsPage> {
  final _searchController = TextEditingController();
  final ProductController _pc = Get.find<ProductController>();
  String _searchQuery = '';
  bool _isGridView = true;
  String? _activeFlavor;

  @override
  void initState() {
    super.initState();
    _activeFlavor = widget.selectedFlavor;
    ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });
  }

  List<Product> get _filteredProducts {
    var products = _pc.products
        .where((p) => p.category == widget.subCategory.name)
        .toList();

    if (_activeFlavor != null && _activeFlavor!.isNotEmpty) {
      products = products.where((p) {
        return p.name.toLowerCase().contains(_activeFlavor!.toLowerCase()) ||
            p.description
                .toLowerCase()
                .contains(_activeFlavor!.toLowerCase()) ||
            (p.flavor?.toLowerCase() == _activeFlavor!.toLowerCase());
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      products = products.where((p) {
        return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return products;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ ==================== النافذة المنبثقة لتفاصيل المنتج مع الأحجام ====================
  void _showProductDetailPopup(Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency =
    Hive.box('settings').get('currency', defaultValue: 'SAR');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2332) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ صورة المنتج
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                    child: ImageHelper.displayImage(
                      imagePath: product.imagePath !=
                          'assets/images/product_placeholder.png'
                          ? product.imagePath
                          : null,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        height: 180,
                        color: Colors.teal.withOpacity(0.1),
                        child: const Icon(Icons.shopping_bag_rounded,
                            size: 60, color: Colors.teal),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                      ),
                    ),
                  ),
                  // معلومات المنتج على الصورة
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.flavor != null &&
                            product.flavor!.isNotEmpty)
                          Text(
                            '🍹 ${product.flavor}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // ✅ محتوى النافذة
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ إذا كان المنتج له أحجام متعددة
                    if (product.hasMultipleSizes &&
                        product.sizes != null &&
                        product.sizes!.isNotEmpty) ...[
                      // عنوان الأحجام
                      Row(
                        children: [
                          const Icon(Icons.straighten_rounded,
                              color: Color(0xFFFF9800), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'available_sizes'.tr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A2332),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ✅ قائمة الأحجام
                      ...product.sizes!.map((size) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFF9800).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              // أيقونة الحجم
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9800)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.straighten_rounded,
                                  color: Color(0xFFFF9800),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // معلومات الحجم
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      size.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A2332),
                                      ),
                                    ),
                                    if (size.description != null &&
                                        size.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          size.description!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // السعر والمخزون
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$currency${size.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: size.stock > 0
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      size.stock > 0
                                          ? '${'available'.tr}: ${size.stock}'
                                          : 'out_of_stock'.tr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: size.stock > 0
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      // ✅ منتج بدون أحجام - عرض السعر الأساسي
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '$currency${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${'stock_label'.tr}: ${product.stock}',
                              style: TextStyle(
                                fontSize: 14,
                                color: product.stock > 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ✅ الوصف
                    if (product.description.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.description_rounded,
                                    color: Colors.orange, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'description_label'.tr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ✅ معلومات إضافية
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _infoChip(Icons.star_rounded,
                              product.rating.toStringAsFixed(1), Colors.amber),
                          _infoChip(Icons.inventory_2_rounded,
                              '${product.stock}', Colors.teal),
                          _infoChip(Icons.reviews_rounded,
                              '${product.reviewCount}', Colors.blue),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ أزرار الإجراءات
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                            label: Text('close'.tr),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Get.to(
                                      () => AddProductPage(product: product));
                            },
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.white),
                            label: Text('edit'.tr,
                                style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A2332),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ ويدجت معلومات صغير
  Widget _infoChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ==================== شريط النكهة النشطة ====================
  Widget _buildActiveFlavorBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? Colors.teal.shade900 : Colors.teal.shade50,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_drink_rounded,
                color: Colors.teal, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'selected_flavor'.tr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  _activeFlavor!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.teal.shade800,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _activeFlavor = null);
              Get.snackbar(
                'flavor_cleared'.tr,
                'showing_all_products'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.grey.shade600,
                colorText: Colors.white,
                duration: const Duration(seconds: 1),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.red, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== نافذة اختيار النكهة ====================
  void _showFlavorFilterSheet() {
    if (widget.subCategory.flavors == null ||
        widget.subCategory.flavors!.isEmpty) {
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.bottomSheet(
      Container(
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2332) : Colors.white,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'select_flavor'.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A2332),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _activeFlavor = null);
                    Get.back();
                  },
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text('show_all'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: widget.subCategory.flavors!.length,
                itemBuilder: (context, index) {
                  final flavor = widget.subCategory.flavors![index];
                  final isSelected = _activeFlavor == flavor.name;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.teal.withOpacity(0.1)
                          : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.teal
                            : (isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.2)),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.teal
                              : Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_drink_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        flavor.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A2332),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                          color: Colors.teal)
                          : const Icon(Icons.circle_outlined,
                          color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onTap: () {
                        setState(() => _activeFlavor = flavor.name);
                        Get.back();
                        Get.snackbar(
                          'flavor_selected'.tr,
                          '${'showing_products_for'.tr} ${flavor.name}',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.teal,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 2),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subCategory.name,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_activeFlavor != null && _activeFlavor!.isNotEmpty)
              Text(
                '🍹 $_activeFlavor',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_rounded, color: Colors.white),
            onPressed: () async {
              Get.dialog(
                const Center(child: CircularProgressIndicator()),
                barrierDismissible: false,
              );

              final syncService = SyncService();
              final success = await syncService.fetchAllData();

              if (Get.isDialogOpen ?? false) Get.back();

              if (success) {
                _pc.loadProducts();
                setState(() {});
                Get.snackbar('نجاح', 'تم جلب المنتجات من السحابة',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green, colorText: Colors.white);
              } else {
                Get.snackbar('خطأ', 'فشل جلب البيانات',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red, colorText: Colors.white);
              }
            },
            tooltip: 'جلب من السحابة',
          ),
          if (widget.subCategory.flavors != null &&
              widget.subCategory.flavors!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.local_drink_rounded,
                  color: Colors.white, size: 22),
              onPressed: _showFlavorFilterSheet,
              tooltip: 'change_flavor'.tr,
            ),
          IconButton(
            icon: Icon(
              _isGridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'view_list'.tr : 'view_grid'.tr,
          ),
          IconButton(
            icon: const Icon(Icons.add_shopping_cart_rounded,
                color: Colors.white),
            onPressed: () => Get.to(() => AddProductPage(
                categoryName: widget.subCategory.name,
                flavor: _activeFlavor)),
            tooltip: 'add_product'.tr,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_activeFlavor != null && _activeFlavor!.isNotEmpty)
            _buildActiveFlavorBar(isDark),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.08), blurRadius: 10)
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style:
              TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: _activeFlavor != null
                    ? 'search_in_flavor'.trParams({'flavor': _activeFlavor!})
                    : 'search_products'.tr,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.teal),
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
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor:
                isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),

          Expanded(
            child: products.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _activeFlavor != null
                        ? Icons.local_drink_outlined
                        : Icons.inventory_2_rounded,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _activeFlavor != null
                        ? 'no_products_for_flavor'.trParams({
                      'flavor': _activeFlavor!,
                    })
                        : _searchQuery.isNotEmpty
                        ? 'no_results'.tr
                        : 'no_products'.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_activeFlavor != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'try_another_flavor'.tr,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _activeFlavor = null);
                      },
                      icon: const Icon(Icons.clear_all_rounded),
                      label: Text('show_all_products'.tr),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'tap_add_product'.tr,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => Get.to(() => AddProductPage(
                          categoryName: widget.subCategory.name)),
                      icon: const Icon(Icons.add_rounded,
                          color: Colors.white),
                      label: Text(
                        'add_product'.tr,
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: () async => _pc.loadProducts(),
              child: _isGridView
                  ? _buildGridView(products, isDark)
                  : _buildListView(products, isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== عرض شبكي ====================
  Widget _buildGridView(List<Product> products, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) =>
          _buildProductCard(products[index], isDark),
    );
  }

  // ==================== عرض قائمة ====================
  Widget _buildListView(List<Product> products, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) =>
          _buildProductListItem(products[index], isDark),
    );
  }

  // ==================== ✅ بطاقة المنتج - شبكي ====================
  Widget _buildProductCard(Product product, bool isDark) {
    final currency =
    Hive.box('settings').get('currency', defaultValue: 'SAR');

    return GestureDetector(
      // ✅ الضغط يفتح النافذة المنبثقة
      onTap: () => _showProductDetailPopup(product),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                      child: _buildProductImage(product),
                    ),
                  ),
                  // السعر
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$currency${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // ✅ شارة الأحجام المتعددة
                  if (product.hasMultipleSizes)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.straighten_rounded,
                                color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              'أحجام',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // ✅ شارة النكهة
                  if (product.flavor != null && product.flavor!.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🍹 ${product.flavor}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // أزرار التعديل والحذف
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              Get.to(() => AddProductPage(product: product)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                size: 14, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showDeleteDialog(product),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete_rounded,
                                size: 14, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description.isNotEmpty
                          ? product.description
                          : 'no_description_short'.tr,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 12, color: Colors.amber.shade600),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500),
                        ),
                        const Spacer(),
                        Text(
                          '${'stock_label'.tr}: ${product.stock}',
                          style: TextStyle(
                              fontSize: 9, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ✅ بطاقة المنتج - قائمة ====================
  Widget _buildProductListItem(Product product, bool isDark) {
    final currency =
    Hive.box('settings').get('currency', defaultValue: 'SAR');

    return GestureDetector(
      // ✅ الضغط يفتح النافذة المنبثقة
      onTap: () => _showProductDetailPopup(product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.06), blurRadius: 10)
          ],
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 60,
                height: 60,
                child: _buildProductImage(product),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A2332),
                          ),
                        ),
                      ),
                      if (product.flavor != null &&
                          product.flavor!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '🍹 ${product.flavor}',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      // ✅ شارة الأحجام
                      if (product.hasMultipleSizes)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.straighten_rounded,
                                  color: Color(0xFFFF9800), size: 10),
                              SizedBox(width: 2),
                              Text(
                                'أحجام',
                                style: TextStyle(
                                  color: Color(0xFFFF9800),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description.isNotEmpty
                        ? product.description
                        : 'no_description_short'.tr,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$currency${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber.shade600),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                      const Spacer(),
                      Text(
                        '${'stock_label'.tr}: ${product.stock}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () =>
                      Get.to(() => AddProductPage(product: product)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.blue, size: 18),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showDeleteDialog(product),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.red, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== دالة عرض الصورة ====================
  Widget _buildProductImage(Product product) {
    return ImageHelper.displayImage(
      imagePath: product.imagePath.isNotEmpty &&
          product.imagePath != 'assets/images/product_placeholder.png'
          ? product.imagePath
          : null,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: _buildPlaceholder(),
      errorWidget: _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          size: 40,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ==================== حوار الحذف ====================
  void _showDeleteDialog(Product product) {
    showDialog(
      context: Get.context!,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('delete_product_title'.tr),
        content:
        Text('${'delete_product_confirm'.tr} "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              _pc.deleteProduct(product.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'delete'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}