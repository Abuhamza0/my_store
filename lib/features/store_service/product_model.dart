import 'dart:math';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imagePath;
  final List<String>? images;
  final List<String> additionalImages;
  final bool isAvailable;
  final int stock;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final String? flavor;
  final String? storeId; // ✅ إضافة store_id (uid)

  // ✅ جديد: الأحجام
  final List<ProductSize>? sizes; // قائمة الأحجام المتاحة
  final bool hasMultipleSizes; // هل المنتج له أحجام متعددة؟

  Product({
    String? id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imagePath = 'assets/images/product_placeholder.png',
    this.images,
    this.additionalImages = const [],
    this.isAvailable = true,
    this.stock = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    DateTime? createdAt,
    this.flavor,
    this.sizes, // ✅ جديد
    this.hasMultipleSizes = false, // ✅ جديد
    this.storeId, // ✅ إضافة
  }) : id = id ?? '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imagePath': imagePath,
      'images': images,
      'additionalImages': additionalImages,
      'isAvailable': isAvailable,
      'stock': stock,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt.toIso8601String(),
      'flavor': flavor,
      'sizes': sizes?.map((s) => s.toJson()).toList(), // ✅ جديد
      'hasMultipleSizes': hasMultipleSizes, // ✅ جديد
      'store_id': storeId, // ✅ حفظ store_id
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'الكل',
      imagePath: json['imagePath']?.toString() ?? 'assets/images/product_placeholder.png',
      additionalImages: (json['additionalImages'] as List? ?? []).map((e) => e.toString()).toList(),
      isAvailable: json['isAvailable'] ?? true,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      flavor: json['flavor']?.toString(),
      sizes: (json['sizes'] as List<dynamic>?)
          ?.map((s) => ProductSize.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      hasMultipleSizes: json['hasMultipleSizes'] ?? false,
      storeId: json['store_id']?.toString() ?? json['storeId']?.toString(), // ✅ قراءة store_id
    );
  }
}

class ProductSize {
  String name; // اسم الحجم (صغير، وسط، كبير)
  double price; // سعر هذا الحجم
  int stock; // المخزون لهذا الحجم
  String? description; // وصف خاص بالحجم
  final String id;
  final String? storeId; // ✅ إضافة

  ProductSize({
    String? id,
    required this.name,
    required this.price,
    this.stock = 0,
    this.description,
    this.storeId, // ✅ إضافة
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'description': description,
      'store_id': storeId, // ✅ حفظ store_id
    };
  }

  factory ProductSize.fromJson(Map<String, dynamic> json) {
    return ProductSize(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] ?? 0,
      description: json['description']?.toString(),
      storeId: json['store_id']?.toString() ?? json['storeId']?.toString(), // ✅ قراءة store_id
    );
  }
}