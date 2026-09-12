import 'package:flutter/material.dart';

class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double total;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Order {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final double totalAmount;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final String accessMethod;
  final bool isRead;
  final String? storeId; // ✅ إضافة storeId
  final String? customerToken; // ✅ إضافة customerToken

  Order({
    String? id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totalAmount,
    this.status = 'pending',
    this.notes,
    DateTime? createdAt,
    required this.accessMethod,
    this.isRead = false,
    this.storeId, // ✅ إضافة storeId
    this.customerToken, // ✅ إضافة customerToken
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'accessMethod': accessMethod,
      'isRead': isRead,
      'store_id': storeId,
      'customerToken': customerToken,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString(),
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'عميل',
      customerPhone: json['customerPhone']?.toString() ?? '',
      items: (json['items'] as List? ?? [])
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      accessMethod: json['accessMethod']?.toString() ?? 'credentials',
      isRead: json['isRead'] ?? false,
      storeId: json['store_id']?.toString() ?? json['storeId']?.toString(),
      customerToken: json['customerToken']?.toString(),
    );
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'preparing':
        return 'قيد التجهيز';
      case 'ready':
        return 'جاهز للتسليم';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}