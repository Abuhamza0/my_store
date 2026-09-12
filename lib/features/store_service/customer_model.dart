import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String password;
  final String address;
  final String city;
  final String notes;
  final double totalPurchases;
  final int orderCount;
  final DateTime createdAt;
  final DateTime lastOrderDate;
  final String? profileImagePath;
  final bool isActive;
  final String uniqueLink;
  final String encryptedPhone;
  final String? deviceFingerprint;
  final DateTime? linkExpiryDate;
  final String loginMethod;
  final DateTime? lastActive;
  final String? storeId; // ✅ إضافة store_id (uid)

  Customer({
    String? id,
    required this.name,
    required this.phone,
    this.email = '',
    this.password = '',
    this.address = '',
    this.city = '',
    this.notes = '',
    this.totalPurchases = 0.0,
    this.orderCount = 0,
    DateTime? createdAt,
    DateTime? lastOrderDate,
    this.profileImagePath,
    this.isActive = true,
    String? uniqueLink,
    String? encryptedPhone,
    this.deviceFingerprint,
    DateTime? linkExpiryDate,
    this.loginMethod = 'credentials',
    this.lastActive,
    this.storeId, // ✅ إضافة
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        lastOrderDate = lastOrderDate ?? DateTime.now(),
        encryptedPhone = encryptedPhone ?? _encryptPhone(phone),
        uniqueLink = uniqueLink ?? generateUniqueLink(phone, id ?? DateTime.now().millisecondsSinceEpoch.toString()),
        linkExpiryDate = linkExpiryDate ?? DateTime.now().add(const Duration(days: 365));

  // ==================== دوال التشفير ====================

  static String _encryptPhone(String phone) {
    try {
      final bytes = utf8.encode('${phone}_${DateTime.now().millisecondsSinceEpoch}');
      return base64Encode(bytes);
    } catch (e) {
      return base64Encode(utf8.encode(phone));
    }
  }

  static String decryptPhone(String encryptedPhone) {
    try {
      final bytes = base64Decode(encryptedPhone);
      final decoded = utf8.decode(bytes);
      if (decoded.contains('_')) {
        return decoded.split('_')[0];
      }
      return decoded;
    } catch (e) {
      return '';
    }
  }

  static String hashPassword(String password) {
    if (password.isEmpty) return '';
    final bytes = utf8.encode('NithamSoft_Salt_$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool verifyPassword(String inputPassword) {
    if (password.isEmpty || inputPassword.isEmpty) return false;
    final hashedInput = hashPassword(inputPassword);
    return hashedInput == password;
  }

  // ✅ دالة عامة لتوليد الرابط الفريد
  static String generateUniqueLink(String phone, String id) {
    const baseUrl = 'nithamsoft://store/customer';
    final encodedPhone = base64Encode(utf8.encode(phone));
    final uniqueCode = _generateUniqueCode(id);
    return '$baseUrl/$encodedPhone/$uniqueCode';
  }

  static String? extractPhoneFromLink(String link) {
    try {
      final uri = Uri.parse(link);
      final segments = uri.pathSegments;
      if (segments.length >= 3 && segments[0] == 'store' && segments[1] == 'customer') {
        final encodedPhone = segments[2];
        final bytes = base64Decode(encodedPhone);
        return utf8.decode(bytes);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Customer copyWith({DateTime? lastActive, String? storeId}) {
    return Customer(
      id: id,
      name: name,
      phone: phone,
      email: email,
      password: password,
      address: address,
      city: city,
      notes: notes,
      totalPurchases: totalPurchases,
      orderCount: orderCount,
      createdAt: createdAt,
      lastOrderDate: lastOrderDate,
      isActive: isActive,
      loginMethod: loginMethod,
      lastActive: lastActive ?? this.lastActive,
      storeId: storeId ?? this.storeId, // ✅ إضافة
    );
  }

  // ✅ دالة خاصة لتوليد الكود الفريد
  static String _generateUniqueCode(String id) {
    final key = utf8.encode('NithamSoft_Secret_Key_2024');
    final message = utf8.encode('$id${DateTime.now().millisecondsSinceEpoch}');
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(message);
    return digest.toString().substring(0, 16);
  }

  String get phoneForLogin => decryptPhone(encryptedPhone);

  bool isLinkValid() {
    if (loginMethod != 'link') return false;
    return linkExpiryDate != null &&
        linkExpiryDate!.isAfter(DateTime.now()) &&
        isActive;
  }

  String get expiryDateText {
    if (linkExpiryDate == null) return 'غير محدد';
    final remaining = linkExpiryDate!.difference(DateTime.now());
    if (remaining.isNegative) return 'منتهي الصلاحية';

    final days = remaining.inDays;
    if (days > 30) {
      return '${(days / 30).floor()} شهر';
    } else if (days > 0) {
      return '$days يوم';
    } else {
      final hours = remaining.inHours;
      return '$hours ساعة';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'address': address,
      'city': city,
      'notes': notes,
      'totalPurchases': totalPurchases,
      'orderCount': orderCount,
      'createdAt': createdAt.toIso8601String(),
      'lastOrderDate': lastOrderDate.toIso8601String(),
      'profileImagePath': profileImagePath,
      'isActive': isActive,
      'uniqueLink': uniqueLink,
      'encryptedPhone': encryptedPhone,
      'deviceFingerprint': deviceFingerprint,
      'linkExpiryDate': linkExpiryDate?.toIso8601String(),
      'loginMethod': loginMethod,
      'lastActive': lastActive?.toIso8601String(),
      'store_id': storeId, // ✅ حفظ store_id
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    // ✅ دالة مساعدة لتحويل التواريخ سواء كانت String أو Timestamp
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      lastOrderDate: parseDate(json['lastOrderDate']) ?? DateTime.now(),
      profileImagePath: json['profileImagePath']?.toString(),
      isActive: json['isActive'] ?? true,
      uniqueLink: json['uniqueLink']?.toString() ?? '',
      encryptedPhone: json['encryptedPhone']?.toString() ?? '',
      deviceFingerprint: json['deviceFingerprint']?.toString(),
      linkExpiryDate: parseDate(json['linkExpiryDate']),
      loginMethod: json['loginMethod']?.toString() ?? 'credentials',
      lastActive: parseDate(json['lastActive']),
      storeId: json['store_id']?.toString() ?? json['storeId']?.toString(), // ✅ قراءة store_id
    );
  }
}