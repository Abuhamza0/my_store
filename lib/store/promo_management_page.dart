// promo_management_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../core/services/store_id_service.dart';
import 'promo_cloud_service.dart';
import 'promo_item_model.dart';

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

class PromoManagementPage extends StatefulWidget {
  const PromoManagementPage({super.key});

  @override
  State<PromoManagementPage> createState() => _PromoManagementPageState();
}

class _PromoManagementPageState extends State<PromoManagementPage> {
  final _box = Hive.box('settings');
  final RxList<PromoItem> _items = <PromoItem>[].obs;
  final RxBool _isLoading = false.obs;
  bool _hasChanges = false;

  static const String _storageKey = 'custom_promo_items';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    _isLoading.value = true;
    try {
      // ═══ 1) قراءة من السحابة ═══
      final cloudItems = await PromoCloudService.fetchGlobalPromos(
        forceRefresh: true,
      );

      if (cloudItems != null && cloudItems.isNotEmpty) {
        _items.assignAll(cloudItems);
        print('✅ Loaded from cloud: ${cloudItems.length}');
      } else {
        // ═══ 2) إذا لا توجد في السحابة، نحمّل من Hive المحلي (كمسودة) ═══
        final saved = _box.get(_storageKey, defaultValue: <Map>[]);
        if (saved is List && saved.isNotEmpty) {
          final list = saved
              .map((j) => PromoItem.fromMap(Map<String, dynamic>.from(j)))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          _items.assignAll(list);
        }

        // ═══ 3) إذا لا شيء، نضع الافتراضية ═══
        if (_items.isEmpty) {
          _items.assignAll(_defaultPromos());
          await _saveToHive(silent: true);
        }
      }
    } catch (e) {
      print('❌ Load error: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  // ═══ البطاقات الافتراضية ═══
  List<PromoItem> _defaultPromos() {
    return [
      PromoItem(
        id: 'promo_1',
        title: 'عروض حصرية',
        subtitle: 'ارتقِ بمتجرك للاحتراف',
        badge: '⭐',
        icon: Icons.workspace_premium_rounded,
        colorValue: 0xFF9A7B1F,
        color2Value: const Color(0xFF6B5214),
        actionType: 'subscription',
        order: 0,
      ),
      PromoItem(
        id: 'promo_2',
        title: 'أضف منتجاتك',
        subtitle: 'إدارة ذكية للمخزون',
        badge: '🆕',
        icon: Icons.add_box_rounded,
        colorValue: 0xFF065F46,
        color2Value: const Color(0xFF064E3B),
        actionType: 'add_product',
        order: 1,
      ),
      PromoItem(
        id: 'promo_3',
        title: 'تقارير المبيعات',
        subtitle: 'تابع أرباحك لحظياً',
        badge: '📊',
        icon: Icons.insights_rounded,
        colorValue: 0xFF3730A3,
        color2Value: const Color(0xFF1E1B4B),
        actionType: 'sales',
        order: 2,
      ),
      PromoItem(
        id: 'promo_4',
        title: 'إدارة العملاء',
        subtitle: 'علاقات دائمة مع زبائنك',
        badge: '💎',
        icon: Icons.groups_rounded,
        colorValue: 0xFF831843,
        color2Value: const Color(0xFF4C0519),
        actionType: 'customers',
        order: 3,
      ),
    ];
  }

  Future<void> _saveToHive({bool silent = false}) async {
    try {
      // إعادة ترقيم
      for (int i = 0; i < _items.length; i++) {
        _items[i].order = i;
      }

      // ═══ 1) حفظ محلي في Hive (مسودة) ═══
      await _box.put(
        _storageKey,
        _items.map((e) => e.toMap()).toList(),
      );

      // ═══ 2) نشر إلى السحابة (عامة لجميع المستخدمين) ═══
      final uploaded = await PromoCloudService.uploadGlobalPromos(
        _items.toList(),
      );

      if (!uploaded) {
        if (!silent) {
          Get.snackbar(
            '⚠️ تحذير',
            'تم الحفظ محلياً، لكن فشل النشر للسحابة',
            snackPosition: SnackPosition.BOTTOM,

            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

      _hasChanges = false;
      if (!silent) {
        Get.snackbar(
          '✅ تم النشر',
          'البطاقات متاحة الآن لجميع المستخدمين',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _Lux.emerald,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('❌ Save error: $e');
      if (!silent) {
        Get.snackbar(
          'خطأ',
          'فشل الحفظ: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _Lux.ruby,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _addNewItem() async {
    final result = await _showEditDialog(null);
    if (result != null) {
      setState(() {
        _items.add(result);
        _hasChanges = true;
      });
      await _saveToHive();
    }
  }

  Future<void> _editItem(PromoItem item) async {
    final result = await _showEditDialog(item);
    if (result != null) {
      final index = _items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        setState(() {
          _items[index] = result;
          _hasChanges = true;
        });
        await _saveToHive();
      }
    }
  }

  Future<void> _deleteItem(PromoItem item) async {
    final confirmed = await Get.dialog<bool>(
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
            Text('تأكيد الحذف',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('هل تريد حذف "${item.title}"؟',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: _Lux.ruby),
            child: Text('حذف',
                style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _items.removeWhere((i) => i.id == item.id);
        _hasChanges = true;
      });
      await _saveToHive();
    }
  }

  Future<void> _toggleActive(PromoItem item) async {
    setState(() {
      item.isActive = !item.isActive;
      _hasChanges = true;
    });
    await _saveToHive(silent: true);
  }

  // ═══════════════════════════════════════════════════════════
  //  📝 حوار الإضافة / التعديل
  // ═══════════════════════════════════════════════════════════

  Future<PromoItem?> _showEditDialog(PromoItem? existing) async {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final badgeCtrl = TextEditingController(text: existing?.badge ?? '');
    final actionValueCtrl =
    TextEditingController(text: existing?.actionValue ?? '');

    IconData selectedIcon = existing?.icon ?? PromoItem.availableIcons.first;
    int selectedGradientIndex = existing != null
        ? PromoItem.availableGradients.indexWhere(
            (g) => g.first.value == existing.colorValue)
        : 0;
    if (selectedGradientIndex < 0) selectedGradientIndex = 0;

    String selectedAction = existing?.actionType ?? 'none';

    final result = await Get.dialog<PromoItem>(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: _Lux.royalGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEdit ? 'تعديل البطاقة' : 'بطاقة جديدة',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // العنوان
                    _fieldLabel('العنوان'),
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: _inputDecoration('مثال: عروض حصرية'),
                    ),
                    const SizedBox(height: 12),

                    // الوصف
                    _fieldLabel('الوصف'),
                    TextField(
                      controller: subtitleCtrl,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: _inputDecoration('مثال: ارتقِ بمتجرك'),
                    ),
                    const SizedBox(height: 12),

                    // الشارة (اختياري)
                    _fieldLabel('الشارة (اختياري)'),
                    TextField(
                      controller: badgeCtrl,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration:
                      _inputDecoration('مثال: ⭐ أو 🆕 أو خصم 50%'),
                    ),
                    const SizedBox(height: 16),

                    // الأيقونة
                    _fieldLabel('الأيقونة'),
                    const SizedBox(height: 8),
                    _buildIconPicker(
                      selectedIcon,
                          (icon) => setDialogState(() => selectedIcon = icon),
                    ),
                    const SizedBox(height: 16),

                    // اللون
                    _fieldLabel('اللون'),
                    const SizedBox(height: 8),
                    _buildGradientPicker(
                      selectedGradientIndex,
                          (index) => setDialogState(
                              () => selectedGradientIndex = index),
                    ),
                    const SizedBox(height: 16),

                    // نوع الإجراء
                    _fieldLabel('عند الضغط'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedAction,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          borderRadius: BorderRadius.circular(12),
                          items: PromoItem.actionTypes.map((a) {
                            return DropdownMenuItem<String>(
                              value: a['value'],
                              child: Text(a['label']!,
                                  style: GoogleFonts.cairo(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedAction = v);
                            }
                          },
                        ),
                      ),
                    ),
                    if (selectedAction == 'url') ...[
                      const SizedBox(height: 12),
                      _fieldLabel('الرابط'),
                      TextField(
                        controller: actionValueCtrl,
                        style: GoogleFonts.cairo(fontSize: 13),
                        decoration:
                        _inputDecoration('https://example.com'),
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  if (subtitleCtrl.text.trim().isEmpty) return;

                  final gradient =
                  PromoItem.availableGradients[selectedGradientIndex];

                  final item = PromoItem(
                    id: existing?.id ??
                        'promo_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleCtrl.text.trim(),
                    subtitle: subtitleCtrl.text.trim(),
                    badge: badgeCtrl.text.trim().isEmpty
                        ? null
                        : badgeCtrl.text.trim(),
                    icon: selectedIcon,
                    colorValue: gradient.first.value,
                    color2Value: gradient.last,
                    actionType: selectedAction,
                    actionValue: actionValueCtrl.text.trim().isEmpty
                        ? null
                        : actionValueCtrl.text.trim(),
                    isActive: existing?.isActive ?? true,
                    order: existing?.order ?? _items.length,
                  );
                  Get.back(result: item);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Lux.midnight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 11),
                ),
                child: Text('حفظ',
                    style: GoogleFonts.cairo(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _Lux.midnight,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.cairo(
          color: Colors.grey.shade400, fontSize: 12),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _Lux.gold, width: 1.6),
      ),
    );
  }

  Widget _buildIconPicker(IconData selected, ValueChanged<IconData> onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PromoItem.availableIcons.map((icon) {
        final isSelected = icon.codePoint == selected.codePoint;
        return GestureDetector(
          onTap: () => onSelect(icon),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isSelected ? _Lux.royalGold : null,
              color: isSelected ? null : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? _Lux.goldDeep
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : _Lux.midnight,
              size: 20,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGradientPicker(int selected, ValueChanged<int> onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
      List.generate(PromoItem.availableGradients.length, (index) {
        final gradient = PromoItem.availableGradients[index];
        final isSelected = index == selected;
        return GestureDetector(
          onTap: () => onSelect(index),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _Lux.gold : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: _Lux.gold.withOpacity(0.4),
                  blurRadius: 10,
                ),
              ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded,
                color: Colors.white, size: 22)
                : null,
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🏗️ البناء الرئيسي
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _Lux.bgDark : _Lux.bgLight,
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: Obx(() {
              if (_isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: _Lux.gold),
                );
              }

              if (_items.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                    _hasChanges = true;
                  });
                  _saveToHive(silent: true);
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildPromoItemTile(item, index, isDark);
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _Lux.gold.withOpacity(0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _addNewItem,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          label: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: _Lux.royalGold,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('بطاقة جديدة',
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
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
        ],
        border: Border(
          bottom: BorderSide(color: _Lux.gold.withOpacity(0.22), width: 1),
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.back(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 17),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
            child: const Icon(Icons.campaign_rounded,
                color: Colors.white, size: 22),
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
                    'إدارة البطاقات الدعائية',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Obx(() => Text(
                  '${_items.length} بطاقة',
                  style: GoogleFonts.cairo(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                )),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // زر النشر اليدوي
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading.value
                      ? null
                      : () async {
                    setState(() => _isLoading.value = true);
                    final cloudItems =
                    await PromoCloudService.fetchGlobalPromos(
                      forceRefresh: true,
                    );
                    if (cloudItems != null) {
                      _items.assignAll(cloudItems);
                      Get.snackbar(
                        'تم التحديث',
                        'تم جلب ${cloudItems.length} بطاقة من السحابة',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: _Lux.sapphire,
                        colorText: Colors.white,
                      );
                    }
                    setState(() => _isLoading.value = false);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_download_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading.value
                      ? null
                      : () async {
                    setState(() => _isLoading.value = true);
                    await _saveToHive();
                    setState(() => _isLoading.value = false);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: _Lux.royalGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          'نشر للجميع',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // وقت آخر مزامنة
              // استبدل Obx بـ FutureBuilder أو استخدم ValueListenableBuilder أو
// ببساطة اجعلها widget عادي (بدون Obx) لأنها لا تحتاج تفاعل
              Builder(
                builder: (context) {
                  final last = PromoCloudService.getLastSyncTime();
                  if (last == null) return const SizedBox.shrink();
                  final diff = DateTime.now().difference(last);
                  String text;
                  if (diff.inMinutes < 1) {
                    text = 'الآن';
                  } else if (diff.inMinutes < 60) {
                    text = 'قبل ${diff.inMinutes} د';
                  } else if (diff.inHours < 24) {
                    text = 'قبل ${diff.inHours} س';
                  } else {
                    text = 'قبل ${diff.inDays} ي';
                  }
                  return Text(
                    'آخر نشر: $text',
                    style: GoogleFonts.cairo(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoItemTile(PromoItem item, int index, bool isDark) {
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(item.colorValue),
        item.color2Value,
      ],
    );

    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editItem(item),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? _Lux.navyCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: item.isActive
                    ? Color(item.colorValue).withOpacity(0.30)
                    : Colors.grey.withOpacity(0.20),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // أيقونة السحب
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      width: 32,
                      height: 60,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: Colors.grey.shade400,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // معاينة البطاقة
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Color(item.colorValue).withOpacity(0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),

                  // النصوص
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.badge != null &&
                                item.badge!.isNotEmpty) ...[
                              Text(item.badge!,
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color:
                                  isDark ? Colors.white : _Lux.midnight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isActive
                                    ? _Lux.emerald.withOpacity(0.15)
                                    : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.isActive ? 'نشط' : 'معطّل',
                                style: GoogleFonts.cairo(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: item.isActive
                                      ? _Lux.emerald
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _actionLabel(item.actionType),
                              style: GoogleFonts.cairo(
                                fontSize: 9.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // الأزرار
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniButton(
                        icon: item.isActive
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: item.isActive ? _Lux.emerald : Colors.grey,
                        onTap: () => _toggleActive(item),
                      ),
                      const SizedBox(height: 6),
                      _miniButton(
                        icon: Icons.delete_outline_rounded,
                        color: _Lux.ruby,
                        onTap: () => _deleteItem(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25), width: 0.8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'subscription':
        return '→ الاشتراك';
      case 'add_product':
        return '→ إضافة منتج';
      case 'sales':
        return '→ المبيعات';
      case 'customers':
        return '→ العملاء';
      case 'orders':
        return '→ الطلبات';
      case 'url':
        return '→ رابط خارجي';
      default:
        return '→ بدون إجراء';
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
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
              child: Icon(Icons.campaign_rounded,
                  size: 55, color: _Lux.gold.withOpacity(0.7)),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد بطاقات دعائية',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : _Lux.midnight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على زر "بطاقة جديدة" لإضافة أول بطاقة',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}