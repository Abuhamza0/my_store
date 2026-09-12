import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../../core/services/store_id_service.dart';
import 'order_controller.dart';
import 'order_model.dart';

class OrderNotificationWidget extends StatelessWidget {
  const OrderNotificationWidget({super.key});

  // ✅ الحصول على storeId من الخدمة
  String _getStoreId() {
    return StoreIdService.getStoreId();
  }

  @override
  Widget build(BuildContext context) {
    final OrderController orderController = Get.find<OrderController>();

    return Obx(() {
      final unreadCount = orderController.unreadOrdersCount.value;

      if (unreadCount == 0) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () {
          Get.to(() => const OrdersListScreen());
        },
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.orange.shade400],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white, size: 28),
                    ...List.generate(3, (index) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 1000 + (index * 300)),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: (1 - value).clamp(0.0, 0.5),
                            child: Transform.scale(
                              scale: 1 + (value * 0.5),
                              child: Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لديك $unreadCount ${unreadCount == 1 ? 'طلب جديد' : 'طلبات جديدة'}! 🔔',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('اضغط لعرض الطلبات الجديدة', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
            ],
          ),
        ),
      );
    });
  }
}

// صفحة قائمة الطلبات
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  String _currentFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final OrderController orderController = Get.find<OrderController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات'),
        backgroundColor: const Color(0xFF1D325E),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (value) {
              setState(() {
                _currentFilter = value;
                orderController.filterStatus.value = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'pending', child: Text('جديدة')),
              const PopupMenuItem(value: 'preparing', child: Text('قيد التجهيز')),
              const PopupMenuItem(value: 'ready', child: Text('جاهزة')),
              const PopupMenuItem(value: 'delivered', child: Text('تم التسليم')),
              const PopupMenuItem(value: 'cancelled', child: Text('ملغاة')),
            ],
          ),
        ],
      ),
      body: Obx(() {
        final orders = orderController.getFilteredOrders();

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('لا توجد طلبات', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: order.statusColor,
                  child: Text(
                    order.customerName.isNotEmpty ? order.customerName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${order.items.length} منتجات - ${order.totalAmount.toStringAsFixed(2)} ر.س\n${order.createdAt.toString()}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                isThreeLine: true,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.statusText,
                    style: TextStyle(color: order.statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                onTap: () {
                  orderController.markAsRead(order.id);
                  Get.snackbar(
                    'تفاصيل الطلب',
                    'العميل: ${order.customerName}\nالإجمالي: ${order.totalAmount.toStringAsFixed(2)} ر.س',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF1D325E),
                    colorText: Colors.white,
                  );
                },
              ),
            );
          },
        );
      }),
    );
  }
}