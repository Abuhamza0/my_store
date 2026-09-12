import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../core/services/store_id_service.dart';
import 'customer_model.dart';
import 'product_model.dart';
import 'product_controller.dart';
import 'order_model.dart';
import 'order_controller.dart';

class RemoteOrderScreen extends StatefulWidget {
  final Customer customer;
  final String accessMethod; // 'direct_link' أو 'credentials'
  final String? storeIdFromUrl; // ✅ إضافة هذا الحقل

  const RemoteOrderScreen({
    super.key,
    required this.customer,
    required this.accessMethod,
    this.storeIdFromUrl,
  });

  @override
  State<RemoteOrderScreen> createState() => _RemoteOrderScreenState();
}

class _RemoteOrderScreenState extends State<RemoteOrderScreen> {
  // ✅ الحصول على storeId من الرابط أو من الخدمة
  String _getStoreId() {
    return widget.storeIdFromUrl ?? StoreIdService.getStoreId();
  }

  @override
  Widget build(BuildContext context) {
    final ProductController productController = Get.find<ProductController>();
    final OrderController orderController = Get.put(OrderController());

    final cartItems = <OrderItem>[].obs;
    final cartTotal = 0.0.obs;
    final isGridView = true.obs;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('تسوق الآن'),
        backgroundColor: const Color(0xFF1D325E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // طريقة العرض
          Obx(() => IconButton(
            icon: Icon(isGridView.value ? Icons.list_rounded : Icons.grid_view_rounded),
            onPressed: () => isGridView.toggle(),
            tooltip: 'تغيير العرض',
          )),
          // السلة
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_rounded),
                onPressed: () {
                  if (cartItems.isEmpty) {
                    Get.snackbar('السلة فارغة', 'أضف منتجات إلى سلتك 🛒',
                        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white);
                  } else {
                    _showCartDialog(cartItems, cartTotal, orderController);
                  }
                },
              ),
              Obx(() {
                if (cartItems.isEmpty) return const SizedBox();
                return Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('${cartItems.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // هيدر الترحيب
          _buildWelcomeHeader(),
          // شريط السلة
          Obx(() {
            if (cartItems.isEmpty) return const SizedBox();
            return _buildCartBar(cartItems, cartTotal, orderController);
          }),
          // قائمة المنتجات
          Expanded(
            child: Obx(() {
              if (productController.filteredProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_rounded, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('لا توجد منتجات', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }

              if (isGridView.value) {
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: productController.filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = productController.filteredProducts[index];
                    return _buildProductCard(product, cartItems, cartTotal);
                  },
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: productController.filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = productController.filteredProducts[index];
                  return _buildProductListItem(product, cartItems, cartTotal);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==================== هيدر الترحيب ====================
  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1D325E), const Color(0xFF1D325E).withOpacity(0.8)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: const Color(0xFF1D325E).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              gradient: LinearGradient(colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)]),
            ),
            child: Center(
              child: Text(
                widget.customer.name.isNotEmpty ? widget.customer.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً ${widget.customer.name}! 👋', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  widget.accessMethod == 'direct_link' ? '📱 تم الدخول عبر الرابط السريع' : '🔐 تم الدخول عبر تسجيل الدخول',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== شريط السلة ====================
  Widget _buildCartBar(RxList<OrderItem> cartItems, RxDouble cartTotal, OrderController orderController) {
    return GestureDetector(
      onTap: () => _showCartDialog(cartItems, cartTotal, orderController),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade500]),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() => Text('${cartItems.length} منتجات في السلة', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 2),
                  const Text('اضغط لإتمام الطلب', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Obx(() => Text('${cartTotal.value.toStringAsFixed(2)} ر.س', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // ==================== بطاقة المنتج ====================
  Widget _buildProductCard(Product product, RxList<OrderItem> cartItems, RxDouble cartTotal) {
    return GestureDetector(
      onTap: () => _showProductDetails(product, cartItems, cartTotal),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(colors: [const Color(0xFF1D325E).withOpacity(0.05), Colors.grey.shade100]),
                    ),
                    child: Center(child: Icon(_getCategoryIcon(product.category), size: 50, color: const Color(0xFF1D325E).withOpacity(0.2))),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF1D325E).withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                      child: Text(product.category, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (!product.isAvailable)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                        child: const Center(child: Text('غير متوفر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(product.description, style: TextStyle(color: Colors.grey.shade500, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${product.price.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1D325E))),
                        GestureDetector(
                          onTap: product.isAvailable ? () => _addToCart(product, 1, cartItems, cartTotal) : null,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: product.isAvailable ? const Color(0xFF1D325E) : Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: product.isAvailable ? [BoxShadow(color: const Color(0xFF1D325E).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                            ),
                            child: Icon(product.isAvailable ? Icons.add_shopping_cart_rounded : Icons.block_rounded, color: Colors.white, size: 18),
                          ),
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

  // ==================== قائمة المنتجات ====================
  Widget _buildProductListItem(Product product, RxList<OrderItem> cartItems, RxDouble cartTotal) {
    return GestureDetector(
      onTap: () => _showProductDetails(product, cartItems, cartTotal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey.shade100),
              child: Center(child: Icon(_getCategoryIcon(product.category), size: 30, color: const Color(0xFF1D325E).withOpacity(0.3))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(product.description, style: TextStyle(color: Colors.grey.shade500, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('${product.price.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1D325E))),
                ],
              ),
            ),
            GestureDetector(
              onTap: product.isAvailable ? () => _addToCart(product, 1, cartItems, cartTotal) : null,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: product.isAvailable ? const Color(0xFF1D325E) : Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(product.isAvailable ? Icons.add_shopping_cart_rounded : Icons.block_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== إضافة للسلة ====================
  void _addToCart(Product product, int quantity, RxList<OrderItem> cartItems, RxDouble cartTotal) {
    final existingIndex = cartItems.indexWhere((item) => item.productId == product.id);
    if (existingIndex != -1) {
      final existing = cartItems[existingIndex];
      cartItems[existingIndex] = OrderItem(
        productId: product.id,
        productName: product.name,
        price: product.price,
        quantity: existing.quantity + quantity,
        total: product.price * (existing.quantity + quantity),
      );
    } else {
      cartItems.add(OrderItem(
        productId: product.id,
        productName: product.name,
        price: product.price,
        quantity: quantity,
        total: product.price * quantity,
      ));
    }
    cartTotal.value = cartItems.fold(0.0, (sum, item) => sum + item.total);
    Get.snackbar('✅ تمت الإضافة', 'تم إضافة ${product.name} إلى السلة', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white, duration: const Duration(seconds: 1));
  }

  // ==================== تفاصيل المنتج ====================
  void _showProductDetails(Product product, RxList<OrderItem> cartItems, RxDouble cartTotal) {
    int quantity = 1;
    showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final totalPrice = product.price * quantity;
            return Container(
              height: Get.height * 0.8,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)))),
                    const SizedBox(height: 20),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.grey.shade100),
                      child: Center(child: Icon(_getCategoryIcon(product.category), size: 80, color: const Color(0xFF1D325E).withOpacity(0.2))),
                    ),
                    const SizedBox(height: 20),
                    Text(product.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${product.price.toStringAsFixed(2)} ر.س', style: const TextStyle(fontSize: 22, color: Color(0xFF1D325E), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(product.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
                    const SizedBox(height: 24),
                    // محدد الكمية
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () { if (quantity > 1) setState(() => quantity--); },
                          child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.remove_rounded, color: Color(0xFF1D325E))),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1D325E).withOpacity(0.3)), borderRadius: BorderRadius.circular(14)),
                          child: Text('$quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D325E))),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => quantity++),
                          child: Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF1D325E), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.add_rounded, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: product.isAvailable ? () { _addToCart(product, quantity, cartItems, cartTotal); Navigator.pop(context); } : null,
                        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 24),
                        label: Text(product.isAvailable ? 'إضافة إلى السلة - ${totalPrice.toStringAsFixed(2)} ر.س' : 'غير متوفر', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: product.isAvailable ? const Color(0xFF1D325E) : Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== عرض السلة وإتمام الطلب ====================
  void _showCartDialog(RxList<OrderItem> cartItems, RxDouble cartTotal, OrderController orderController) {
    final notesController = TextEditingController();
    showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: Get.height * 0.85,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)))),
                    const SizedBox(height: 16),
                    const Text('🛒 سلة التسوق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (cartItems.isEmpty) {
                    return const Center(child: Text('السلة فارغة', style: TextStyle(fontSize: 18, color: Colors.grey)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('${item.quantity} × ${item.price.toStringAsFixed(2)} ر.س', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ])),
                            Text('${item.total.toStringAsFixed(2)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D325E), fontSize: 15)),
                            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () { cartItems.removeAt(index); cartTotal.value = cartItems.fold(0.0, (sum, i) => sum + i.total); if (cartItems.isEmpty) Navigator.pop(context); }),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
                child: Column(
                  children: [
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(hintText: 'ملاحظات إضافية (اختياري)', prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF1D325E)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('الإجمالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Obx(() => Text('${cartTotal.value.toStringAsFixed(2)} ر.س', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1D325E)))),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // ✅ الحصول على storeId من الرابط أو من الخدمة
                          final storeId = _getStoreId();

                          final order = Order(
                            customerId: widget.customer.id,
                            customerName: widget.customer.name,
                            customerPhone: widget.customer.phone,
                            items: List<OrderItem>.from(cartItems),
                            totalAmount: cartTotal.value,
                            notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                            accessMethod: widget.accessMethod,
                            storeId: storeId,
                          );

                          await orderController.addOrder(order, storeId: storeId);

                          cartItems.clear();
                          cartTotal.value = 0.0;
                          Navigator.pop(context);
                          Get.snackbar('🎉 تم إرسال الطلب!', 'سيتم تجهيز طلبك قريباً', snackPosition: SnackPosition.TOP, backgroundColor: Colors.green, colorText: Colors.white, duration: const Duration(seconds: 3));
                        },
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                        label: const Text('إرسال الطلب', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D325E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== أيقونة الفئة ====================
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'إلكترونيات': return Icons.devices_rounded;
      case 'ملابس': return Icons.checkroom_rounded;
      case 'أثاث': return Icons.chair_rounded;
      case 'مواد غذائية': return Icons.restaurant_rounded;
      case 'عطور': return Icons.air_rounded;
      case 'أحذية': return Icons.ice_skating_rounded;
      case 'ساعات': return Icons.watch_rounded;
      default: return Icons.shopping_bag_rounded;
    }
  }
}