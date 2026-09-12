// translation_service.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class TranslationService {
  static const String _languageKey = 'app_language';

  // Arabic translations (default)
  static const Map<String, String> _ar = {
    // General
    'my_store': 'متجري',
    'error': 'خطأ',
    'success': 'تم',
    'notice': 'تنبيه',
    'ok': 'حسناً',
    'cancel': 'إلغاء',
    'save': 'حفظ',
    'yes': 'نعم',
    'no': 'لا',
    'required': 'مطلوب',
    'notification': 'إشعار',
    'notifications': 'الإشعارات',
    'no_notifications': 'لا توجد إشعارات',

    // Login screen
    'shop_easily': 'تسوق بكل سهولة 🛍️',
    'create_account': 'إنشاء حساب',
    'enter_password': 'أدخل كلمة المرور',
    'login': 'تسجيل الدخول',
    'phone_number': 'رقم الهاتف',
    'verify_number': 'تحقق من الرقم',
    'verifying': 'جاري التحقق...',
    'password': 'كلمة المرور',
    'stay_logged_in': 'البقاء متصلاً',
    'name': 'الاسم',
    'enter_store': 'دخول المتجر',
    'change_number': 'تغيير الرقم',
    'welcome': 'مرحباً',
    'complete_registration': 'أكمل إنشاء حسابك',
    'number_registered_complete_data': 'رقمك مسجل. أكمل البيانات.',
    'enter_phone': 'أدخل رقم الهاتف',
    'phone_not_registered': 'رقم الهاتف ليس مسجل',
    'phone_not_in_records': 'هذا الرقم غير موجود في سجل العملاء. تواصل مع صاحب المتجر.',
    'wrong_password': 'كلمة المرور خاطئة',
    'enter_name': 'أدخل الاسم',
    'login_success': 'تم الدخول للمتجر بنجاح',
    'login_failed': 'فشل الدخول',
    'loading_store_data': 'جاري جلب بيانات المتجر...',
    'system_name': 'نظام سوفت',
    'fill_all_fields': 'املأ جميع الحقول',
    'password_too_short': 'كلمة المرور قصيرة',
    'password_mismatch': 'كلمة المرور غير متطابقة',
    'account_exists': 'الحساب موجود مسبقاً',
    'account_created': 'تم إنشاء الحساب بنجاح',
    'password_min_6': 'كلمة المرور (6 أحرف على الأقل)',
    'confirm_password': 'تأكيد كلمة المرور',

    // Shopping screen
    'shop_now': 'تسوق الآن',
    'products_store': 'متجر المنتجات',
    'refresh_data': 'تحديث البيانات',
    'edit_store_id': 'تعديل storeId',
    'logout': 'تسجيل الخروج',
    'confirm_logout': 'هل تريد تسجيل الخروج؟',
    'store_synced': 'المتجر متزامن',
    'store_error': 'يوجد خلل في المتجر',
    'search_product': 'ابحث عن منتج...',
    'list_view': 'عرض قائمة',
    'grid_view': 'عرض شبكي',
    'all_products': 'كل المنتجات',
    'loading_products': 'جاري تحميل المنتجات...',
    'no_results': 'لا توجد نتائج',
    'no_product_match': 'لم نعثر على منتج يطابق بحثك',
    'no_products': 'لا توجد منتجات',
    'products_will_appear': 'ستظهر المنتجات هنا عند إضافتها',
    'product': 'منتج',
    'branches': 'فروع',
    'categories': 'فئات',
    'products': 'منتجات',
    'no_image': 'لا صورة',
    'no_image_available': 'لا توجد صورة',
    'no_description': 'لا يوجد وصف',
    'add': 'أضف',
    'add_to_cart': 'أضف للسلة',
    'added_to_cart': 'تمت الإضافة للسلة',
    'total': 'الإجمالي',

    // Store selection
    'select_store': 'اختر المتجر',
    'phone_registered_in': 'رقم الهاتف مسجل في',
    'stores': 'متاجر',
    'store': 'متجر',
    'have_account_enter_password': 'لديك حساب - أدخل كلمة المرور',
    'complete_account_creation': 'أكمل إنشاء حسابك',

    // Orders
    'new_order': 'طلب جديد 📦',
    'new_order_from': 'طلب جديد من',
    'with_value': 'بقيمة',
    'order_received_with_value': 'تم استلام طلب جديد بقيمة',

    // Store ID editor
    'edit_store_id_hint': 'يمكنك تعديل معرف المتجر (storeId) يدوياً إذا لزم الأمر',
    'enter_store_id': 'أدخل معرف المتجر',
    'store_id_required': 'لا يمكن أن يكون storeId فارغاً',
    'store_id_updated': 'تم تحديث storeId بنجاح',
    'no_store_id': 'لا يوجد معرف للمتجر',
    'updated_products': 'تم تحديث',

    // Contact
    'contact_store_for_new_link': 'هناك خطأ .. يرجى التواصل مع المتجر لتجديد الرابط',
  };

  // English translations
  static const Map<String, String> _en = {
    // General
    'my_store': 'My Store',
    'error': 'Error',
    'success': 'Success',
    'notice': 'Notice',
    'ok': 'OK',
    'cancel': 'Cancel',
    'save': 'Save',
    'yes': 'Yes',
    'no': 'No',
    'required': 'Required',
    'notification': 'Notification',
    'notifications': 'Notifications',
    'no_notifications': 'No notifications',

    // Login screen
    'shop_easily': 'Shop easily 🛍️',
    'create_account': 'Create Account',
    'enter_password': 'Enter Password',
    'login': 'Login',
    'phone_number': 'Phone Number',
    'verify_number': 'Verify Number',
    'verifying': 'Verifying...',
    'password': 'Password',
    'stay_logged_in': 'Stay logged in',
    'name': 'Name',
    'enter_store': 'Enter Store',
    'change_number': 'Change Number',
    'welcome': 'Welcome',
    'complete_registration': 'complete your registration',
    'number_registered_complete_data': 'Your number is registered. Complete your data.',
    'enter_phone': 'Enter phone number',
    'phone_not_registered': 'Phone not registered',
    'phone_not_in_records': 'This number is not in customer records. Contact the store owner.',
    'wrong_password': 'Wrong password',
    'enter_name': 'Enter name',
    'login_success': 'Successfully logged in',
    'login_failed': 'Login failed',
    'loading_store_data': 'Loading store data...',
    'system_name': 'Soft System',
    'fill_all_fields': 'Fill all fields',
    'password_too_short': 'Password is too short',
    'password_mismatch': 'Passwords do not match',
    'account_exists': 'Account already exists',
    'account_created': 'Account created successfully',
    'password_min_6': 'Password (at least 6 characters)',
    'confirm_password': 'Confirm Password',

    // Shopping screen
    'shop_now': 'Shop Now',
    'products_store': 'Products Store',
    'refresh_data': 'Refresh Data',
    'edit_store_id': 'Edit storeId',
    'logout': 'Logout',
    'confirm_logout': 'Do you want to logout?',
    'store_synced': 'Store synced',
    'store_error': 'Store error',
    'search_product': 'Search for product...',
    'list_view': 'List View',
    'grid_view': 'Grid View',
    'all_products': 'All Products',
    'loading_products': 'Loading products...',
    'no_results': 'No results',
    'no_product_match': 'No product matches your search',
    'no_products': 'No products',
    'products_will_appear': 'Products will appear here when added',
    'product': 'product',
    'branches': 'branches',
    'categories': 'categories',
    'products': 'products',
    'no_image': 'No image',
    'no_image_available': 'No image available',
    'no_description': 'No description',
    'add': 'Add',
    'add_to_cart': 'Add to Cart',
    'added_to_cart': 'Added to cart',
    'total': 'Total',

    // Store selection
    'select_store': 'Select Store',
    'phone_registered_in': 'Phone number registered in',
    'stores': 'stores',
    'store': 'Store',
    'have_account_enter_password': 'You have an account - enter password',
    'complete_account_creation': 'Complete your account creation',

    // Orders
    'new_order': 'New Order 📦',
    'new_order_from': 'New order from',
    'with_value': 'with value',
    'order_received_with_value': 'New order received with value',

    // Store ID editor
    'edit_store_id_hint': 'You can edit the store ID manually if needed',
    'enter_store_id': 'Enter store ID',
    'store_id_required': 'storeId cannot be empty',
    'store_id_updated': 'storeId updated successfully',
    'no_store_id': 'No store ID available',
    'updated_products': 'Updated',

    // Contact
    'contact_store_for_new_link': 'There is an error.. please contact the store to renew the link',
  };

  String translate(String key) {
    final language = _getCurrentLanguage();
    final translations = language == 'en' ? _en : _ar;
    return translations[key] ?? key;
  }

  String _getCurrentLanguage() {
    try {
      final settingsBox = Hive.box('settings');
      return settingsBox.get(_languageKey, defaultValue: 'ar')?.toString() ?? 'ar';
    } catch (e) {
      return 'ar';
    }
  }

  void setLanguage(String language) {
    try {
      final settingsBox = Hive.box('settings');
      settingsBox.put(_languageKey, language);
      Get.updateLocale(Locale(language));
    } catch (e) {
      print('Error setting language: $e');
    }
  }

  String getCurrentLanguage() {
    return _getCurrentLanguage();
  }
}