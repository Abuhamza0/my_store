import 'dart:ui';

import 'package:get/get.dart';

class LocaleService {
  static final RxString current = Get.locale?.languageCode.obs ?? 'ar'.obs;

  static void changeLocale(String languageCode) {
    Get.updateLocale(Locale(languageCode));
    current.value = languageCode;
  }
}