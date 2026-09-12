import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../services/cloud_service.dart';

class UserStatsController extends GetxController {
  final userCount = 0.obs;
  final productCount = 0.obs;
  final orderCount = 0.obs;
  final activeUserCount = 0.obs;
  final totalSales = 0.0.obs;
  final activeLinksCount = 0.obs;
  final isLoading = true.obs;

  // للحصول على CloudService instance
  CloudService get _cloudService => CloudService.to;

  @override
  void onInit() {
    super.onInit();
    loadAllStats();
    listenToFirestoreChanges();
  }

  /// ✅ تحميل جميع الإحصائيات مرة واحدة
  Future<void> loadAllStats() async {
    isLoading.value = true;
    try {
      // استخدام CloudService.to لاستدعاء الدوال
      final results = await Future.wait([
        _cloudService.getUserCount(),
        _cloudService.getProductCount(),
        _cloudService.getOrderCount(),
        _cloudService.getActiveUserCount(),
        _cloudService.getTotalSales(),
        _cloudService.getActiveLinksCount(),
      ]);

      userCount.value = results[0] as int;
      productCount.value = results[1] as int;
      orderCount.value = results[2] as int;
      activeUserCount.value = results[3] as int;
      totalSales.value = results[4] as double;
      activeLinksCount.value = results[5] as int;
    } catch (e) {
      print("❌ Error loading stats: $e");
      // تحميل البيانات المحلية كاحتياط
      loadLocalStats();
    } finally {
      isLoading.value = false;
    }
  }

  /// ✅ تحميل عدد المستخدمين فقط
  Future<void> loadUserCount() async {
    try {
      int count = await _cloudService.getUserCount();
      userCount.value = count;
    } catch (e) {
      print("❌ Error loading user count: $e");
    }
  }

  /// ✅ تحميل عدد المنتجات فقط
  Future<void> loadProductCount() async {
    try {
      int count = await _cloudService.getProductCount();
      productCount.value = count;
    } catch (e) {
      print("❌ Error loading product count: $e");
    }
  }

  /// ✅ تحميل عدد الطلبات فقط
  Future<void> loadOrderCount() async {
    try {
      int count = await _cloudService.getOrderCount();
      orderCount.value = count;
    } catch (e) {
      print("❌ Error loading order count: $e");
    }
  }

  /// ✅ استماع مباشر للتغييرات في Firestore
  void listenToFirestoreChanges() {
    // استماع لتغييرات المستخدمين
    FirebaseFirestore.instance.collection('customers').snapshots().listen((snapshot) {
      userCount.value = snapshot.docs.length;
      isLoading.value = false;
    });

    // استماع لتغييرات المنتجات
    FirebaseFirestore.instance.collection('products').snapshots().listen((snapshot) {
      productCount.value = snapshot.docs.length;
    });

    // استماع لتغييرات الطلبات
    FirebaseFirestore.instance.collection('orders').snapshots().listen((snapshot) {
      orderCount.value = snapshot.docs.length;
    });

    // استماع لتغييرات الروابط النشطة
    FirebaseFirestore.instance
        .collection('store_links')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      activeLinksCount.value = snapshot.docs.length;
    });
  }

  /// ✅ تحميل الإحصائيات المحلية (احتياطي عند فشل الاتصال)
  void loadLocalStats() {
    try {
      // يمكنك استخدام Hive هنا للحصول على البيانات المحلية
      // هذا مجرد مثال
      print("📦 Loading local stats...");
    } catch (e) {
      print("❌ Error loading local stats: $e");
    }
  }

  /// ✅ تحديث جميع الإحصائيات
  Future<void> refreshAllStats() async {
    await loadAllStats();
  }

  /// ✅ الحصول على ملخص الإحصائيات
  Map<String, dynamic> getStatsSummary() {
    return {
      'userCount': userCount.value,
      'productCount': productCount.value,
      'orderCount': orderCount.value,
      'activeUserCount': activeUserCount.value,
      'totalSales': totalSales.value,
      'activeLinksCount': activeLinksCount.value,
    };
  }

}