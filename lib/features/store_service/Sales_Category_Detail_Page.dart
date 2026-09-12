// sales_category_detail_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'Premium_Cart_Sheet.dart';
import 'Premium_Product_Expanded_View.dart';
import 'customer_model.dart';
import 'order_controller.dart';
import 'product_model.dart';
import 'product_controller.dart';
import 'order_model.dart';
import 'custom_category_model.dart';
import 'store_header_with_cart.dart';
import 'package:mystore/utils/image_helper.dart';

class SalesCategoryDetailPage extends StatelessWidget {
  final CustomCategory category;
  final RxList<OrderItem> cart;
  final RxDouble total;
  final Customer? loggedInCustomer;
  final VoidCallback? onCartTap;

  const SalesCategoryDetailPage({
    super.key,
    required this.category,
    required this.cart,
    required this.total,
    this.loggedInCustomer,
    this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<ProductController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = Hive.box('settings').get('currency', defaultValue: 'SAR');

    final selectedSub = 'all'.obs;
    final selectedShape = 'all'.obs;
    final selectedFlavor = 'all'.obs;
    final selectedSubType = 'all'.obs;
    final selectedSubFlavor = 'all'.obs;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(category.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A2332),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Obx(() {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => _showPremiumCartSheet(cart, total, currency, context),
                  icon: const Icon(Icons.shopping_cart_rounded, color: Color(0xFFD4AF37)),
                  tooltip: 'cart'.tr,
                ),
                if (cart.isNotEmpty)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${cart.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Obx(() => cart.isEmpty
              ? const SizedBox.shrink()
              : _buildMiniCartBar(cart, total, currency, isDark, context)),

          if (loggedInCustomer != null)
            StoreHeaderWithCart(
              loggedInCustomer: loggedInCustomer!,
              cart: cart, total: total,
              onCartTap: onCartTap ?? () {},
            ),

          if (category.subCategories.isNotEmpty)
            _buildLevelOneBar(
              category,
              selectedSub,
              selectedShape,
              selectedFlavor,
              selectedSubType,
              selectedSubFlavor,
              isDark,
            ),

          Obx(() {
            if (selectedSub.value != 'all') {
              final sub = _findSub(selectedSub.value);
              if (sub != null && sub.subCategories != null && sub.subCategories!.isNotEmpty) {
                return _buildLevelTwoBar(
                  sub,
                  selectedShape,
                  selectedFlavor,
                  selectedSubType,
                  selectedSubFlavor,
                  isDark,
                );
              }
            }
            return const SizedBox.shrink();
          }),

          Obx(() {
            if (selectedShape.value != 'all') {
              final sub = _findSub(selectedSub.value);
              if (sub != null) {
                final shape = _findShape(sub, selectedShape.value);
                if (shape != null && shape.flavors != null && shape.flavors!.isNotEmpty) {
                  return _buildLevelThreeBar(shape, selectedFlavor, isDark);
                }
              }
            }
            return const SizedBox.shrink();
          }),

          Obx(() {
            if (selectedShape.value == 'all') return const SizedBox.shrink();
            final sub = _findSub(selectedSub.value);
            if (sub == null) return const SizedBox.shrink();
            final shape = _findShape(sub, selectedShape.value);
            if (shape == null || shape.subCategories == null || shape.subCategories!.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildLevelFourBar(shape, selectedSubType, selectedSubFlavor, isDark);
          }),

          Obx(() {
            if (selectedSubType.value == 'all') return const SizedBox.shrink();
            final sub = _findSub(selectedSub.value);
            if (sub == null) return const SizedBox.shrink();
            final shape = _findShape(sub, selectedShape.value);
            if (shape == null) return const SizedBox.shrink();
            final subType = _findSubType(shape, selectedSubType.value);
            if (subType == null || subType.flavors == null || subType.flavors!.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildLevelFiveBar(subType, selectedSubFlavor, isDark);
          }),

          Expanded(
            child: Obx(() {
              return _buildContent(
                pc, cart, total, isDark, currency,
                selectedSub, selectedShape, selectedFlavor,
                selectedSubType, selectedSubFlavor, context,
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showPremiumCartSheet(RxList<OrderItem> cart, RxDouble total, String currency, BuildContext context) {
    OrderController? orderController;
    if (Get.isRegistered<OrderController>()) {
      orderController = Get.find<OrderController>();
    } else {
      orderController = OrderController();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PremiumCartSheet(
          cart: cart,
          total: total,
          oc: orderController!,
          loggedInCustomer: loggedInCustomer,
          currency: currency,
          uploadOrder: (order) async {
            // Upload order logic
          },
        );
      },
    );
  }

  Widget _buildMiniCartBar(RxList<OrderItem> cart, RxDouble total, String currency, bool isDark, BuildContext context) {
    return GestureDetector(
      onTap: () => _showPremiumCartSheet(cart, total, currency, context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2332), Color(0xFF2D3A4E)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A2332).withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
              ),
              child: const Icon(
                Icons.shopping_cart_rounded,
                color: Color(0xFFD4AF37),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${cart.length} ${cart.length == 1 ? 'item'.tr : 'items'.tr} ${'in_cart'.tr}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '$currency${total.value.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFD4AF37),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelOneBar(
      CustomCategory cat,
      RxString selectedSub,
      RxString selectedShape,
      RxString selectedFlavor,
      RxString selectedSubType,
      RxString selectedSubFlavor,
      bool isDark,
      ) {
    final colors = [const Color(0xFF667eea), const Color(0xFF764ba2), const Color(0xFFf093fb), const Color(0xFFf5576c)];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cat.subCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Obx(() {
              final selected = selectedSub.value == 'all';
              return _buildCategoryChip(
                title: 'all'.tr,
                icon: Icons.grid_view_rounded,
                color: const Color(0xFF667EEA),
                selected: selected,
                onTap: () {
                  selectedSub.value = 'all';
                  selectedShape.value = 'all';
                  selectedFlavor.value = 'all';
                  selectedSubType.value = 'all';
                  selectedSubFlavor.value = 'all';
                },
              );
            });
          }

          final sub = cat.subCategories[index - 1];
          final color = colors[index % colors.length];

          return Obx(() {
            return _buildCategoryChip(
              title: sub.name,
              icon: Icons.category_rounded,
              color: color,
              selected: selectedSub.value == sub.name,
              onTap: () {
                selectedSub.value = sub.name;
                selectedShape.value = 'all';
                selectedFlavor.value = 'all';
                selectedSubType.value = 'all';
                selectedSubFlavor.value = 'all';
              },
            );
          });
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required String title,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minWidth: 95, maxWidth: 240),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [color, color.withOpacity(0.72)])
              : null,
          color: selected ? null : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 5))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.18) : color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: selected ? Colors.white : color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF263247),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelTwoBar(
      SubCategory sub,
      RxString selectedShape,
      RxString selectedFlavor,
      RxString selectedSubType,
      RxString selectedSubFlavor,
      bool isDark,
      ) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.04),
        border: Border(
          top: BorderSide(color: const Color(0xFF667eea).withOpacity(0.15)),
          bottom: BorderSide(color: const Color(0xFF667eea).withOpacity(0.15)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: sub.subCategories!.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Obx(() {
              final isSelected = selectedShape.value == 'all';
              return GestureDetector(
                onTap: () {
                  selectedShape.value = 'all';
                  selectedFlavor.value = 'all';
                  selectedSubType.value = 'all';
                  selectedSubFlavor.value = 'all';
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF667eea) : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade400, width: 1.5),
                  ),
                  child: Text('🎨 ${'all'.tr}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF667eea), fontWeight: FontWeight.w600, fontSize: 11)),
                ),
              );
            });
          }
          final shape = sub.subCategories![index - 1];
          return Obx(() {
            final isSelected = selectedShape.value == shape.name;
            return GestureDetector(
              onTap: () {
                selectedShape.value = shape.name;
                selectedFlavor.value = 'all';
                selectedSubType.value = 'all';
                selectedSubFlavor.value = 'all';
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF667eea) : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade400, width: 1.5),
                ),
                child: Text('📐 ${shape.name}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF667eea), fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildLevelThreeBar(SubCategory shape, RxString selectedFlavor, bool isDark) {
    final flavors = shape.flavors ?? [];
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFFFF9800).withOpacity(0.04), const Color(0xFFFF5722).withOpacity(0.04)]),
        border: Border(top: BorderSide(color: const Color(0xFFFF9800).withOpacity(0.2)), bottom: BorderSide(color: const Color(0xFFFF9800).withOpacity(0.2))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: flavors.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Obx(() {
              final isSelected = selectedFlavor.value == 'all';
              return GestureDetector(
                onTap: () => selectedFlavor.value = 'all',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFF5722)]) : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? const Color(0xFFFF9800) : Colors.grey.shade300, width: isSelected ? 2 : 1),
                    boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
                  ),
                  child: Text('🍹 ${'all'.tr}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1A2332), fontWeight: FontWeight.w600, fontSize: 11)),
                ),
              );
            });
          }
          final flavor = flavors[index - 1];
          final flavorColor = _getFlavorColor(flavor.name);
          return Obx(() {
            final isSelected = selectedFlavor.value == flavor.name;
            return GestureDetector(
              onTap: () => selectedFlavor.value = flavor.name,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isSelected ? LinearGradient(colors: [flavorColor.withOpacity(0.8), flavorColor]) : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? flavorColor : Colors.grey.shade300, width: isSelected ? 2 : 1),
                  boxShadow: isSelected ? [BoxShadow(color: flavorColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
                ),
                child: Text('🍹 ${flavor.name}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1A2332), fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildLevelFourBar(SubCategory shape, RxString selectedSubType, RxString selectedSubFlavor, bool isDark) {
    final subTypes = shape.subCategories ?? [];
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF9C27B0).withOpacity(0.04),
        border: Border(
          top: BorderSide(color: const Color(0xFF9C27B0).withOpacity(0.15)),
          bottom: BorderSide(color: const Color(0xFF9C27B0).withOpacity(0.15)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: subTypes.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Obx(() {
              final isSelected = selectedSubType.value == 'all';
              return GestureDetector(
                onTap: () {
                  selectedSubType.value = 'all';
                  selectedSubFlavor.value = 'all';
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF9C27B0) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade400, width: 1.5),
                  ),
                  child: Text('📌 ${'all'.tr}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF9C27B0), fontWeight: FontWeight.w600, fontSize: 11)),
                ),
              );
            });
          }
          final subType = subTypes[index - 1];
          return Obx(() {
            final isSelected = selectedSubType.value == subType.name;
            return GestureDetector(
              onTap: () {
                selectedSubType.value = subType.name;
                selectedSubFlavor.value = 'all';
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF9C27B0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade400, width: 1.5),
                ),
                child: Text('📌 ${subType.name}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF9C27B0), fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildLevelFiveBar(SubCategory subType, RxString selectedSubFlavor, bool isDark) {
    final flavors = subType.flavors ?? [];
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF4CAF50).withOpacity(0.04), const Color(0xFF2196F3).withOpacity(0.04)]),
        border: Border(top: BorderSide(color: const Color(0xFF4CAF50).withOpacity(0.2)), bottom: BorderSide(color: const Color(0xFF4CAF50).withOpacity(0.2))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: flavors.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Obx(() {
              final isSelected = selectedSubFlavor.value == 'all';
              return GestureDetector(
                onTap: () => selectedSubFlavor.value = 'all',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2196F3)]) : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300, width: isSelected ? 2 : 1),
                    boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
                  ),
                  child: Text('🍹 ${'all'.tr}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1A2332), fontWeight: FontWeight.w600, fontSize: 11)),
                ),
              );
            });
          }
          final flavor = flavors[index - 1];
          final flavorColor = _getFlavorColor(flavor.name);
          return Obx(() {
            final isSelected = selectedSubFlavor.value == flavor.name;
            return GestureDetector(
              onTap: () => selectedSubFlavor.value = flavor.name,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isSelected ? LinearGradient(colors: [flavorColor.withOpacity(0.8), flavorColor]) : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? flavorColor : Colors.grey.shade300, width: isSelected ? 2 : 1),
                  boxShadow: isSelected ? [BoxShadow(color: flavorColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
                ),
                child: Text('🍹 ${flavor.name}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1A2332), fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildContent(
      ProductController pc,
      RxList<OrderItem> cart,
      RxDouble total,
      bool isDark,
      String currency,
      RxString selectedSub,
      RxString selectedShape,
      RxString selectedFlavor,
      RxString selectedSubType,
      RxString selectedSubFlavor,
      BuildContext context,
      ) {
    if (selectedSub.value == 'all') {
      return _buildAllSubGrid(pc, cart, total, isDark, currency, selectedSub);
    }

    final sub = _findSub(selectedSub.value);
    if (sub == null) {
      return Center(child: Text('subcategory_not_found'.tr));
    }

    if (selectedShape.value == 'all') {
      return _buildTypesGrid(
        sub: sub,
        isDark: isDark,
        onTypeTap: (typeName) {
          selectedShape.value = typeName;
          selectedFlavor.value = 'all';
          selectedSubType.value = 'all';
          selectedSubFlavor.value = 'all';
        },
      );
    }

    final Set<String> categoryNames = {sub.name};
    if (sub.subCategories != null) {
      for (var shape in sub.subCategories!) {
        categoryNames.add(shape.name);
        if (shape.flavors != null) {
          for (var f in shape.flavors!) {
            categoryNames.add(f.name);
          }
        }
        if (shape.subCategories != null) {
          for (var subType in shape.subCategories!) {
            categoryNames.add(subType.name);
            if (subType.flavors != null) {
              for (var f in subType.flavors!) {
                categoryNames.add(f.name);
              }
            }
          }
        }
      }
    }

    List<Product> displayProducts = pc.products.where((p) => categoryNames.contains(p.category)).toList();

    if (selectedShape.value != 'all') {
      final shape = _findShape(sub, selectedShape.value);
      if (shape != null) {
        final shapeCategories = {shape.name};
        if (shape.flavors != null) {
          for (var f in shape.flavors!) {
            shapeCategories.add(f.name);
          }
        }
        if (shape.subCategories != null) {
          for (var st in shape.subCategories!) {
            shapeCategories.add(st.name);
            if (st.flavors != null) {
              for (var f in st.flavors!) {
                shapeCategories.add(f.name);
              }
            }
          }
        }
        displayProducts = displayProducts.where((p) => shapeCategories.contains(p.category)).toList();
      }
    }

    if (selectedFlavor.value != 'all') {
      displayProducts = displayProducts.where((p) {
        return p.name.toLowerCase().contains(selectedFlavor.value.toLowerCase()) ||
            p.description.toLowerCase().contains(selectedFlavor.value.toLowerCase()) ||
            (p.flavor?.toLowerCase() == selectedFlavor.value.toLowerCase());
      }).toList();
    }

    if (selectedSubType.value != 'all') {
      final shape = _findShape(sub, selectedShape.value);
      if (shape != null) {
        final subType = _findSubType(shape, selectedSubType.value);
        if (subType != null) {
          final subTypeCategories = {subType.name};
          if (subType.flavors != null) {
            for (var f in subType.flavors!) {
              subTypeCategories.add(f.name);
            }
          }
          displayProducts = displayProducts.where((p) => subTypeCategories.contains(p.category)).toList();
        }
      }
    }

    if (selectedSubFlavor.value != 'all') {
      displayProducts = displayProducts.where((p) {
        return p.name.toLowerCase().contains(selectedSubFlavor.value.toLowerCase()) ||
            p.description.toLowerCase().contains(selectedSubFlavor.value.toLowerCase()) ||
            (p.flavor?.toLowerCase() == selectedSubFlavor.value.toLowerCase());
      }).toList();
    }

    final unique = displayProducts.toSet().toList();

    if (unique.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'no_products_in_this_filter'.tr,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                selectedShape.value = 'all';
                selectedFlavor.value = 'all';
                selectedSubType.value = 'all';
                selectedSubFlavor.value = 'all';
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text('show_all_products'.tr),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: unique.length,
      itemBuilder: (ctx, index) {
        final product = unique[index];
        return _buildPremiumProductCard(
          product,
          cart,
          total,
          isDark,
          currency,
          ctx,
        );
      },
    );
  }

  void _showProductDetailExpanded(
      Product p,
      RxList<OrderItem> cart,
      RxDouble total,
      bool isDark,
      String currency,
      BuildContext ctx,
      ) {
    final images = <String>[
      if (p.imagePath.trim().isNotEmpty) p.imagePath.trim(),
      ...p.additionalImages.where((img) => img.trim().isNotEmpty).map((img) => img.trim()),
    ];

    if (images.isEmpty) {
      images.add('');
    }

    final pageController = PageController();
    final currentIndex = 0.obs;

    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'close'.tr,
      barrierColor: Colors.black.withOpacity(0.48),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Center(
              child: PremiumProductExpandedView(
                product: p,
                images: images,
                pageController: pageController,
                currentIndex: currentIndex,
                cart: cart,
                total: total,
                isDark: isDark,
                currency: currency,
                parentContext: ctx,
                onAddToCart: () => _showSizePopup(p, cart, total, ctx, currency),
                isAddedToCart: false,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    ).then((_) {
      pageController.dispose();
    });
  }

  Widget _buildTypesGrid({
    required SubCategory sub,
    required bool isDark,
    required void Function(String) onTypeTap,
  }) {
    final types = sub.subCategories ?? [];

    if (types.isEmpty) {
      return Center(
        child: Text(
          'no_types_yet'.tr,
          style: const TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        return _buildTypeCard(
          type: type,
          isDark: isDark,
          onTap: () => onTypeTap(type.name),
        );
      },
    );
  }

  Widget _buildTypeCard({
    required SubCategory type,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final pc = Get.find<ProductController>();
    final productsCount = pc.products.where((p) => p.category == type.name).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171F30) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: type.imagePath != null && type.imagePath!.isNotEmpty
                  ? ImageHelper.displayImage(
                imagePath: type.imagePath,
                fit: BoxFit.cover,
                placeholder: _buildImagePlaceholderPremium(isDark),
              )
                  : _buildImagePlaceholderPremium(isDark),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$productsCount',
                  style: const TextStyle(
                    color: Color(0xFF1A2332),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                type.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSubGrid(
      ProductController pc,
      RxList<OrderItem> cart,
      RxDouble total,
      bool isDark,
      String currency,
      RxString selectedSub,
      ) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: category.subCategories.length,
      itemBuilder: (context, index) {
        final sub = category.subCategories[index];
        final products = pc.products.where((p) => p.category == sub.name).toList();
        final subProducts = <Product>[];
        if (sub.subCategories != null) {
          for (final sc in sub.subCategories!) {
            subProducts.addAll(pc.products.where((p) => p.category == sc.name));
            if (sc.subCategories != null) {
              for (final subType in sc.subCategories!) {
                subProducts.addAll(pc.products.where((p) => p.category == subType.name));
              }
            }
          }
        }
        final allProducts = [...products, ...subProducts];
        final totalProducts = allProducts.length;

        Product? coverProduct;
        for (final product in allProducts) {
          final path = product.imagePath ?? '';
          if (path.isNotEmpty && path != 'assets/images/product_placeholder.png') {
            coverProduct = product;
            break;
          }
        }

        return _buildCategoryVisualCard(
          sub: sub,
          coverProduct: coverProduct,
          totalProducts: totalProducts,
          isDark: isDark,
          onTap: () {
            selectedSub.value = sub.name;
          },
        );
      },
    );
  }

  Widget _buildCategoryVisualCard({
    required SubCategory sub,
    required Product? coverProduct,
    required int totalProducts,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final String? cloudImageUrl = sub.imagePath;
    final colors = [
      const Color(0xFF667EEA),
      const Color(0xFF764BA2),
      const Color(0xFF00BFA6),
      const Color(0xFFFF8A65),
      const Color(0xFFFFB300),
      const Color(0xFFEC407A),
    ];
    final color = colors[sub.name.hashCode.abs() % colors.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171F30) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildCategoryBackground(
                cloudImageUrl: cloudImageUrl,
                coverProduct: coverProduct,
                isDark: isDark,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.78),
                    ],
                    stops: const [0.25, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      '$totalProducts',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'view_products'.tr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.2)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBackground({
    required String? cloudImageUrl,
    required Product? coverProduct,
    required bool isDark,
  }) {
    if (cloudImageUrl != null && cloudImageUrl.isNotEmpty) {
      if (cloudImageUrl.startsWith('data:image')) {
        try {
          final base64Data = cloudImageUrl.split(',').last;
          final bytes = base64Decode(base64Data);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return coverProduct != null
                  ? _buildProductImagePremium(coverProduct, isDark)
                  : _buildImagePlaceholderPremium(isDark);
            },
          );
        } catch (e) {
          return coverProduct != null
              ? _buildProductImagePremium(coverProduct, isDark)
              : _buildImagePlaceholderPremium(isDark);
        }
      }

      if (cloudImageUrl.startsWith('http://') || cloudImageUrl.startsWith('https://')) {
        return Image.network(
          cloudImageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return coverProduct != null
                ? _buildProductImagePremium(coverProduct, isDark)
                : _buildImagePlaceholderPremium(isDark);
          },
        );
      }

      if (cloudImageUrl.startsWith('assets/')) {
        return Image.asset(
          cloudImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return coverProduct != null
                ? _buildProductImagePremium(coverProduct, isDark)
                : _buildImagePlaceholderPremium(isDark);
          },
        );
      }

      if (!kIsWeb) {
        final file = File(cloudImageUrl);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return coverProduct != null
                  ? _buildProductImagePremium(coverProduct, isDark)
                  : _buildImagePlaceholderPremium(isDark);
            },
          );
        }
      }
    }

    if (coverProduct != null) {
      return _buildProductImagePremium(coverProduct, isDark);
    }

    return _buildImagePlaceholderPremium(isDark);
  }

  Widget _buildPremiumProductCard(
      Product p,
      RxList<OrderItem> cart,
      RxDouble total,
      bool isDark,
      String currency,
      BuildContext ctx,
      ) {
    final darkBg = const Color(0xFF151C2B);
    final detailsBg = isDark ? const Color(0xFF1B2435) : const Color(0xFFF7F8FA);

    const buttonGradient = LinearGradient(
      colors: [
        Color(0xFF380E5D),
        Color(0xFF07083D),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    const goldGradient = LinearGradient(
      colors: [
        Color(0xFFF2C94C),
        Color(0xFFF6A663),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: () => _showProductDetailExpanded(p, cart, total, isDark, currency, ctx),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? darkBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFE0E4EA),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF667EEA)).withOpacity(0.10),
              blurRadius: 12,
              spreadRadius: 1,
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: ImageHelper.displayImage(
                        imagePath: p.imagePath,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: _buildImagePlaceholderPremium(isDark),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: goldGradient,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD2B350).withOpacity(0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$currency${p.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF332000),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (p.additionalImages.isNotEmpty)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              '${1 + p.additionalImages.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: detailsBg,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.description.isNotEmpty ? p.description : 'no_description'.tr,
                        style: TextStyle(
                          fontSize: 8,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: buttonGradient,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF37224B).withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _showSizePopup(p, cart, total, ctx, currency),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'add'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumBadge({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 7, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildProductImagePremium(Product p, bool isDark) {
    String? validImage = p.imagePath.trim().isNotEmpty &&
        p.imagePath != 'assets/images/product_placeholder.png'
        ? p.imagePath.trim()
        : null;

    if (validImage == null && p.additionalImages.isNotEmpty) {
      validImage = p.additionalImages.first.trim();
    }

    if (validImage == null || validImage.isEmpty) {
      return _buildImagePlaceholderPremium(isDark);
    }

    if (validImage.startsWith('data:image')) {
      try {
        final base64Data = validImage.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholderPremium(isDark),
        );
      } catch (e) {
        print('❌ Base64 display error: $e');
        return _buildImagePlaceholderPremium(isDark);
      }
    }

    if (validImage.startsWith('http://') || validImage.startsWith('https://')) {
      return Image.network(
        validImage,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholderPremium(isDark),
      );
    }

    if (!kIsWeb) {
      final file = File(validImage);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholderPremium(isDark),
        );
      }
    }

    return _buildImagePlaceholderPremium(isDark);
  }

  void _showFullScreenImageGallery(BuildContext context, Product product) {
    final List<String> allImages = [];
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      allImages.add(product.imagePath!);
    }
    if (product.additionalImages != null) {
      allImages.addAll(product.additionalImages!.where((img) => img.isNotEmpty));
    }

    if (allImages.isEmpty) return;

    final PageController pageController = PageController();
    final RxInt currentIndex = 0.obs;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            title: Obx(() => Text(
              '${currentIndex.value + 1} / ${allImages.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            )),
            centerTitle: true,
          ),
          body: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: pageController,
                itemCount: allImages.length,
                onPageChanged: (index) => currentIndex.value = index,
                itemBuilder: (context, index) {
                  final imageStr = allImages[index];
                  return InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                        child: _buildAdaptiveWebImage(imageStr),
                      ),
                    ),
                  );
                },
              ),
              if (allImages.length > 1) ...[
                Positioned(
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
                    onPressed: () {
                      pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 30),
                    onPressed: () {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdaptiveWebImage(String path) {
    if (path.startsWith('data:image') || path.length > 500) {
      try {
        final base64Str = path.contains(',') ? path.split(',').last : path;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        return const Icon(Icons.broken_image, color: Colors.white, size: 50);
      }
    }

    if (path.startsWith('http://') || path.startsWith('https://') || kIsWeb) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        },
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
    );
  }

  Widget _buildImageLoading(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? const [Color(0xFF20283A), Color(0xFF151C2B)] : const [Color(0xFFF5F7FB), Color(0xFFEDEFF5)],
        ),
      ),
      child: const Center(
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF667EEA))),
      ),
    );
  }

  Widget _buildImagePlaceholderPremium(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? const [Color(0xFF252D40), Color(0xFF151C2B)] : const [Color(0xFFF4F6FA), Color(0xFFE7EBF3)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                boxShadow: [BoxShadow(color: const Color(0xFF667EEA).withOpacity(0.25), blurRadius: 15)],
              ),
              child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 23),
            ),
            const SizedBox(height: 8),
            Text('no_image'.tr, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.grey.shade100, Colors.grey.shade200], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
              child: const Icon(Icons.shopping_bag_rounded, size: 16, color: Color(0xFFFF9800)),
            ),
            const SizedBox(height: 2),
            Text('no_image_short'.tr, style: TextStyle(fontSize: 7, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  void _showSizePopup(Product product, RxList<OrderItem> cart, RxDouble total, BuildContext ctx, String currency) {
    if (product.hasMultipleSizes && product.sizes != null && product.sizes!.isNotEmpty) {
      _showSizeDialog(product, cart, total, ctx, currency);
    } else {
      _addToCart(product, 1, cart, total);
      Get.snackbar('done'.tr, 'added_to_cart'.tr, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white, duration: const Duration(seconds: 1));
    }
  }

  void _showSizeDialog(Product product, RxList<OrderItem> cart, RxDouble total, BuildContext ctx, String currency) {
    ProductSize? selectedSize;
    int quantity = 1;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), child: ImageHelper.displayImage(imagePath: product.imagePath != 'assets/images/product_placeholder.png' ? product.imagePath : null, height: 140, width: double.infinity, fit: BoxFit.cover, placeholder: Container(height: 140, color: const Color(0xFFFF9800).withOpacity(0.1), child: const Icon(Icons.shopping_bag_rounded, size: 45, color: Color(0xFFFF9800))))),
                Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A2332))),
                  if (product.flavor != null) Text('🍹 ${product.flavor}', style: const TextStyle(color: Colors.teal, fontSize: 13)),
                  const SizedBox(height: 12),
                  Text('choose_size'.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                  const SizedBox(height: 8),
                  ...product.sizes!.map((size) {
                    final isSelected = selectedSize?.id == size.id;
                    return GestureDetector(
                      onTap: () => setDialogState(() { selectedSize = size; quantity = 1; }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: isSelected ? const Color(0xFF1A2332) : Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? const Color(0xFF1A2332) : Colors.grey.withOpacity(0.3), width: isSelected ? 2 : 1)),
                        child: Row(children: [
                          Icon(Icons.straighten_rounded, color: isSelected ? const Color(0xFFFFD700) : const Color(0xFFFF9800), size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(size.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF1A2332)))),
                          Text('$currency${size.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFFFFD700) : Colors.teal)),
                        ]),
                      ),
                    );
                  }),
                  if (selectedSize != null) ...[
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      GestureDetector(onTap: () { if (quantity > 1) setDialogState(() => quantity--); }, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.remove_rounded))),
                      const SizedBox(width: 16),
                      Text('$quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      GestureDetector(onTap: () => setDialogState(() => quantity++), child: Container(width: 36, height: 36, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A2332), Color(0xFF2D3A4E)]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_rounded, color: Colors.white))),
                    ]),
                    const SizedBox(height: 8),
                    Center(child: Text('${'total_label'.tr}: $currency${(selectedSize!.price * quantity).toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
                    onPressed: selectedSize == null ? null : () { _addToCart(product, quantity, cart, total); Navigator.pop(dialogCtx); Get.snackbar('done'.tr, 'added_to_cart'.tr, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white); },
                    icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                    label: Text(selectedSize != null ? 'add_to_cart'.tr : 'choose_size'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: selectedSize != null ? const Color(0xFF1A2332) : Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )),
                ])),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _addToCart(Product p, int qty, RxList<OrderItem> cart, RxDouble total) {
    final idx = cart.indexWhere((i) => i.productId == p.id);
    if (idx != -1) {
      final e = cart[idx];
      cart[idx] = OrderItem(productId: p.id, productName: p.name, price: p.price, quantity: e.quantity + qty, total: p.price * (e.quantity + qty));
    } else {
      cart.add(OrderItem(productId: p.id, productName: p.name, price: p.price, quantity: qty, total: p.price * qty));
    }
    total.value = cart.fold(0.0, (s, i) => s + i.total);
    cart.refresh();
  }

  SubCategory? _findSub(String name) {
    for (var sub in category.subCategories) {
      if (sub.name == name) return sub;
    }
    return null;
  }

  SubCategory? _findShape(SubCategory sub, String name) {
    if (sub.subCategories == null) return null;
    for (var s in sub.subCategories!) {
      if (s.name == name) return s;
    }
    return null;
  }

  SubCategory? _findSubType(SubCategory shape, String name) {
    if (shape.subCategories == null) return null;
    for (var s in shape.subCategories!) {
      if (s.name == name) return s;
    }
    return null;
  }

  Color _getFlavorColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('strawberry') || n.contains('berry')) return Colors.red;
    if (n.contains('mango') || n.contains('orange')) return Colors.orange;
    if (n.contains('mint') || n.contains('menthol')) return Colors.green;
    if (n.contains('grape')) return Colors.purple;
    if (n.contains('lemon')) return Colors.amber;
    if (n.contains('watermelon')) return Colors.pink;
    if (n.contains('peach')) return Colors.deepOrange;
    return Colors.teal;
  }
}