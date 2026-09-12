// Premium_Cart_Sheet.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mystore/features/store_service/order_controller.dart';
import 'package:mystore/features/store_service/order_model.dart';
import 'package:mystore/features/store_service/product_controller.dart';
import 'package:mystore/features/store_service/product_model.dart';
import 'package:mystore/utils/image_helper.dart';

import 'Premium_Product_Expanded_View.dart';
import 'customer_model.dart';

class PremiumCartSheet extends StatefulWidget {
  final RxList<OrderItem> cart;
  final RxDouble total;
  final OrderController oc;
  final Customer? loggedInCustomer;
  final String currency;
  final Future<void> Function(Order order) uploadOrder;

  const PremiumCartSheet({
    Key? key,
    required this.cart,
    required this.total,
    required this.oc,
    this.loggedInCustomer,
    required this.currency,
    required this.uploadOrder,
  }) : super(key: key);

  @override
  State<PremiumCartSheet> createState() => _PremiumCartSheetState();
}

class _PremiumCartSheetState extends State<PremiumCartSheet> {
  final TextEditingController _notesController = TextEditingController();

  static const navy = Color(0xFF101A2D);
  static const navy2 = Color(0xFF24334C);
  static const gold = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFF3D978);
  static const surface = Color(0xFFF7F8FB);
  static const textDark = Color(0xFF172033);
  static const muted = Color(0xFF7B8494);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _refreshTotal() {
    widget.total.value = widget.cart.fold(0.0, (sum, item) => sum + item.total);
    setState(() {});
  }

  bool _isSubmitting = false;

  Future<void> _submitOrder() async {
    if (widget.cart.isEmpty) return;

    final customer = widget.loggedInCustomer;
    if (customer == null) {
      Get.snackbar('error'.tr, 'login_required'.tr);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final order = Order(
        customerId: customer.id,
        customerName: customer.name,
        customerPhone: customer.phone,
        items: List.from(widget.cart),
        totalAmount: widget.total.value,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        accessMethod: 'credentials',
      );

      await widget.oc.addOrder(order);
      await widget.uploadOrder(order);

      widget.cart.clear();
      widget.total.value = 0;

      if (mounted) Navigator.pop(context);

      Get.snackbar(
        'order_sent_successfully'.tr,
        'will_notify_when_ready'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF2E8B57),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      );
    } catch (e) {
      print('❌ Order send failed: $e');
      Get.snackbar(
        'error'.tr,
        'order_send_error'.tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error_rounded, color: Colors.white),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.currency;

    return Container(
      height: Get.height * 0.88,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2B) : surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [navy, navy2],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: gold.withOpacity(0.28)),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: goldLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'cart_title'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'review_order'.tr,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(
                          () => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: gold.withOpacity(0.28)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_cart_rounded,
                              color: goldLight,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${widget.cart.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: Obx(
                  () => widget.cart.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: navy.withOpacity(0.055),
                        shape: BoxShape.circle,
                        border: Border.all(color: gold.withOpacity(0.18)),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 46,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'cart_empty'.tr,
                      style: TextStyle(
                        color: isDark ? Colors.white : textDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'add_products_to_continue'.tr,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                itemCount: widget.cart.length,
                itemBuilder: (c, i) {
                  final item = widget.cart[i];
                  final pc = Get.find<ProductController>();
                  Product? product;
                  for (final p in pc.products) {
                    if (p.id == item.productId) {
                      product = p;
                      break;
                    }
                  }

                  final flavor = product?.flavor?.trim() ?? '';

                  return GestureDetector(
                    onTap: product != null ? () => _openProductExpandedView(product!) : null,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B2435) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFE9ECF2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.035),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: const LinearGradient(
                                colors: [navy, navy2],
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ImageHelper.displayImage(
                              imagePath: product?.imagePath,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [navy, navy2],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_rounded,
                                  color: goldLight,
                                  size: 25,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : textDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (flavor.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      '🍹 $flavor',
                                      style: const TextStyle(
                                        color: Colors.teal,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 7),
                                Text(
                                  '${item.price.toStringAsFixed(2)} $currency',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.total.toStringAsFixed(0)} $currency',
                                style: TextStyle(
                                  color: isDark ? Colors.white : textDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _cartQtyButton(
                                    icon: Icons.remove_rounded,
                                    onTap: () {
                                      if (item.quantity > 1) {
                                        final q = item.quantity - 1;
                                        widget.cart[i] = OrderItem(
                                          productId: item.productId,
                                          productName: item.productName,
                                          price: item.price,
                                          quantity: q,
                                          total: item.price * q,
                                        );
                                      } else {
                                        widget.cart.removeAt(i);
                                      }
                                      _refreshTotal();
                                    },
                                    filled: false,
                                  ),
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 32),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item.quantity}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : textDark,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  _cartQtyButton(
                                    icon: Icons.add_rounded,
                                    onTap: () {
                                      final q = item.quantity + 1;
                                      widget.cart[i] = OrderItem(
                                        productId: item.productId,
                                        productName: item.productName,
                                        price: item.price,
                                        quantity: q,
                                        total: item.price * q,
                                      );
                                      _refreshTotal();
                                    },
                                    filled: true,
                                  ),
                                  const SizedBox(width: 5),
                                  InkWell(
                                    onTap: () {
                                      widget.cart.removeAt(i);
                                      _refreshTotal();
                                    },
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.07),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFE05252),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 14,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2435) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE9ECF2),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.055),
                  blurRadius: 18,
                  offset: const Offset(0, -7),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _notesController,
                  maxLines: 1,
                  style: TextStyle(color: isDark ? Colors.white : textDark),
                  decoration: InputDecoration(
                    hintText: 'add_order_note'.tr,
                    hintStyle: const TextStyle(color: muted, fontSize: 11),
                    prefixIcon: const Icon(Icons.edit_note_rounded, color: navy, size: 21),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF151C2B) : surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        navy.withOpacity(0.055),
                        gold.withOpacity(0.075),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: gold.withOpacity(0.16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: gold, size: 19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'total_label'.tr,
                          style: TextStyle(
                            color: isDark ? Colors.white : textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Obx(
                            () => Text(
                          '${widget.total.value.toStringAsFixed(2)} $currency',
                          style: TextStyle(
                            color: isDark ? goldLight : navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: Obx(
                        () => ElevatedButton(
                      onPressed: widget.cart.isEmpty || _isSubmitting ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 31,
                            height: 31,
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.send_rounded, color: goldLight, size: 16),
                          ),
                          const SizedBox(width: 9),
                          Text(
                            'send_order'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
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
        ],
      ),
    );
  }

  void _openProductExpandedView(Product product) {
    final images = <String>[
      if (product.imagePath.trim().isNotEmpty) product.imagePath.trim(),
      ...product.additionalImages.where((img) => img.trim().isNotEmpty),
    ];

    final PageController pageController = PageController();
    final RxInt currentIndex = 0.obs;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => PremiumProductExpandedView(
        product: product,
        images: images,
        pageController: pageController,
        currentIndex: currentIndex,
        cart: widget.cart,
        total: widget.total,
        isDark: Theme.of(context).brightness == Brightness.dark,
        currency: widget.currency,
        parentContext: context,
        onAddToCart: () {
          // Product already in cart
        },
        isAddedToCart: true,
      ),
    );
  }

  Widget _cartQtyButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: filled ? navy : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled ? Colors.white : textDark,
        ),
      ),
    );
  }
}