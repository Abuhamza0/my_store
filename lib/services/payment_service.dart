import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PaymentService {
  /// دفع ببطاقة ائتمان
  static Future<bool> payWithCard({
    required BuildContext context,
    required double amount,
    required String currency,
  }) async {
    if (kIsWeb) {
      // ✅ على الويب - دفع وهمي للتجربة
      savePaymentRecord(amount: amount, method: 'بطاقة ائتمان', status: 'ناجح (ويب - تجريبي)');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم الدفع بنجاح (تجريبي على الويب)'), backgroundColor: Colors.green),
        );
      }
      return true;
    }

    // ✅ على الأجهزة الحقيقية - Stripe
    try {
      // ... كود Stripe هنا
      savePaymentRecord(amount: amount, method: 'بطاقة ائتمان', status: 'ناجح');
      return true;
    } catch (e) {
      savePaymentRecord(amount: amount, method: 'بطاقة ائتمان', status: 'فشل', error: e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الدفع: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// ✅ حفظ سجل الدفع
  static void savePaymentRecord({
    required double amount,
    required String method,
    required String status,
    String? error,
  }) {
    final paymentsBox = Hive.box('payments');
    paymentsBox.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'amount': amount,
      'currency': 'SAR',
      'method': method,
      'status': status,
      'error': error,
    });
  }

  /// تفعيل الاشتراك بعد الدفع
  static void activateSubscription(String method) {
    final subscriptionBox = Hive.box('subscription');
    subscriptionBox.put('isSubscribed', true);
    subscriptionBox.put('subscriptionDate', DateTime.now().toIso8601String());
    subscriptionBox.put('expiryDate', DateTime.now().add(const Duration(days: 365)).toIso8601String());
    subscriptionBox.put('paymentMethod', method);
    subscriptionBox.put('lastPaymentAmount', 5.0);
    subscriptionBox.put('lastPaymentDate', DateTime.now().toIso8601String());
  }

  static bool isSubscribed() {
    final subscriptionBox = Hive.box('subscription');
    final isSubscribed = subscriptionBox.get('isSubscribed', defaultValue: false);
    if (!isSubscribed) return false;
    final expiryDate = DateTime.parse(subscriptionBox.get('expiryDate'));
    return DateTime.now().isBefore(expiryDate);
  }
}