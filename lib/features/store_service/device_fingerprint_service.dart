import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class DeviceFingerprintService {
  static Future<String> getDeviceFingerprint() async {
    try {
      String fingerprint = '';

      if (Platform.isAndroid) {
        fingerprint = _generateFingerprint([
          'android',
          DateTime.now().millisecondsSinceEpoch.toString(),
          Platform.operatingSystemVersion,
        ]);
      } else if (Platform.isIOS) {
        fingerprint = _generateFingerprint([
          'ios',
          DateTime.now().millisecondsSinceEpoch.toString(),
          Platform.operatingSystemVersion,
        ]);
      } else {
        fingerprint = _generateFingerprint([
          'web',
          DateTime.now().millisecondsSinceEpoch.toString(),
        ]);
      }

      return fingerprint;
    } catch (e) {
      debugPrint('Error getting device fingerprint: $e');
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  static String _generateFingerprint(List<String> values) {
    final combined = values.join('|');
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<bool> verifyDeviceFingerprint(String storedFingerprint) async {
    if (storedFingerprint.isEmpty) return true;
    final currentFingerprint = await getDeviceFingerprint();
    return currentFingerprint == storedFingerprint;
  }

  static Future<Map<String, String>> getDeviceInfo() async {
    return {
      'النوع': Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Web'),
      'الموديل': 'جهاز ${Platform.operatingSystem}',
      'النظام': Platform.operatingSystemVersion,
      'المعرف': 'محلي',
    };
  }
}

int min(int a, int b) => a < b ? a : b;