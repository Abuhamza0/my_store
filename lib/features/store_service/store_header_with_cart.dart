import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'order_model.dart';
import 'customer_model.dart';

class StoreHeaderWithCart extends StatelessWidget {
  final Customer? loggedInCustomer;
  final RxList<OrderItem> cart;
  final RxDouble total;
  final VoidCallback onCartTap;

  const StoreHeaderWithCart({
    super.key,
    required this.loggedInCustomer,
    required this.cart,
    required this.total,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box('settings');
    final storeName =
    settingsBox.get('store_name', defaultValue: 'my_store'.tr);
    final currencySymbol =
    settingsBox.get('currency', defaultValue: 'SAR');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2332), Color(0xFF2D3A4E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius:
        const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2332).withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // اسم المتجر + الترحيب
          Row(
            children: [
              // أيقونة العميل
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.white.withOpacity(0.15),
                ),
                child: Center(
                  child: Text(
                    loggedInCustomer?.name != null &&
                        loggedInCustomer!.name.isNotEmpty
                        ? loggedInCustomer!.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // رسالة الترحيب
              Expanded(
                child: Text(
                  '${'welcome'.tr} ${loggedInCustomer?.name ?? ''}! 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // اسم المتجر
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  storeName,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // بطاقة السلة
          Obx(() => GestureDetector(
            onTap: onCartTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cart.isEmpty
                      ? [Colors.grey.shade300, Colors.grey.shade400]
                      : const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (cart.isEmpty
                        ? Colors.grey
                        : const Color(0xFFFF6B6B))
                        .withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // أيقونة السلة مع العدد
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: cart.isEmpty
                            ? [Colors.grey.shade500, Colors.grey.shade700]
                            : const [
                          Color(0xFF4CAF50),
                          Color(0xFF2E7D32)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            cart.isEmpty
                                ? Icons.shopping_cart_outlined
                                : Icons.shopping_cart_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (cart.isNotEmpty)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                '${cart.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // نص السلة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cart.isEmpty
                              ? 'cart_empty'.tr
                              : '${cart.length} ${'cart_items_count'.tr}',
                          style: TextStyle(
                            color: cart.isEmpty
                                ? Colors.grey.shade800
                                : const Color(0xFF1A2332),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          cart.isEmpty
                              ? 'add_products_msg'.tr
                              : 'tap_to_review'.tr,
                          style: TextStyle(
                            color: cart.isEmpty
                                ? Colors.grey.shade700
                                : Colors.white.withOpacity(0.9),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // الإجمالي
                  Text(
                    cart.isEmpty
                        ? '0.00 $currencySymbol'
                        : '${total.value.toStringAsFixed(0)} $currencySymbol',
                    style: TextStyle(
                      color: cart.isEmpty
                          ? Colors.grey.shade800
                          : const Color(0xFF1A2332),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),

                  // سهم
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: cart.isEmpty
                        ? Colors.grey.shade700
                        : const Color(0xFF1A2332),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}