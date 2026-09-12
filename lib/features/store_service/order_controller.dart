import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/store_id_service.dart';
import 'order_model.dart';

class OrderController extends GetxController {
  final Box _orderBox = Hive.box('orders');

  final orders = <Order>[].obs;
  final unreadOrdersCount = 0.obs;
  final isLoading = false.obs;
  final RxString filterStatus = 'all'.obs;

  // ✅ دالة الحصول على الـ UID (المعرف الموحد لصاحب المتجر)
  String get storeId {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        Hive.box('settings').put('store_id', uid);
        return uid;
      }

      final storedId = Hive.box('settings').get('store_id', defaultValue: '')?.toString() ?? '';
      if (storedId.isNotEmpty && storedId != 'default_store') {
        return storedId;
      }

      return StoreIdService.getStoreId();
    } catch (e) {
      print('❌ خطأ في جلب storeId: $e');
      return '';
    }
  }

  // الحصول على إيميل المستخدم الحالي مباشرة من فايربيس
  String? get currentUserEmail => FirebaseAuth.instance.currentUser?.email;

  @override
  void onInit() {
    super.onInit();
    loadOrders();
    ever(orders, (_) => updateUnreadCount());
    startListeningToNewOrders();
  }

  void startListeningToNewOrders() {
    final id = storeId;
    if (id.isEmpty) return;

    print('🔔 الاستماع - storeId: $id');

    FirebaseFirestore.instance
        .collection('orders')
        .where('store_id', isEqualTo: id)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      unreadOrdersCount.value = snapshot.docs.length;
      print('📊 طلبات جديدة: ${snapshot.docs.length}');

      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          Get.snackbar(
            '🔔 طلب جديد!',
            '${data!['customerName'] ?? 'عميل'}',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        }
      }
    }, onError: (e) {
      print('❌ خطأ: $e');
    });
  }

  void listenToUnreadOrders(String storeId) {
    FirebaseFirestore.instance
        .collection('orders')
        .where('store_id', isEqualTo: storeId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      unreadOrdersCount.value = snapshot.docs.length;
    });
  }

  void loadOrders() {
    isLoading.value = true;
    final ordersData = _orderBox.values.toList();
    orders.value = ordersData
        .map((json) => Order.fromJson(Map<String, dynamic>.from(json)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    unreadOrdersCount.value = orders.where((o) => !o.isRead).length;

    isLoading.value = false;
  }

  // ✅ دالة addOrder واحدة فقط
  Future<Order> addOrder(Order order, {String? storeId}) async {
    final effectiveStoreId = storeId ?? order.storeId ?? StoreIdService.getStoreId();

    // ✅ رفع مباشر بدون خادم وسيط
    await _uploadOrderToFirebase(order, storeId: effectiveStoreId);
    await _orderBox.put(order.id, order.toJson());
    orders.insert(0, order);
    updateUnreadCount();
    _notifyNewOrder(order);
    return order;
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final order = orders.firstWhere((o) => o.id == orderId);
    final updatedOrder = Order(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      items: order.items,
      totalAmount: order.totalAmount,
      status: newStatus,
      notes: order.notes,
      createdAt: order.createdAt,
      accessMethod: order.accessMethod,
      isRead: true,
      storeId: order.storeId,
      customerToken: order.customerToken,
    );

    await _orderBox.put(orderId, updatedOrder.toJson());
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      orders[index] = updatedOrder;
    }
    orders.refresh();
    updateUnreadCount();

    await _sendNotificationToCustomer(updatedOrder, newStatus);

    await _updateOrderInCloud(updatedOrder);
  }

  Future<void> markAsRead(String orderId) async {
    final order = orders.firstWhere((o) => o.id == orderId);
    if (!order.isRead) {
      final updatedOrder = Order(
        id: order.id,
        customerId: order.customerId,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        items: order.items,
        totalAmount: order.totalAmount,
        status: order.status,
        notes: order.notes,
        createdAt: order.createdAt,
        accessMethod: order.accessMethod,
        isRead: true,
        storeId: order.storeId,
        customerToken: order.customerToken,
      );

      await _orderBox.put(orderId, updatedOrder.toJson());
      final index = orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        orders[index] = updatedOrder;
      }
      updateUnreadCount();
    }
  }

  Future<void> deleteOrder(String orderId) async {
    await _orderBox.delete(orderId);
    orders.removeWhere((o) => o.id == orderId);
    updateUnreadCount();

    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).delete();
    } catch (e) {
      print('❌ خطأ في حذف الطلب من السحابة: $e');
    }
  }

  void updateUnreadCount() {
    unreadOrdersCount.value = orders.where((o) => !o.isRead).length;
  }

  List<Order> getFilteredOrders() {
    if (filterStatus.value == 'all') return orders;
    if (filterStatus.value == 'unread') return orders.where((o) => !o.isRead).toList();
    return orders.where((o) => o.status == filterStatus.value).toList();
  }

  void _notifyNewOrder(Order order) {
    updateUnreadCount();
    Get.snackbar(
      '🔔 طلب جديد!',
      '${order.customerName} طلب ${order.items.length} منتجات بقيمة ${order.totalAmount.toStringAsFixed(2)} ر.س',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF1D325E),
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      isDismissible: true,
      mainButton: TextButton(
        onPressed: () {
          Get.toNamed('/orders');
        },
        child: const Text(
          'عرض',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // ==================== السحابة ====================

  // ✅ رفع مباشر بدون خادم وسيط
  Future<void> _uploadOrderToFirebase(Order order, {String? storeId}) async {
    String? token = await FirebaseMessaging.instance.getToken();

    final id = storeId ?? order.storeId ?? '';

    if (id.isEmpty || id == 'default_store') {
      print('❌ storeId غير صالح أو مفقود ($id)');
      return;
    }

    // ✅ رفع مباشر إلى Firestore (بدون Cloud Functions)
    await FirebaseFirestore.instance.collection('orders').doc(order.id).set({
      'customerId': order.customerId,
      'customerName': order.customerName,
      'customerPhone': order.customerPhone,
      'items': order.items.map((item) => item.toJson()).toList(),
      'totalAmount': order.totalAmount,
      'notes': order.notes ?? '',
      'customerToken': token ?? order.customerToken ?? '',
      'status': 'pending',
      'accessMethod': order.accessMethod,
      'isRead': false,
      'storeId': id,
      'store_id': id,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ✅ إرسال إشعار للعميل مباشرة
    await FirebaseFirestore.instance.collection('notifications').add({
      'customerId': order.customerId,
      'customerPhone': order.customerPhone,
      'title': 'طلب جديد',
      'body': 'تم استلام طلبك بنجاح',
      'isRead': false,
      'store_id': id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('✅ تم رفع الطلب مباشرة - storeId: $id');
  }

  /// ✅ تحديث الطلب في السحابة
  Future<void> _updateOrderInCloud(Order order) async {
    String? token = await FirebaseMessaging.instance.getToken();
    try {
      final id = order.storeId ?? storeId;
      if (id.isEmpty || id == 'default_store') {
        print('❌ storeId غير صالح');
        return;
      }

      await FirebaseFirestore.instance.collection('orders').doc(order.id).set({
        'customerId': order.customerId,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'items': order.items.map((item) => item.toJson()).toList(),
        'totalAmount': order.totalAmount,
        'notes': order.notes ?? '',
        'customerToken': token ?? order.customerToken ?? '',
        'status': order.status,
        'accessMethod': order.accessMethod,
        'isRead': false,
        'storeId': id,
        'store_id': id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  /// ✅ إرسال إشعار للعميل
  Future<void> _sendNotificationToCustomer(Order order, String status) async {
    try {
      String title = '';
      String body = '';

      switch (status) {
        case 'preparing':
          title = 'جاري تجهيز طلبك 🛍️';
          body = 'طلبك قيد التجهيز الآن';
          break;
        case 'ready':
          title = 'طلبك جاهز! 🎉';
          body = 'طلبك جاهز للاستلام. تفضل بزيارتنا';
          break;
        case 'delivered':
          title = 'تم توصيل الطلب ✅';
          body = 'نتمنى أن تستمتع بطلبك';
          break;
        case 'cancelled':
          title = 'تم إلغاء الطلب ❌';
          body = 'تم إلغاء طلبك. للاستفسار تواصل معنا';
          break;
        default:
          title = 'تحديث الطلب';
          body = 'تم تحديث حالة طلبك';
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'customerId': order.customerId,
        'customerPhone': order.customerPhone,
        'title': title,
        'body': body,
        'orderId': order.id,
        'status': status,
        'isRead': false,
        'store_id': storeId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ تم إرسال إشعار للعميل: $title');
    } catch (e) {
      print('❌ خطأ في إرسال الإشعار: $e');
    }
  }
}