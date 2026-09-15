// device_guard.dart
import 'package:hive/hive.dart';

class DeviceGuard {
  /// الحصول على معرّف الجهاز الحالي
  static String get deviceId =>
      Hive.box('settings').get('device_id', defaultValue: '')?.toString() ?? '';

  /// إضافة deviceId إلى أي Map قبل الرفع
  static Map<String, dynamic> stamp(Map<String, dynamic> data) {
    return {
      ...data,
      'deviceId': deviceId,
    };
  }
}