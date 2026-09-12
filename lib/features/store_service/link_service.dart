import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'customer_model.dart'; // ✅ استيراد واحد فقط

class LinkService {
  // ✅ بناء رسالة ترحيب للرابط الخاص
  static String buildWelcomeMessage(Customer customer) {
    return '''
🎉 *مرحباً ${customer.name}*

تم إنشاء متجرك الخاص في نظام سوفت!

📱 *رقم هاتفك:* ${customer.phone}
🏙 *المدينة:* ${customer.city}

🔗 *رابط متجرك الخاص:*
${customer.uniqueLink}

📌 *مميزات الرابط:*
• آمن ومشفر
• مرتبط برقم هاتفك فقط
• صالح لمدة سنة كاملة
• يمكنك الطلب مباشرة من المتجر

⚠️ *ملاحظة هامة:*
هذا الرابط خاص بك ولا يمكن استخدامه من هاتف آخر.

شكراً لثقتكم في نظام سوفت 🙏
''';
  }

  // ✅ بناء رسالة واتساب للرابط الخاص
  static String buildWhatsAppMessage(Customer customer) {
    return '''
🌟 *مرحباً ${customer.name}*

رابط متجرك الخاص جاهز! 🎉

🔗 ${customer.uniqueLink}

📱 فقط افتح الرابط من هاتفك ${customer.phone}
🛒 وابدأ التسوق الآن!
''';
  }

  // ✅ بناء رسالة الاعتمادات
  static String buildCredentialsMessage(Customer customer, String password) {
    return '''
🎉 *مرحباً ${customer.name}*

تم إنشاء حسابك في متجر نظام سوفت!

📱 *رقم الهاتف:* ${customer.phone}
🔑 *كلمة المرور:* $password

📌 *للدخول إلى متجرك:*
1. افتح تطبيق نظام سوفت
2. اختر "خدمة متجري"
3. سجل الدخول برقم هاتفك وكلمة المرور

⚠️ *ملاحظة هامة:*
يرجى تغيير كلمة المرور بعد أول دخول

شكراً لثقتكم في نظام سوفت 🙏
''';
  }

  // ✅ مشاركة الرابط عبر واتساب
  static Future<void> shareViaWhatsApp(Customer customer) async {
    final message = buildWhatsAppMessage(customer);
    final phone = customer.phone.replaceAll(RegExp(r'[^\d]'), '');
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'خطأ',
          'لا يمكن فتح واتساب',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء المشاركة',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ✅ مشاركة مخصصة عبر واتساب
  static Future<void> shareViaWhatsAppCustom(String phone, String message) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'خطأ',
          'لا يمكن فتح واتساب',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء المشاركة',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ✅ مشاركة الرابط بشكل عام
  static Future<void> shareLink(Customer customer) async {
    final message = buildWelcomeMessage(customer);
    await Share.share(
      message,
      subject: 'رابط متجرك الخاص - ${customer.name}',
    );
  }

  // ✅ نسخ الرابط إلى الحافظة
  static void copyLink(Customer customer) {
    Clipboard.setData(ClipboardData(text: customer.uniqueLink));
    Get.snackbar(
      'تم النسخ',
      'تم نسخ الرابط إلى الحافظة',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  // ✅ نسخ النص إلى الحافظة
  static void copyText(String text, {String message = 'تم النسخ'}) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      message,
      '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  // ✅ تجديد الرابط
  static Future<String> renewLink(Customer customer) async {
    final newLink = Customer.generateUniqueLink(
      customer.phone,
      '${customer.id}_${DateTime.now().millisecondsSinceEpoch}',
    );
    return newLink;
  }

  // ✅ إبطال الرابط
  static String revokeLink(Customer customer) {
    return '${customer.uniqueLink}/revoked/${DateTime.now().millisecondsSinceEpoch}';
  }
}