// lib/services/subscription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

/// خدمة إدارة الاشتراكات والباقات
class SubscriptionService extends GetxService {
  // ==================== 🔥 Firestore ====================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== 📦 Hive Box ====================
  late Box _subscriptionBox;

  // ==================== 🎯 Singleton ====================
  static SubscriptionService get to => Get.find<SubscriptionService>();

  // ==================== 📊 المتغيرات المراقبة ====================
  final RxString currentPlan = 'basic'.obs; // basic, pro, enterprise
  final RxBool isSubscribed = false.obs;
  final Rx<DateTime?> expiryDate = Rx<DateTime?>(null);
  final RxInt remainingDays = 0.obs;

  // ==================== 🚀 التهيئة ====================
  @override
  void onInit() {
    super.onInit();
    _initBox();
    _loadLocalSubscription();
    debugPrint('✅ SubscriptionService تم تهيئته بنجاح');
  }

  /// تهيئة صندوق Hive
  void _initBox() {
    try {
      _subscriptionBox = Hive.box('subscription');
    } catch (e) {
      debugPrint('❌ فشل فتح صندوق الاشتراكات: $e');
    }
  }

  /// تحميل بيانات الاشتراك المحفوظة محلياً
  void _loadLocalSubscription() {
    try {
      final plan = _subscriptionBox.get('plan', defaultValue: 'basic');
      final subscribed = _subscriptionBox.get('is_subscribed', defaultValue: false);
      final expiryStr = _subscriptionBox.get('expiry_date');
      final remaining = _subscriptionBox.get('remaining_days', defaultValue: 0);

      currentPlan.value = plan;
      isSubscribed.value = subscribed;
      if (expiryStr != null) {
        expiryDate.value = DateTime.tryParse(expiryStr);
      }
      remainingDays.value = remaining;
    } catch (e) {
      debugPrint('❌ فشل تحميل الاشتراك المحلي: $e');
    }
  }
  /// تفعيل النسخة التجريبية المجانية (14 يوماً)
  Future<bool> initTrial({required String userId}) async {
    try {
      final now = DateTime.now();
      final trialExpiry = now.add(const Duration(days: 14)); // 14 يوم تجريبي

      // ✅ حفظ في السحابة
      await _firestore.collection('users').doc(userId).collection('subscriptions').add({
        'plan': 'trial',
        'price': 0,
        'currency': 'USD',
        'payment_method': 'trial',
        'start_date': Timestamp.fromDate(now),
        'expiry_date': Timestamp.fromDate(trialExpiry),
        'duration_days': 14,
        'status': 'active',
        'is_trial': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      // ✅ تحديث حالة المستخدم
      await _firestore.collection('users').doc(userId).update({
        'plan': 'trial',
        'is_subscribed': true,
        'is_trial': true,
        'subscription_expiry': Timestamp.fromDate(trialExpiry),
      });

      // ✅ حفظ محلياً
      await _saveLocalSubscription(
        plan: 'trial',
        isSubscribed: true,
        expiryDate: trialExpiry,
        remainingDays: 14,
      );

      debugPrint('✅ تم تفعيل النسخة التجريبية للمستخدم $userId');
      return true;
    } catch (e) {
      debugPrint('❌ فشل تفعيل النسخة التجريبية: $e');
      return false;
    }
  }

  /// التحقق مما إذا كان المستخدم قد استخدم النسخة التجريبية مسبقاً
  Future<bool> hasUsedTrial({required String userId}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('is_trial', isEqualTo: true)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ فشل التحقق من النسخة التجريبية: $e');
      // في حالة الخطأ، نفترض أنه لم يستخدمها (للسماح بالدخول)
      return false;
    }
  }

  /// التحقق من صلاحية النسخة التجريبية
  Future<bool> isTrialValid({required String userId}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('is_trial', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return false;

      final trialData = querySnapshot.docs.first.data();
      final expiryTimestamp = trialData['expiry_date'] as Timestamp?;

      if (expiryTimestamp == null) return false;

      return expiryTimestamp.toDate().isAfter(DateTime.now());
    } catch (e) {
      debugPrint('❌ فشل التحقق من صلاحية التجربة: $e');
      return false;
    }
  }

  /// الحصول على الأيام المتبقية في النسخة التجريبية
  Future<int> getTrialRemainingDays({required String userId}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('is_trial', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return 0;

      final trialData = querySnapshot.docs.first.data();
      final expiryTimestamp = trialData['expiry_date'] as Timestamp?;

      if (expiryTimestamp == null) return 0;

      final remaining = expiryTimestamp.toDate().difference(DateTime.now()).inDays;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      debugPrint('❌ فشل جلب أيام التجربة المتبقية: $e');
      return 0;
    }
  }

  // ==================== 💳 دوال الاشتراك ====================

  /// تفعيل اشتراك جديد
  Future<bool> activateSubscription({
    required String userId,
    required String plan,
    required int durationMonths,
    required double price,
    String? currency,
    String? paymentMethod,
  }) async {
    try {
      final now = DateTime.now();
      final expiry = now.add(Duration(days: durationMonths * 30));

      // ✅ حفظ في السحابة
      await _firestore.collection('users').doc(userId).collection('subscriptions').add({
        'plan': plan,
        'price': price,
        'currency': currency ?? 'USD',
        'payment_method': paymentMethod ?? 'card',
        'start_date': Timestamp.fromDate(now),
        'expiry_date': Timestamp.fromDate(expiry),
        'duration_months': durationMonths,
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
      });

      // ✅ تحديث حالة المستخدم
      await _firestore.collection('users').doc(userId).update({
        'plan': plan,
        'is_subscribed': true,
        'subscription_expiry': Timestamp.fromDate(expiry),
      });

      // ✅ حفظ محلياً
      await _saveLocalSubscription(
        plan: plan,
        isSubscribed: true,
        expiryDate: expiry,
        remainingDays: durationMonths * 30,
      );

      debugPrint('✅ تم تفعيل اشتراك $plan للمستخدم $userId');
      return true;
    } catch (e) {
      debugPrint('❌ فشل تفعيل الاشتراك: $e');
      return false;
    }
  }

  /// تجديد الاشتراك الحالي
  Future<bool> renewSubscription({
    required String userId,
    required int durationMonths,
    required double price,
  }) async {
    try {
      final now = DateTime.now();
      final currentExpiry = expiryDate.value ?? now;
      final newExpiry = currentExpiry.add(Duration(days: durationMonths * 30));

      // ✅ تحديث في السحابة
      final subscriptions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (subscriptions.docs.isNotEmpty) {
        await subscriptions.docs.first.reference.update({
          'expiry_date': Timestamp.fromDate(newExpiry),
          'renewed_at': FieldValue.serverTimestamp(),
        });
      }

      // ✅ تحديث المستخدم
      await _firestore.collection('users').doc(userId).update({
        'subscription_expiry': Timestamp.fromDate(newExpiry),
      });

      // ✅ تحديث محلي
      final remaining = newExpiry.difference(now).inDays;
      await _saveLocalSubscription(
        plan: currentPlan.value,
        isSubscribed: true,
        expiryDate: newExpiry,
        remainingDays: remaining,
      );

      debugPrint('✅ تم تجديد الاشتراك للمستخدم $userId');
      return true;
    } catch (e) {
      debugPrint('❌ فشل تجديد الاشتراك: $e');
      return false;
    }
  }

  /// إلغاء الاشتراك
  Future<bool> cancelSubscription({required String userId}) async {
    try {
      // ✅ تحديث السحابة
      await _firestore.collection('users').doc(userId).update({
        'is_subscribed': false,
        'plan': 'free',
        'subscription_expiry': null,
      });

      // ✅ تحديث الاشتراكات النشطة
      final subscriptions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in subscriptions.docs) {
        await doc.reference.update({
          'status': 'cancelled',
          'cancelled_at': FieldValue.serverTimestamp(),
        });
      }

      // ✅ تحديث محلي
      await _saveLocalSubscription(
        plan: 'free',
        isSubscribed: false,
        expiryDate: null,
        remainingDays: 0,
      );

      debugPrint('✅ تم إلغاء اشتراك المستخدم $userId');
      return true;
    } catch (e) {
      debugPrint('❌ فشل إلغاء الاشتراك: $e');
      return false;
    }
  }

  /// التحقق من صلاحية الاشتراك
  Future<bool> checkSubscriptionValidity({required String userId}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final isSubscribed = userData['is_subscribed'] as bool? ?? false;
      final expiryTimestamp = userData['subscription_expiry'] as Timestamp?;

      if (!isSubscribed || expiryTimestamp == null) {
        await _saveLocalSubscription(
          plan: 'free',
          isSubscribed: false,
          expiryDate: null,
          remainingDays: 0,
        );
        return false;
      }

      final expiry = expiryTimestamp.toDate();
      final isValid = expiry.isAfter(DateTime.now());

      if (!isValid) {
        // انتهى الاشتراك
        await _firestore.collection('users').doc(userId).update({
          'is_subscribed': false,
          'plan': 'free',
        });
        await _saveLocalSubscription(
          plan: 'free',
          isSubscribed: false,
          expiryDate: expiry,
          remainingDays: 0,
        );
      }

      return isValid;
    } catch (e) {
      debugPrint('❌ فشل التحقق من صلاحية الاشتراك: $e');
      return isSubscribed.value;
    }
  }

  /// حساب الأيام المتبقية
  int calculateRemainingDays() {
    if (expiryDate.value == null) return 0;
    final remaining = expiryDate.value!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  // ==================== 📋 دوال الباقات ====================

  /// الحصول على الباقات المتاحة
  List<Map<String, dynamic>> getAvailablePlans({String? currency}) {
    final isSAR = currency == 'SAR';
    return [
      {
        'name': 'الأساسية',
        'id': 'basic',
        'price_monthly': isSAR ? 149 : 39,
        'price_yearly': isSAR ? 1499 : 390,
        'users': 5,
        'projects': 10,
        'storage': '2 جيجابايت',
        'support': 'بريد إلكتروني',
        'features': ['5 مستخدمين', '10 مشاريع', '2 جيجابايت تخزين', 'دعم عبر البريد الإلكتروني'],
        'is_popular': false,
      },
      {
        'name': 'المتقدمة',
        'id': 'pro',
        'price_monthly': isSAR ? 299 : 79,
        'price_yearly': isSAR ? 2999 : 790,
        'users': 25,
        'projects': 50,
        'storage': '10 جيجابايت',
        'support': 'دعم فوري',
        'features': ['25 مستخدم', '50 مشروع', '10 جيجابايت تخزين', 'دعم فوري', 'تقارير متقدمة'],
        'is_popular': true,
      },
      {
        'name': 'المؤسسات',
        'id': 'enterprise',
        'price_monthly': isSAR ? 599 : 159,
        'price_yearly': isSAR ? 5999 : 1590,
        'users': -1, // غير محدود
        'projects': -1,
        'storage': '50 جيجابايت',
        'support': 'مدير حساب مخصص',
        'features': ['مستخدمين غير محدود', 'مشاريع غير محدودة', '50 جيجابايت تخزين', 'دعم مخصص', 'تكامل مخصص', 'مدير حساب خاص'],
        'is_popular': false,
      },
    ];
  }

  /// الحصول على تفاصيل باقة معينة
  Map<String, dynamic>? getPlanDetails(String planId, {String? currency}) {
    final plans = getAvailablePlans(currency: currency);
    try {
      return plans.firstWhere((plan) => plan['id'] == planId);
    } catch (e) {
      return null;
    }
  }

  /// التحقق من إمكانية الوصول لميزة معينة
  bool canAccessFeature(String feature) {
    if (!isSubscribed.value) return false;

    final planDetails = getPlanDetails(currentPlan.value);
    if (planDetails == null) return false;

    final features = planDetails['features'] as List<String>? ?? [];
    return features.contains(feature);
  }

  /// الحصول على الحد الأقصى للمستخدمين
  int getMaxUsers() {
    final planDetails = getPlanDetails(currentPlan.value);
    if (planDetails == null) return 0;
    return planDetails['users'] as int? ?? 0;
  }

  /// الحصول على الحد الأقصى للمشاريع
  int getMaxProjects() {
    final planDetails = getPlanDetails(currentPlan.value);
    if (planDetails == null) return 0;
    return planDetails['projects'] as int? ?? 0;
  }

  // ==================== 📊 دوال الإحصائيات ====================

  /// جلب إحصائيات الاشتراكات (للمدير)
  Future<Map<String, dynamic>> getSubscriptionStats() async {
    try {
      final stats = await _firestore.collection('stats').doc('subscriptions').get();
      return stats.data() ?? {};
    } catch (e) {
      debugPrint('❌ فشل جلب إحصائيات الاشتراكات: $e');
      return {};
    }
  }

  /// جلب جميع المشتركين النشطين
  Future<List<QueryDocumentSnapshot>> getActiveSubscribers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('is_subscribed', isEqualTo: true)
          .get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('❌ فشل جلب المشتركين النشطين: $e');
      return [];
    }
  }

  // ==================== 💾 دوال الحفظ المحلي ====================

  /// حفظ بيانات الاشتراك محلياً في Hive
  Future<void> _saveLocalSubscription({
    required String plan,
    required bool isSubscribed,
    DateTime? expiryDate,
    required int remainingDays,
  }) async {
    try {
      await _subscriptionBox.put('plan', plan);
      await _subscriptionBox.put('is_subscribed', isSubscribed);
      if (expiryDate != null) {
        await _subscriptionBox.put('expiry_date', expiryDate.toIso8601String());
      } else {
        await _subscriptionBox.delete('expiry_date');
      }
      await _subscriptionBox.put('remaining_days', remainingDays);

      // ✅ تحديث المتغيرات المراقبة
      currentPlan.value = plan;
      this.isSubscribed.value = isSubscribed;
      this.expiryDate.value = expiryDate;
      this.remainingDays.value = remainingDays;
    } catch (e) {
      debugPrint('❌ فشل حفظ الاشتراك محلياً: $e');
    }
  }

  /// مسح بيانات الاشتراك المحلية
  Future<void> clearLocalSubscription() async {
    try {
      await _subscriptionBox.delete('plan');
      await _subscriptionBox.delete('is_subscribed');
      await _subscriptionBox.delete('expiry_date');
      await _subscriptionBox.delete('remaining_days');

      currentPlan.value = 'free';
      isSubscribed.value = false;
      expiryDate.value = null;
      remainingDays.value = 0;
    } catch (e) {
      debugPrint('❌ فشل مسح الاشتراك المحلي: $e');
    }
  }

  // ==================== 🔄 دوال الترقية ====================

  /// الترقية من باقة إلى أخرى
  Future<bool> upgradePlan({
    required String userId,
    required String newPlan,
    required int durationMonths,
    required double price,
    String? paymentMethod,
  }) async {
    try {
      // ✅ إلغاء الاشتراك الحالي
      await cancelSubscription(userId: userId);

      // ✅ تفعيل الاشتراك الجديد
      final success = await activateSubscription(
        userId: userId,
        plan: newPlan,
        durationMonths: durationMonths,
        price: price,
        paymentMethod: paymentMethod,
      );

      if (success) {
        debugPrint('✅ تمت الترقية من ${currentPlan.value} إلى $newPlan');
      }

      return success;
    } catch (e) {
      debugPrint('❌ فشلت الترقية: $e');
      return false;
    }
  }

  /// الحصول على سعر الترقية (الفرق بين الباقتين)
  double? getUpgradePrice({
    required String currentPlanId,
    required String newPlanId,
    required int durationMonths,
    String? currency,
  }) {
    final currentPlanDetails = getPlanDetails(currentPlanId, currency: currency);
    final newPlanDetails = getPlanDetails(newPlanId, currency: currency);

    if (currentPlanDetails == null || newPlanDetails == null) return null;

    final currentPrice = (currentPlanDetails['price_monthly'] as num).toDouble();
    final newPrice = (newPlanDetails['price_monthly'] as num).toDouble();
    final difference = newPrice - currentPrice;

    return difference > 0 ? difference * durationMonths : 0;
  }

  // ==================== 🎁 دوال المكافآت ====================

  /// منح أيام مجانية
  Future<bool> grantFreeDays({
    required String userId,
    required int days,
  }) async {
    try {
      final now = DateTime.now();
      final currentExpiry = expiryDate.value ?? now;
      final newExpiry = currentExpiry.add(Duration(days: days));

      await _firestore.collection('users').doc(userId).update({
        'subscription_expiry': Timestamp.fromDate(newExpiry),
      });

      await _saveLocalSubscription(
        plan: currentPlan.value,
        isSubscribed: true,
        expiryDate: newExpiry,
        remainingDays: newExpiry.difference(now).inDays,
      );

      debugPrint('✅ تم منح $days يوم مجاني للمستخدم $userId');
      return true;
    } catch (e) {
      debugPrint('❌ فشل منح أيام مجانية: $e');
      return false;
    }
  }
}

// دالة مساعدة للطباعة
void debugPrint(String message) {
  print(message);
}