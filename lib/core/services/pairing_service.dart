import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PairingService {
  static String generatePairingCode() {
    final random = Random();
    return '${random.nextInt(900000) + 100000}';
  }

  static Future<String> createPairingCode(String storeId, String deviceId) async {
    final code = generatePairingCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    await FirebaseFirestore.instance
        .collection('store_devices')
        .doc(storeId)
        .collection('pairing_codes')
        .doc(code)
        .set({
      'store_id': storeId,
      'created_by_device': deviceId,
      'expires_at': Timestamp.fromDate(expiresAt),
      'used': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    return code;
  }

  static Future<bool> verifyPairingCode(String code, String storeId, String deviceId) async {
    final cleanCode = code.trim().replaceAll('\n', '').replaceAll('\r', '');

    debugPrint('🔍 Attempting verification: code="$cleanCode", storeId="$storeId", scanningDeviceId="$deviceId"');

    final docRef = FirebaseFirestore.instance
        .collection('store_devices')
        .doc(storeId)
        .collection('pairing_codes')
        .doc(cleanCode);

    final doc = await docRef.get();

    if (!doc.exists || doc.data() == null) {
      debugPrint('❌ Verification Failed: Code doc does not exist on path');
      return false;
    }

    final data = doc.data()!;
    debugPrint('📄 Found Doc Data: $data');

    if (data['used'] == true) {
      debugPrint('❌ Verification Failed: Code is already used');
      return false;
    }

    if (data['store_id'] != storeId) {
      debugPrint('❌ Verification Failed: store_id mismatch (${data['store_id']} vs $storeId)');
      return false;
    }

    final expiresAt = (data['expires_at'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) {
      debugPrint('❌ Verification Failed: Code expired at $expiresAt');
      return false;
    }

    // إضافة الجهاز الجديد القادم من الكاميرا إلى قائمة الأجهزة الموثوقة
    await FirebaseFirestore.instance
        .collection('store_devices')
        .doc(storeId)
        .collection('trusted_devices')
        .doc(deviceId)
        .set({
      'device_id': deviceId,
      'trusted_at': FieldValue.serverTimestamp(),
      'last_active': FieldValue.serverTimestamp(),
    });

    await docRef.update({'used': true});
    debugPrint('✅ Verification Successful!');
    return true;
  }

  static Future<bool> isDeviceTrusted(String storeId, String deviceId) async {
    final doc = await FirebaseFirestore.instance
        .collection('store_devices')
        .doc(storeId)
        .collection('trusted_devices')
        .doc(deviceId)
        .get();
    return doc.exists;
  }
}