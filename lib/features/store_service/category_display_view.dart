// category_display_view.dart
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/image_upload_service.dart';
import '../../core/services/store_id_service.dart';
import 'add_product_page.dart';
import 'custom_category_model.dart';
import 'product_controller.dart';
import 'product_model.dart';
import 'package:mystore/utils/image_helper.dart';

// ═══════════════════════════════════════════════════════════════
//  🎨 لوحة ألوان فاخرة موحّدة
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
  static const Color teal = Color(0xFF14B8A6);

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

class CategoryDisplayView extends StatefulWidget {
  final ProductController pc;
  final RxList<CustomCategory> cats;
  final bool isDark;
  final RxString selectedCategory;
  final RxString selectedSub;
  final RxString selectedType;
  final RxString selectedFlavor;

  const CategoryDisplayView({
    Key? key,
    required this.pc,
    required this.cats,
    required this.isDark,
    required this.selectedCategory,
    required this.selectedSub,
    required this.selectedType,
    required this.selectedFlavor,
  }) : super(key: key);

  @override
  State<CategoryDisplayView> createState() => _CategoryDisplayViewState();
}

class _CategoryDisplayViewState extends State<CategoryDisplayView> {
  ProductController get pc => widget.pc;
  RxList<CustomCategory> get cats => widget.cats;
  bool get isDark => widget.isDark;
  RxString get selectedCategory => widget.selectedCategory;
  RxString get selectedSub => widget.selectedSub;
  RxString get selectedType => widget.selectedType;
  RxString get selectedFlavor => widget.selectedFlavor;

  final RxString selectedSubType = 'all'.obs;

  final RxString levelOneLabel = 'level_one_label_default'.tr.obs;
  final RxString levelTwoLabel = 'level_two_label_default'.tr.obs;
  final RxString levelThreeLabel = 'level_three_label_default'.tr.obs;
  final RxString levelFourLabel = 'level_four_label_default'.tr.obs;
  final RxString levelFiveLabel = 'level_five_label_default'.tr.obs;

  final RxBool levelOneLabelVisible = true.obs;
  final RxBool levelTwoLabelVisible = true.obs;
  final RxBool levelThreeLabelVisible = true.obs;
  final RxBool levelFourLabelVisible = true.obs;
  final RxBool levelFiveLabelVisible = true.obs;

  final RxBool showLevelFiveBar = false.obs;

  @override
  void initState() {
    super.initState();
    _loadBarLabels();
    ever(selectedCategory, (_) => _resetLowerLevels(1));
    ever(selectedSub, (_) => _resetLowerLevels(2));
    ever(selectedType, (_) => _resetLowerLevels(3));
    ever(selectedFlavor, (_) => _resetLowerLevels(4));
  }

  void _loadBarLabels() {
    final box = Hive.box('settings');
    final saved = box.get('category_bar_labels');
    if (saved is Map) {
      levelOneLabel.value = saved['level1'] ?? 'level_one_label_default'.tr;
      levelTwoLabel.value = saved['level2'] ?? 'level_two_label_default'.tr;
      levelThreeLabel.value = saved['level3'] ?? 'level_three_label_default'.tr;
      levelFourLabel.value = saved['level4'] ?? 'level_four_label_default'.tr;
      levelFiveLabel.value = saved['level5'] ?? 'level_five_label_default'.tr;
    }
  }

  void _saveBarLabels() {
    Hive.box('settings').put('category_bar_labels', {
      'level1': levelOneLabel.value,
      'level2': levelTwoLabel.value,
      'level3': levelThreeLabel.value,
      'level4': levelFourLabel.value,
      'level5': levelFiveLabel.value,
    });
  }

  Future<void> _editBarLabel(RxString label) async {
    final controller = TextEditingController(text: label.value);
    final result = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _Lux.royalGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text('edit_bar_label'.tr,
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.cairo(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'bar_title_hint'.tr,
            hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Lux.gold, width: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Lux.midnight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('save'.tr,
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      label.value = result;
      _saveBarLabels();
    }
  }

  void _resetLowerLevels(int level) {
    if (level <= 1) {
      selectedSub.value = 'all';
      selectedType.value = 'all';
      selectedFlavor.value = 'all';
      selectedSubType.value = 'all';
      showLevelFiveBar.value = false;
    } else if (level == 2) {
      selectedType.value = 'all';
      selectedFlavor.value = 'all';
      selectedSubType.value = 'all';
      showLevelFiveBar.value = false;
    } else if (level == 3) {
      selectedFlavor.value = 'all';
      selectedSubType.value = 'all';
      showLevelFiveBar.value = false;
    } else if (level == 4) {
      selectedSubType.value = 'all';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  💾 حفظ التصنيفات — مع deviceId تلقائياً
  // ═══════════════════════════════════════════════════════════════
  void _saveCategories() async {
    // 1. حفظ محلي في Hive
    Hive.box('settings')
        .put('custom_categories_data', cats.map((c) => c.toJson()).toList());

    // 2. التحقق من storeId
    final storeId = StoreIdService.getStoreId();
    if (storeId.isEmpty || storeId == 'default_store') {
      print('⚠️ Cannot save categories - invalid storeId');
      return;
    }

    // 3. معالجة الصور
    final processedCategories = await _processImagesInCategories(
        cats.map((c) => c.toJson()).toList());

    // 4. الرفع إلى Firestore مع deviceId تلقائياً
    try {
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(storeId)
          .set(
        StoreIdService.stamp({
          'custom_categories_data': processedCategories,
          'store_id': storeId,
          'updated_at': FieldValue.serverTimestamp(),
        }),
        SetOptions(merge: true),
      );

      print('✅ Categories uploaded to cloud successfully');
    } catch (e) {
      print('❌ Error uploading categories: $e');
    }
  }

  Future<dynamic> _processImagesInCategories(dynamic data) async {
    if (data is List) {
      final result = [];
      for (var item in data) {
        result.add(await _processImagesInCategories(item));
      }
      return result;
    } else if (data is Map) {
      final result = <String, dynamic>{};
      for (var entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (key == 'imagePath' &&
            value is String &&
            value.startsWith('data:image')) {
          final uploadedUrl = await _uploadBase64Image(value, 'categories');
          result[key] = uploadedUrl ?? value;
        } else {
          result[key] = await _processImagesInCategories(value);
        }
      }
      return result;
    }
    return data;
  }

  Future<String?> _uploadBase64Image(String base64Data, String folder) async {
    try {
      final bytes = base64Decode(base64Data.split(',').last);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageService = ImageUploadService();
      final url = await imageService.uploadBytes(
        bytes: bytes,
        fileName: fileName,
        folder: folder,
      );
      return url;
    } catch (e) {
      print('❌ Failed to upload Base64 image: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  🏗️ البناء الرئيسي
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (cats.isEmpty && pc.products.isNotEmpty) {
      // استخدم Future.microtask لتجنب التعديل أثناء البناء
      Future.microtask(() => _autoGenerateCategoriesFromProducts());

      // اعرض شاشة تحميل مؤقتة
      return _buildGeneratingState();
    }

    if (cats.isEmpty) return _buildEmptyCategoriesState();

    return Column(
      children: [
        _buildLevelOneBar(),
        Obx(() {
          if (selectedCategory.value == 'all') return const SizedBox.shrink();
          final cat = _findCategory(selectedCategory.value, cats);
          if (cat == null || cat.subCategories.isEmpty) {
            return const SizedBox.shrink();
          }
          return _buildLevelTwoBar(cat);
        }),
        Obx(() {
          if (selectedSub.value == 'all') return const SizedBox.shrink();
          final cat = _findCategory(selectedCategory.value, cats);
          if (cat == null) return const SizedBox.shrink();
          final sub = _findSub(cat, selectedSub.value);
          if (sub == null ||
              sub.subCategories == null ||
              sub.subCategories!.isEmpty) {
            return const SizedBox.shrink();
          }
          return _buildLevelThreeBar(sub, cat);
        }),
        Obx(() {
          if (selectedType.value == 'all') return const SizedBox.shrink();
          final cat = _findCategory(selectedCategory.value, cats);
          if (cat == null) return const SizedBox.shrink();
          final sub = _findSub(cat, selectedSub.value);
          if (sub == null) return const SizedBox.shrink();
          final type = _findTypeRecursive(sub, selectedType.value);
          if (type == null) return const SizedBox.shrink();
          if ((type.flavors ?? []).isEmpty) return const SizedBox.shrink();
          return _buildLevelFourBar(type, cat);
        }),
        Obx(() {
          if (!showLevelFiveBar.value || selectedType.value == 'all') {
            return const SizedBox.shrink();
          }
          final cat = _findCategory(selectedCategory.value, cats);
          if (cat == null) return const SizedBox.shrink();
          final sub = _findSub(cat, selectedSub.value);
          if (sub == null) return const SizedBox.shrink();
          final type = _findTypeRecursive(sub, selectedType.value);
          if (type == null) return const SizedBox.shrink();
          return _buildLevelFiveBar(type, cat);
        }),
        Expanded(child: Obx(() => _buildContent())),
      ],
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  ///  🪄 إنشاء الأقسام تلقائياً من بيانات المنتجات
  ///  (يُستخدم فقط إذا كانت السحابة فارغة من الأقسام)
  /// ═══════════════════════════════════════════════════════════════
  void _autoGenerateCategoriesFromProducts() {
    // ✅ 1. تحقق أن الأقسام فارغة
    if (cats.isNotEmpty) return;

    // ✅ 2. تحقق أن هناك منتجات
    final products = pc.products.toList();
    if (products.isEmpty) {
      print('ℹ️ [AutoCats] لا توجد منتجات لاستخراج الأقسام');
      return;
    }

    print('🪄 [AutoCats] بدء استخراج الأقسام من ${products.length} منتج...');

    // ═══════════════════════════════════════════════════════════
    //  📊 3. جمع البيانات الفريدة
    // ═══════════════════════════════════════════════════════════
    final Map<String, Set<String>> categoriesMap = {}; // category → flavors
    final Set<String> allFlavors = {};

    for (final product in products) {
      final category = product.category.trim();
      final flavor = product.flavor?.trim() ?? '';

      if (category.isEmpty || category == 'general') continue;

      // إضافة القسم
      categoriesMap.putIfAbsent(category, () => <String>{});

      // إضافة النكهة للقسم
      if (flavor.isNotEmpty) {
        categoriesMap[category]!.add(flavor);
        allFlavors.add(flavor);
      }
    }

    if (categoriesMap.isEmpty) {
      print('ℹ️ [AutoCats] لا توجد أقسام صالحة للاستخراج');
      return;
    }

    // ═══════════════════════════════════════════════════════════
    //  🏗️ 4. بناء الأقسام
    // ═══════════════════════════════════════════════════════════
    final List<CustomCategory> generatedCategories = [];

    categoriesMap.forEach((categoryName, flavors) {
      // ─── القسم ───
      final category = CustomCategory(
        name: categoryName,
        imagePath: null,
        subCategories: [],
      );

      // ─── القسم الفرعي (نوع عام) ───
      final subCategory = SubCategory(
        name: categoryName,  // نفس اسم القسم
        imagePath: null,
        subCategories: [],
        flavors: [],
      );

      // ─── الأنواع الفرعية (إذا كانت النكهات كثيرة) ───
      if (flavors.isNotEmpty) {
        // كل نكهة تصبح "نوع" تحت القسم الفرعي
        for (final flavor in flavors) {
          final flavorType = SubCategory(
            name: flavor,
            imagePath: null,
            subCategories: [],
            flavors: [Flavor(name: flavor)],
          );
          subCategory.subCategories!.add(flavorType);
        }

        // ✅ أيضاً احتفظ بالنكهات على المستوى الأول
        for (final flavor in flavors) {
          subCategory.flavors!.add(Flavor(name: flavor));
        }
      }

      category.subCategories.add(subCategory);
      generatedCategories.add(category);
    });

    // ═══════════════════════════════════════════════════════════
    //  💾 5. الحفظ في cats + Hive
    // ═══════════════════════════════════════════════════════════
    cats.assignAll(generatedCategories);

    Hive.box('settings').put(
      'custom_categories_data',
      cats.map((c) => c.toJson()).toList(),
    );

    print('✅ [AutoCats] تم إنشاء ${generatedCategories.length} قسم من المنتجات');

    // ═══════════════════════════════════════════════════════════
    //  📤 6. رفع إلى السحابة (اختياري)
    // ═══════════════════════════════════════════════════════════
    _saveCategories();

    // ═══════════════════════════════════════════════════════════
    //  📢 7. إشعار المستخدم
    // ═══════════════════════════════════════════════════════════
    Get.snackbar(
      '🪄 تم إنشاء الأقسام تلقائياً',
      'تم استخراج ${generatedCategories.length} قسم من ${products.length} منتج',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _Lux.emerald,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
    );
  }

  /// حالة "جارٍ إنشاء الأقسام"
  Widget _buildGeneratingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _Lux.gold.withOpacity(0.15),
                  _Lux.gold.withOpacity(0.04),
                ],
              ),
              border: Border.all(
                color: _Lux.gold.withOpacity(0.30),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(_Lux.gold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'جارٍ إنشاء الأقسام من المنتجات...',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : _Lux.midnight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'يتم استخراج الأقسام والنكهات تلقائياً',
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎯 شريط الفئات العام
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBarWithFixedLabel({
    required RxString labelRx,
    required RxBool labelVisible,
    required Color color,
    required List<String> items,
    required RxString selectedValue,
    required void Function(String) onTapItem,
    required VoidCallback onAddTap,
    String prefix = '',
    void Function(String)? onLongPressItem,
    List<Widget> extraActions = const [],
  }) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? _Lux.navyCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.20 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.20 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.20),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Obx(() {
            final visible = labelVisible.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.fastOutSlowIn,
              width: visible ? 100 : 46,
              height: double.infinity,
              margin:
              const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
              child: ClipPath(
                clipper: ArrowTabClipper(
                  cutSize: visible ? 12.0 : 8.0,
                  isRTL:
                  Directionality.of(context) != TextDirection.rtl,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: visible
                          ? [
                        color.withOpacity(0.28),
                        color.withOpacity(0.12),
                      ]
                          : [
                        color.withOpacity(0.16),
                        color.withOpacity(0.06),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: labelVisible.toggle,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: visible
                            ? _buildExpandedLabel(
                          labelRx: labelRx,
                          color: color,
                          itemsCount: items.length,
                        )
                            : _buildCollapsedArrow(color: color),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 3),

          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              itemCount: items.length + 2 + extraActions.length,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Obx(() {
                    final isSelected = selectedValue.value == 'all';
                    return _buildChip(
                      label: '📂 ${'all'.tr}',
                      selected: isSelected,
                      color: color,
                      onTap: () => onTapItem('all'),
                    );
                  });
                }

                if (index < items.length + 1) {
                  final item = items[index - 1];
                  return Obx(() {
                    final isSelected = selectedValue.value == item;
                    return _buildChip(
                      label: '$prefix$item',
                      selected: isSelected,
                      color: color,
                      onTap: () => onTapItem(item),
                      onLongPress: onLongPressItem != null
                          ? () => onLongPressItem(item)
                          : null,
                    );
                  });
                }

                if (index == items.length + 1) {
                  return _buildAddButton(onTap: onAddTap, color: color);
                }

                return extraActions[index - items.length - 2];
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
//  ✏️ حوار تعديل الاسم فقط
// ═══════════════════════════════════════════════════════════════
  Future<String?> _promptForNameOnly({
    required String title,
    required String initialName,
    required Color accentColor,
  }) async {
    final controller = TextEditingController(text: initialName);

    final result = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        backgroundColor: isDark ? _Lux.navyCard : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.75)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.edit_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : _Lux.midnight,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: isDark ? Colors.white : _Lux.midnight,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'name'.tr,
            hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
            filled: true,
            fillColor: isDark ? _Lux.navyCard : Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? _Lux.gold.withOpacity(0.15)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accentColor, width: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Get.back(result: v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
            ),
            child: Text(
              'save'.tr,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    return result;
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.75)],
          )
              : null,
          color: selected ? null : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.20),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: color.withOpacity(0.40),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 62),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton({required VoidCallback onTap, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.75)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.40),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedLabel({
    required RxString labelRx,
    required Color color,
    required int itemsCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 18),
          const SizedBox(width: 2),
          Expanded(
            child: GestureDetector(
              onTap: () => _editBarLabel(labelRx),
              child: Obx(() => Text(
                labelRx.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              )),
            ),
          ),
          if (itemsCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$itemsCount',
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsedArrow({required Color color}) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    return Center(
      child: Icon(
        isRTL
            ? Icons.keyboard_arrow_left_rounded
            : Icons.keyboard_arrow_right_rounded,
        color: color,
        size: 22,
      ),
    );
  }

  Future<void> _showItemOptionsDialog({
    required String itemName,
    required Color accentColor,
    required Future<void> Function() onEdit,
    required Future<void> Function() onDelete,
    String? extraInfo,
  }) async {
    final result = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? _Lux.navyCard : Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.75)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.tune_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'options'.tr,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _Lux.midnight,
                    ),
                  ),
                  Text(
                    itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (extraInfo != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: accentColor.withOpacity(0.20), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        extraInfo,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : _Lux.midnight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildOptionTile(
              icon: Icons.edit_rounded,
              label: 'edit_name'.tr,
              color: _Lux.sapphire,
              onTap: () => Get.back(result: 'edit'),
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'delete'.tr,
              color: _Lux.ruby,
              onTap: () => Get.back(result: 'delete'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (result == 'edit') {
      await onEdit();
    } else if (result == 'delete') {
      await onDelete();
    }
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.20), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _Lux.midnight,
                  ),
                ),
              ),
              Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.grey.shade400, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  📊 المستويات الخمسة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLevelOneBar() {
    return _buildBarWithFixedLabel(
      labelRx: levelOneLabel,
      labelVisible: levelOneLabelVisible,
      color: _Lux.violet,
      items: cats.map((c) => c.name).toList(),
      selectedValue: selectedCategory,
      onTapItem: (name) {
        selectedCategory.value = name;
        selectedSub.value = 'all';
        selectedType.value = 'all';
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      },
      onAddTap: () => _showAddCategoryDialog(),
      prefix: '📁 ',
      onLongPressItem: (name) {
        final cat = _findCategory(name, cats);
        if (cat == null) return;
        _showItemOptionsDialog(
          itemName: cat.name,
          accentColor: _Lux.violet,
          extraInfo:
          '${cat.subCategories.length} ${'sub_categories'.tr}',
          onEdit: () async {
            final newName = await _promptForNameOnly(
              title: 'edit_category'.tr,
              initialName: cat.name,
              accentColor: _Lux.violet,
            );
            if (newName != null && newName.isNotEmpty) {
              cat.name = newName;
              _refreshData();
            }
          },
          onDelete: () async {
            await _confirmDeleteCategory(cat);
          },
        );
      },
    );
  }

  Widget _buildLevelTwoBar(CustomCategory cat) {
    return _buildBarWithFixedLabel(
      labelRx: levelTwoLabel,
      labelVisible: levelTwoLabelVisible,
      color: _Lux.emerald,
      items: cat.subCategories.map((s) => s.name).toList(),
      selectedValue: selectedSub,
      onTapItem: (name) {
        selectedSub.value = name;
        selectedType.value = 'all';
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      },
      onAddTap: () => _showAddSubCategoryDialog(cat),
      prefix: '📁 ',
      onLongPressItem: (name) {
        final sub = _findSub(cat, name);
        if (sub == null) return;
        _showItemOptionsDialog(
          itemName: sub.name,
          accentColor: _Lux.emerald,
          extraInfo: (sub.subCategories?.isEmpty ?? true)
              ? 'no_subcategories_yet'.tr
              : '${sub.subCategories!.length} ${'types_count'.tr}',
          onEdit: () async {
            final newName = await _promptForNameOnly(
              title: 'edit_subcategory'.tr,
              initialName: sub.name,
              accentColor: _Lux.emerald,
            );
            if (newName != null && newName.isNotEmpty) {
              sub.name = newName;
              _refreshData();
            }
          },
          onDelete: () async {
            await _confirmDeleteSub(cat, sub);
          },
        );
      },
    );
  }

  Widget _buildLevelThreeBar(SubCategory sub, CustomCategory cat) {
    final items = (sub.subCategories ?? []).map((t) => t.name).toList();

    final type = selectedType.value != 'all'
        ? _findTypeRecursive(sub, selectedType.value)
        : null;
    final shouldShowAddFlavor = type != null && (type.flavors ?? []).isEmpty;

    return _buildBarWithFixedLabel(
      labelRx: levelThreeLabel,
      labelVisible: levelThreeLabelVisible,
      color: _Lux.amber,
      items: items,
      selectedValue: selectedType,
      onTapItem: (name) {
        selectedType.value = name;
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      },
      onAddTap: () => _showAddSubSubCategoryDialog(sub, cat),
      prefix: '🏷️ ',
      onLongPressItem: (name) {
        final t = (sub.subCategories ?? []).firstWhereOrNull(
              (e) => e.name == name,
        );
        if (t == null) return;
        _showItemOptionsDialog(
          itemName: t.name,
          accentColor: _Lux.amber,
          extraInfo: '${(t.flavors ?? []).length} ${'flavors_count'.tr}',
          onEdit: () async {
            final newName = await _promptForNameOnly(
              title: 'edit_type'.tr,
              initialName: t.name,
              accentColor: _Lux.amber,
            );
            if (newName != null && newName.isNotEmpty) {
              t.name = newName;
              _refreshData();
            }
          },
          onDelete: () async {
            await _confirmDeleteType(sub, t, cat);
          },
        );
      },
      extraActions: shouldShowAddFlavor
          ? [
        _buildExtraActionChip(
          label: 'add_flavor_short'.tr,
          icon: Icons.local_drink_rounded,
          color: _Lux.teal,
          onTap: () => _showAddFlavorDialog(type),
        ),
      ]
          : [],
    );
  }



  Widget _buildLevelFourBar(SubCategory type, CustomCategory cat) {
    final flavors = type.flavors ?? [];

    return _buildBarWithFixedLabel(
      labelRx: levelFourLabel,
      labelVisible: levelFourLabelVisible,
      color: _Lux.teal,
      items: flavors.map((f) => f.name).toList(),
      selectedValue: selectedFlavor,
      onTapItem: (name) {
        selectedFlavor.value = name;
        selectedSubType.value = 'all';
      },
      onAddTap: () => _showAddFlavorDialog(type),
      prefix: '🍹 ',
      onLongPressItem: (name) {
        final flavor = flavors.firstWhereOrNull((f) => f.name == name);
        if (flavor == null) return;
        _showItemOptionsDialog(
          itemName: flavor.name,
          accentColor: _Lux.teal,
          extraInfo: 'flavor'.tr,
          onEdit: () async {
            final newName = await _promptForNameOnly(
              title: 'edit_flavor'.tr,
              initialName: flavor.name,
              accentColor: _Lux.teal,
            );
            if (newName != null && newName.isNotEmpty) {
              flavor.name = newName;
              _refreshData();
            }
          },
          onDelete: () async {
            await _confirmDeleteFlavor(
              item: type,
              flavor: flavor,
              sub: type,
            );
          },
        );
      },
      extraActions: [
        Obx(() {
          final isBarActive = showLevelFiveBar.value;
          return _buildExtraActionChip(
            label: isBarActive ? 'hide_subtype'.tr : 'subtype'.tr,
            icon: isBarActive
                ? Icons.visibility_off_rounded
                : Icons.add_business_rounded,
            color: _Lux.violet,
            onTap: () => showLevelFiveBar.toggle(),
          );
        }),
      ],
    );
  }

  Widget _buildLevelFiveBar(SubCategory type, CustomCategory cat) {
    final subTypes = type.subCategories ?? [];
    return _buildBarWithFixedLabel(
      labelRx: levelFiveLabel,
      labelVisible: levelFiveLabelVisible,
      color: _Lux.violet,
      items: subTypes.map((st) => st.name).toList(),
      selectedValue: selectedSubType,
      onTapItem: (name) => selectedSubType.value = name,
      onAddTap: () => _showAddSubTypeUnderType(type),
      prefix: '📌 ',
      onLongPressItem: (name) {
        final subType = subTypes.firstWhereOrNull((st) => st.name == name);
        if (subType == null) return;
        _showItemOptionsDialog(
          itemName: subType.name,
          accentColor: _Lux.violet,
          extraInfo: 'sub_type'.tr,
          onEdit: () async {
            final newName = await _promptForNameOnly(
              title: 'edit_sub_type'.tr,
              initialName: subType.name,
              accentColor: _Lux.violet,
            );
            if (newName != null && newName.isNotEmpty) {
              subType.name = newName;
              _refreshData();
            }
          },
          onDelete: () async {
            await _confirmDeleteType(type, subType, cat);
          },
        );
      },
    );
  }

  Widget _buildExtraActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.18), color.withOpacity(0.06)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  📦 المحتوى الرئيسي
  // ═══════════════════════════════════════════════════════════════

  Widget _buildContent() {
    final currency = Hive.box('settings').get('currency', defaultValue: 'SAR');

    if (selectedCategory.value == 'all') {
      return _buildAllCategoriesGrid();
    }

    final cat = _findCategory(selectedCategory.value, cats);
    if (cat == null) return Center(child: Text('category_not_found'.tr));

    if (cat.subCategories.isEmpty) {
      return _buildEmptySubcategoriesState(cat);
    }

    if (selectedSub.value == 'all') {
      return Column(
        children: [
          Expanded(child: _buildAllSubsGrid(cat)),
          _buildPrimaryButton(
            icon: Icons.add_rounded,
            label: 'add_sub_category'.tr,
            onTap: () => _showAddSubCategoryDialog(cat),
          ),
        ],
      );
    }

    final sub = _findSub(cat, selectedSub.value);
    if (sub == null) return Center(child: Text('subcategory_not_found'.tr));

    final addProductUnderSub = _buildAddProductButton(sub.name);

    if (selectedType.value == 'all') {
      if (sub.subCategories == null || sub.subCategories!.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            children: [
              Expanded(child: _buildEmptyTypesState(sub, cat)),
              addProductUnderSub,
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          children: [
            Expanded(child: _buildTypesGrid(sub, cat)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddSubSubCategoryDialog(sub, cat),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('add_type'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Lux.amber,
                    side: BorderSide(
                        color: _Lux.amber.withOpacity(0.5), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            addProductUnderSub,
          ],
        ),
      );
    }

    final type = _findTypeRecursive(sub, selectedType.value);
    if (type == null) return Center(child: Text('type_not_found'.tr));

    if (selectedSubType.value != 'all' && selectedFlavor.value == 'all') {
      final subType = _findTypeRecursive(type, selectedSubType.value);
      if (subType != null) {
        final categoryName = subType.name;
        final addProductUnderSubType = _buildAddProductButton(categoryName);
        final Set<String> categoryNames = {categoryName};
        if (subType.subCategories != null) {
          for (var child in subType.subCategories!) {
            categoryNames.add(child.name);
          }
        }
        final products = pc.products
            .where((p) => categoryNames.contains(p.category))
            .toList();
        return _buildProductGrid(products, addProductUnderSubType, currency);
      }
    }

    final categoryName = type.name;
    final addProductUnderType = _buildAddProductButton(categoryName);

    final Set<String> categoryNames = {type.name};

    if (type.flavors != null) {
      for (var f in type.flavors!) {
        categoryNames.add(f.name);
      }
    }

    if (type.subCategories != null) {
      for (var child in type.subCategories!) {
        categoryNames.add(child.name);
        if (child.flavors != null) {
          for (var f in child.flavors!) {
            categoryNames.add(f.name);
          }
        }
      }
    }

    var displayProducts =
    pc.products.where((p) => categoryNames.contains(p.category)).toList();

    if (selectedFlavor.value != 'all') {
      displayProducts = displayProducts.where((p) {
        return p.name
            .toLowerCase()
            .contains(selectedFlavor.value.toLowerCase()) ||
            p.description
                .toLowerCase()
                .contains(selectedFlavor.value.toLowerCase()) ||
            (p.flavor?.toLowerCase() == selectedFlavor.value.toLowerCase());
      }).toList();
    }

    return _buildProductGrid(
        displayProducts.toSet().toList(), addProductUnderType, currency);
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎯 حالات فارغة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyCategoriesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _Lux.gold.withOpacity(0.15),
                    _Lux.gold.withOpacity(0.04),
                  ],
                ),
                border: Border.all(
                    color: _Lux.gold.withOpacity(0.25), width: 1.5),
              ),
              child: Icon(Icons.folder_open_rounded,
                  size: 58, color: _Lux.gold.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            Text(
              'no_categories_yet'.tr,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _Lux.midnight,
              ),
            ),
            const SizedBox(height: 26),
            _buildPrimaryButton(
              icon: Icons.add_rounded,
              label: 'add_category'.tr,
              onTap: () => _showAddCategoryDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySubcategoriesState(CustomCategory cat) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _Lux.emerald.withOpacity(0.10),
                border: Border.all(
                    color: _Lux.emerald.withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.folder_open_rounded,
                  size: 48, color: _Lux.emerald),
            ),
            const SizedBox(height: 20),
            Text(
              'no_subcategories_yet'.tr,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : _Lux.midnight,
              ),
            ),
            const SizedBox(height: 20),
            _buildPrimaryButton(
              icon: Icons.add_rounded,
              label: 'add_sub_category'.tr,
              onTap: () => _showAddSubCategoryDialog(cat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTypesState(SubCategory sub, CustomCategory cat) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _Lux.amber.withOpacity(0.10),
              border: Border.all(
                  color: _Lux.amber.withOpacity(0.25), width: 1.5),
            ),
            child: const Icon(Icons.category_outlined,
                size: 44, color: _Lux.amber),
          ),
          const SizedBox(height: 16),
          Text(
            'no_types_yet'.tr,
            style: GoogleFonts.cairo(
                fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showAddSubSubCategoryDialog(sub, cat),
            icon: const Icon(Icons.add_rounded),
            label: Text('add_type'.tr),
            style: OutlinedButton.styleFrom(
              foregroundColor: _Lux.amber,
              side: BorderSide(color: _Lux.amber.withOpacity(0.5), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔘 الأزرار الأساسية
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: _Lux.royalGold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _Lux.gold.withOpacity(0.40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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

  Widget _buildAddProductButton(String categoryName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            gradient: _Lux.midnightSky,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _Lux.midnight.withOpacity(0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  Get.to(() => AddProductPage(categoryName: categoryName)),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_shopping_cart_rounded,
                        color: _Lux.goldLight, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${'add_product'.tr} - $categoryName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
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
  //  🎴 شبكات العرض
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAllCategoriesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: cats.length,
      itemBuilder: (context, index) => _buildCategoryCard(cats[index]),
    );
  }

  Widget _buildAllSubsGrid(CustomCategory cat) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: cat.subCategories.length,
      itemBuilder: (context, index) =>
          _buildSubCategoryCard(cat.subCategories[index]),
    );
  }

  Widget _buildTypesGrid(SubCategory sub, CustomCategory cat) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: sub.subCategories!.length,
      itemBuilder: (context, index) =>
          _buildTypeCard(sub.subCategories![index]),
    );
  }

  Widget _buildProductGrid(
      List<Product> products, Widget addButton, dynamic currency) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _Lux.sapphire.withOpacity(0.10),
                        border: Border.all(
                            color: _Lux.sapphire.withOpacity(0.25),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 44, color: _Lux.sapphire),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'no_products'.tr,
                      style: GoogleFonts.cairo(
                          fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
            addButton,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: products.length,
              itemBuilder: (ctx, index) => _buildEditableProductCard(
                products[index],
                currency.toString(),
              ),
            ),
          ),
          addButton,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎴 بطاقات الأقسام والأنواع
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCategoryCard(CustomCategory cat) {
    return _buildLuxCard(
      imagePath: cat.imagePath,
      title: cat.name,
      subtitle:
      '${cat.subCategories.length} ${'sub_categories'.tr}',
      accentColor: _Lux.violet,
      onTap: () {
        selectedCategory.value = cat.name;
        selectedSub.value = 'all';
        selectedType.value = 'all';
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      },
      onLongPress: () => _confirmDeleteCategory(cat),
      onEdit: () => _editCategory(cat),
    );
  }

  Widget _buildSubCategoryCard(SubCategory sub) {
    return _buildLuxCard(
      imagePath: sub.imagePath,
      title: sub.name,
      accentColor: _Lux.emerald,
      onTap: () {
        selectedSub.value = sub.name;
        selectedType.value = 'all';
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      },
      onLongPress: () => _confirmDeleteSub(
        _findCategory(selectedCategory.value, cats)!,
        sub,
      ),
      onEdit: () => _editSubCategory(sub),
    );
  }

  Widget _buildTypeCard(SubCategory type) {
    return _buildLuxCard(
      imagePath: type.imagePath,
      title: type.name,
      accentColor: _Lux.amber,
      onTap: () {
        selectedType.value = type.name;
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      },
      onLongPress: () => _confirmDeleteType(
        _findSub(_findCategory(selectedCategory.value, cats)!,
            selectedSub.value)!,
        type,
        _findCategory(selectedCategory.value, cats)!,
      ),
      onEdit: () => _editType(type),
    );
  }

  Widget _buildLuxCard({
    required String? imagePath,
    required String title,
    String? subtitle,
    required Color accentColor,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required VoidCallback onEdit,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? _Lux.navyCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? accentColor.withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
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
                          top: Radius.circular(18)),
                      child: _buildImageWithPlaceholder(imagePath),
                    ),
                  ),
                  // زر التعديل
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: _Lux.royalGold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _Lux.gold.withOpacity(0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                  // شارة الحذف
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: onLongPress,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _Lux.ruby.withOpacity(0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _Lux.ruby.withOpacity(0.40),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isDark ? Colors.white : _Lux.midnight,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            subtitle,
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎴 بطاقة المنتج
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEditableProductCard(Product p, String currency) {
    return GestureDetector(
      onLongPress: () => _confirmDeleteProduct(p),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? _Lux.navyCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? _Lux.gold.withOpacity(0.10)
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
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
                    child: GestureDetector(
                      onTap: () => _showProductImagesFullScreen(p),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: _buildImageWithPlaceholder(p.imagePath),
                      ),
                    ),
                  ),
                  // زر التعديل
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => Get.to(() => AddProductPage(product: p)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: _Lux.royalGold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _Lux.gold.withOpacity(0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                  // زر الحذف
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: () => _confirmDeleteProduct(p),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _Lux.ruby.withOpacity(0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _Lux.ruby.withOpacity(0.40),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                  // السعر
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: _Lux.royalGold,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _Lux.gold.withOpacity(0.40),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        '$currency${p.price.toStringAsFixed(0)}',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  // النكهة
                  if (p.flavor != null && p.flavor!.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.20)),
                        ),
                        child: Text(
                          '🍹 ${p.flavor}',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isDark ? Colors.white : _Lux.midnight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.description.isNotEmpty
                        ? p.description
                        : 'no_description'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🖼️ معرض الصور
  // ═══════════════════════════════════════════════════════════════

  void _showProductImagesFullScreen(Product product) {
    final images = <String>[
      if (product.imagePath.trim().isNotEmpty) product.imagePath,
      ...product.additionalImages.where(
            (image) => image.trim().isNotEmpty,
      ),
    ];

    if (images.isEmpty) return;

    final pageController = PageController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close'.tr,
      barrierColor: Colors.black.withOpacity(0.58),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _ProductFullScreenGallery(
          images: images,
          pageController: pageController,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ).then((_) {
      pageController.dispose();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔍 دوال مساعدة
  // ═══════════════════════════════════════════════════════════════

  CustomCategory? _findCategory(String name, List<CustomCategory> list) {
    for (var c in list) {
      if (c.name == name) return c;
    }
    return null;
  }

  SubCategory? _findSub(CustomCategory cat, String name) {
    for (var s in cat.subCategories) {
      if (s.name == name) return s;
    }
    return null;
  }

  SubCategory? _findTypeRecursive(SubCategory parent, String name) {
    if (parent.name == name) return parent;
    if (parent.subCategories != null) {
      for (var child in parent.subCategories!) {
        final found = _findTypeRecursive(child, name);
        if (found != null) return found;
      }
    }
    return null;
  }

  Color _getFlavorColor(String name) {
    final colors = [
      _Lux.teal,
      Colors.pink,
      _Lux.amber,
      _Lux.violet,
      Colors.indigo,
      Colors.brown,
      Colors.cyan,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  // ═══════════════════════════════════════════════════════════════
  //  📝 حوارات الإضافة والتعديل
  // ═══════════════════════════════════════════════════════════════

  Future<({String name, String? imagePath})?> _promptForNameWithImage(
      String title, String hint) async {
    final nameCtrl = TextEditingController();
    final imageUrlCtrl = TextEditingController();
    String? selectedImagePath;

    final result =
    await Get.dialog<({String name, String? imagePath})>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _Lux.royalGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.cairo(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: GoogleFonts.cairo(
                          color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: _Lux.gold, width: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlCtrl,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'image_link_optional'.tr,
                      hintStyle: GoogleFonts.cairo(
                          color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedImagePath =
                        v.trim().isEmpty ? null : v.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImageHelper.pickImage();
                      if (picked != null) {
                        setDialogState(() {
                          selectedImagePath = picked;
                          imageUrlCtrl.text = picked;
                        });
                      }
                    },
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _Lux.gold.withOpacity(0.10),
                            _Lux.gold.withOpacity(0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _Lux.gold.withOpacity(0.30),
                          width: 1.5,
                        ),
                      ),
                      child: selectedImagePath != null &&
                          selectedImagePath!.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildImageWithPlaceholder(
                            selectedImagePath),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: _Lux.gold,
                              size: 30),
                          const SizedBox(height: 4),
                          Text(
                            'choose_image_or_link'.tr,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: _Lux.goldDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Get.back(
                  result: (
                  name: nameCtrl.text.trim(),
                  imagePath: selectedImagePath ??
                      (imageUrlCtrl.text.trim().isEmpty
                          ? null
                          : imageUrlCtrl.text.trim()),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _Lux.midnight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('save'.tr,
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result;
  }

  Future<String?> _promptForName(String title, String hint) async {
    final controller = TextEditingController();
    return await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _Lux.royalGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.cairo(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.cairo(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Lux.gold, width: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Lux.midnight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('save'.tr,
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await _promptForNameWithImage(
        'add_category'.tr, 'category_name_hint'.tr);
    if (result != null && result.name.isNotEmpty) {
      final newCat = CustomCategory(
        name: result.name,
        imagePath: result.imagePath,
        subCategories: [],
      );
      cats.add(newCat);
      selectedCategory.value = newCat.name;
      selectedSub.value = 'all';
      selectedType.value = 'all';
      selectedFlavor.value = 'all';
      selectedSubType.value = 'all';
      _refreshData();
    }
  }

  Future<void> _showAddSubCategoryDialog(CustomCategory cat) async {
    final result = await _promptForNameWithImage(
        'add_sub_category'.tr, 'sub_category_hint'.tr);
    if (result != null && result.name.isNotEmpty) {
      final newSub = SubCategory(
        name: result.name,
        imagePath: result.imagePath,
        subCategories: [],
      );
      cat.subCategories.add(newSub);
      selectedSub.value = newSub.name;
      selectedType.value = 'all';
      selectedFlavor.value = 'all';
      selectedSubType.value = 'all';
      _refreshData();
    }
  }

  Future<void> _showAddSubSubCategoryDialog(
      SubCategory parentSub, CustomCategory cat) async {
    final result = await _promptForNameWithImage(
        'add_type'.tr, 'type_name_hint'.tr);
    if (result != null && result.name.isNotEmpty) {
      parentSub.subCategories ??= [];
      final newType = SubCategory(
        name: result.name,
        imagePath: result.imagePath,
        subCategories: [],
      );
      parentSub.subCategories!.add(newType);
      selectedType.value = newType.name;
      selectedFlavor.value = 'all';
      selectedSubType.value = 'all';
      _refreshData();
    }
  }

  Future<void> _showAddSubTypeUnderType(SubCategory parentType) async {
    final name =
    await _promptForName('add_sub_type'.tr, 'sub_type_name_hint'.tr);
    if (name != null && name.isNotEmpty) {
      parentType.subCategories ??= [];
      parentType.subCategories!
          .add(SubCategory(name: name, subCategories: []));
      _refreshData();
    }
  }

  Future<void> _showAddFlavorDialog(SubCategory item) async {
    final name = await _promptForName('add_flavor'.tr, 'flavor_name_hint'.tr);
    if (name != null && name.isNotEmpty) {
      item.flavors ??= [];
      item.flavors!.add(Flavor(name: name));
      selectedFlavor.value = name;
      selectedSubType.value = 'all';
      _refreshData();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ✏️ دوال التعديل
  // ═══════════════════════════════════════════════════════════════

  Future<void> _editCategory(CustomCategory cat) async {
    final result = await _showEditDialog(
      title: 'edit_category'.tr,
      initialName: cat.name,
      initialImagePath: cat.imagePath,
    );
    if (result != null) {
      cat.name = result.name;
      cat.imagePath = result.imagePath;
      _refreshData();
    }
  }

  Future<void> _editSubCategory(SubCategory sub) async {
    final result = await _showEditDialog(
      title: 'edit_subcategory'.tr,
      initialName: sub.name,
      initialImagePath: sub.imagePath,
    );
    if (result != null) {
      sub.name = result.name;
      sub.imagePath = result.imagePath;
      _refreshData();
    }
  }

  Future<void> _editType(SubCategory type) async {
    final result = await _showEditDialog(
      title: 'edit_type'.tr,
      initialName: type.name,
      initialImagePath: type.imagePath,
    );
    if (result != null) {
      type.name = result.name;
      type.imagePath = result.imagePath;
      _refreshData();
    }
  }

  Future<({String name, String? imagePath})?> _showEditDialog({
    required String title,
    required String initialName,
    String? initialImagePath,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final imageUrlCtrl = TextEditingController(text: initialImagePath ?? '');
    String? selectedImagePath = initialImagePath;

    final result = await showDialog<({String name, String? imagePath})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.cairo(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'name'.tr,
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: _Lux.gold, width: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlCtrl,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'image_link'.tr,
                      labelStyle: GoogleFonts.cairo(),
                      hintText: 'https://example.com/image.jpg',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedImagePath =
                        value.trim().isEmpty ? null : value.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImageHelper.pickImage();
                      if (picked != null) {
                        setDialogState(() {
                          selectedImagePath = picked;
                          imageUrlCtrl.text = picked;
                        });
                      }
                    },
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _Lux.gold.withOpacity(0.10),
                            _Lux.gold.withOpacity(0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _Lux.gold.withOpacity(0.30),
                          width: 1.5,
                        ),
                      ),
                      child: selectedImagePath != null &&
                          selectedImagePath!.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildImageWithPlaceholder(
                            selectedImagePath),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: _Lux.gold,
                              size: 30),
                          const SizedBox(height: 4),
                          Text(
                            'choose_image_or_link'.tr,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: _Lux.goldDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cancel'.tr,
                    style: GoogleFonts.cairo(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    Navigator.pop(
                      ctx,
                      (
                      name: nameCtrl.text.trim(),
                      imagePath: selectedImagePath,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Lux.midnight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('save'.tr,
                    style: GoogleFonts.cairo(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
    return result;
  }

  void _refreshData() {
    cats.refresh();
    _saveCategories();
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════
  //  🗑️ دوال الحذف
  // ═══════════════════════════════════════════════════════════════

  Future<bool> _confirmDelete(String title, String itemName) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _Lux.ruby.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _Lux.ruby, size: 20),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '${'confirm_delete'.tr} $itemName؟',
          style: GoogleFonts.cairo(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Lux.ruby,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('delete'.tr,
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmDeleteCategory(CustomCategory cat) async {
    if (await _confirmDelete('delete_category'.tr, cat.name)) {
      cats.removeWhere((c) => c.name == cat.name);
      if (selectedCategory.value == cat.name) {
        selectedCategory.value = 'all';
        selectedSub.value = 'all';
        selectedType.value = 'all';
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      }
      _refreshData();
    }
  }

  Future<void> _confirmDeleteSub(CustomCategory cat, SubCategory sub) async {
    if (await _confirmDelete('delete_subcategory'.tr, sub.name)) {
      cat.subCategories.removeWhere((s) => s.name == sub.name);
      if (selectedSub.value == sub.name) {
        selectedSub.value = 'all';
        selectedType.value = 'all';
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      }
      _refreshData();
    }
  }

  Future<void> _confirmDeleteType(
      SubCategory parent, SubCategory type, CustomCategory cat) async {
    if (await _confirmDelete('delete_type'.tr, type.name)) {
      parent.subCategories?.removeWhere((t) => t.name == type.name);
      if (selectedType.value == type.name) {
        selectedType.value = 'all';
        selectedFlavor.value = 'all';
        selectedSubType.value = 'all';
      }
      _refreshData();
    }
  }

  Future<void> _confirmDeleteFlavor({
    required SubCategory item,
    required Flavor flavor,
    required SubCategory sub,
  }) async {
    if (await _confirmDelete('delete_flavor'.tr, flavor.name)) {
      item.flavors?.removeWhere((f) => f.name == flavor.name);
      if (selectedFlavor.value == flavor.name) {
        selectedFlavor.value = 'all';
      }
      _refreshData();
    }
  }

  Future<void> _confirmDeleteProduct(Product p) async {
    if (await _confirmDelete('delete_product'.tr, p.name)) {
      pc.products.removeWhere((prod) => prod.id == p.id);
      pc.products.refresh();
      setState(() {});
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  🖼️ أدوات الصور
  // ═══════════════════════════════════════════════════════════════

  Widget _buildImageWithPlaceholder(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return _buildImagePlaceholder();
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: 800,
        key: ValueKey(imagePath),
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildImagePlaceholder();
        },
      );
    }

    if (imagePath.startsWith('data:image')) {
      try {
        final base64Data = imagePath.split(',').last;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          key: ValueKey(imagePath),
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        );
      } catch (_) {
        return _buildImagePlaceholder();
      }
    }

    if (!kIsWeb) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          key: ValueKey(imagePath),
        );
      }
    }

    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _Lux.gold.withOpacity(0.10),
            _Lux.gold.withOpacity(0.03),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_rounded,
          color: _Lux.gold.withOpacity(0.6),
          size: 30,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ArrowTabClipper
// ═══════════════════════════════════════════════════════════════
class ArrowTabClipper extends CustomClipper<Path> {
  final double cutSize;
  final bool isRTL;

  ArrowTabClipper({this.cutSize = 12.0, this.isRTL = false});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (isRTL) {
      path.moveTo(0, 0);
      path.lineTo(size.width - cutSize, 0);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(size.width - cutSize, size.height);
      path.lineTo(0, size.height);
      path.close();
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(cutSize, size.height);
      path.lineTo(0, size.height / 2);
      path.lineTo(cutSize, 0);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant ArrowTabClipper oldClipper) {
    return oldClipper.cutSize != cutSize || oldClipper.isRTL != isRTL;
  }
}

// ═══════════════════════════════════════════════════════════════
//  Product Full Screen Gallery
// ═══════════════════════════════════════════════════════════════
class _ProductFullScreenGallery extends StatefulWidget {
  final List<String> images;
  final PageController pageController;

  const _ProductFullScreenGallery({
    required this.images,
    required this.pageController,
  });

  @override
  State<_ProductFullScreenGallery> createState() =>
      _ProductFullScreenGalleryState();
}

class _ProductFullScreenGalleryState
    extends State<_ProductFullScreenGallery> {
  late int currentIndex;
  final Map<int, TransformationController> _transformControllers = {};

  @override
  void initState() {
    super.initState();
    currentIndex = 0;
  }

  @override
  void dispose() {
    for (final controller in _transformControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _controllerFor(int index) {
    return _transformControllers.putIfAbsent(
      index,
          () => TransformationController(),
    );
  }

  void _resetZoom(int index) {
    final controller = _transformControllers[index];
    if (controller == null) return;
    controller.value = Matrix4.identity();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.images.length) return;
    widget.pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return Material(
      color: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Colors.transparent),
                ),
              ),

              Positioned.fill(
                child: PageView.builder(
                  controller: widget.pageController,
                  itemCount: images.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    _resetZoom(currentIndex);
                    setState(() => currentIndex = index);
                  },
                  itemBuilder: (context, index) =>
                      _buildImagePage(context, images[index], index),
                ),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 145,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.40),
                          Colors.black.withOpacity(0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 210,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.48),
                          Colors.black.withOpacity(0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    _galleryIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.13)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded,
                              color: _Lux.gold, size: 15),
                          const SizedBox(width: 7),
                          Text(
                            '${currentIndex + 1} / ${images.length}',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (images.length > 1 && currentIndex > 0)
                Positioned(
                  left: 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _galleryNavigationButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _goTo(currentIndex - 1),
                    ),
                  ),
                ),

              if (images.length > 1 && currentIndex < images.length - 1)
                Positioned(
                  right: 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _galleryNavigationButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _goTo(currentIndex + 1),
                    ),
                  ),
                ),

              if (images.length > 1)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 22,
                  child: SizedBox(
                    height: 68,
                    child: Center(
                      child: ListView.separated(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final selected = index == currentIndex;
                          return GestureDetector(
                            onTap: () => _goTo(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: selected ? 72 : 62,
                              height: selected ? 68 : 58,
                              padding:
                              EdgeInsets.all(selected ? 2.5 : 1.5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: selected
                                      ? _Lux.gold
                                      : Colors.white.withOpacity(0.18),
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                  BoxShadow(
                                    color: _Lux.gold.withOpacity(0.28),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ImageHelper.displayImage(
                                  imagePath: images[index],
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    color: _Lux.navyCard,
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              if (images.length > 1)
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (index) {
                      final selected = index == currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: selected ? 18 : 5,
                        height: 4,
                        decoration: BoxDecoration(
                          color: selected
                              ? _Lux.gold
                              : Colors.white.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePage(
      BuildContext context, String imagePath, int index) {
    final controller = _controllerFor(index);

    return Center(
      child: InteractiveViewer(
        transformationController: controller,
        minScale: 1.0,
        maxScale: 5.0,
        panEnabled: true,
        scaleEnabled: true,
        boundaryMargin: const EdgeInsets.all(80),
        clipBehavior: Clip.none,
        child: Hero(
          tag: 'product-fullscreen-$index-$imagePath',
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.94,
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.48),
                  blurRadius: 35,
                  spreadRadius: 4,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ImageHelper.displayImage(
              imagePath: imagePath,
              fit: BoxFit.contain,
              placeholder: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_Lux.gold),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _galleryIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.38),
            borderRadius: BorderRadius.circular(15),
            border:
            Border.all(color: Colors.white.withOpacity(0.13)),
          ),
          child: Icon(icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }

  Widget _galleryNavigationButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 74,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.30),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}