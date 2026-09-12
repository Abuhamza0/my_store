class CustomCategory {
  final String id;
  String name;
  String? imagePath;
  final List<SubCategory> subCategories;
  final DateTime createdAt;
  final String? storeId; // ✅ إضافة store_id (uid)

  CustomCategory({
    String? id,
    required this.name,
    this.imagePath,
    List<SubCategory>? subCategories,
    DateTime? createdAt,
    this.storeId, // ✅ إضافة
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        subCategories = subCategories ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'subCategories': subCategories.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'store_id': storeId, // ✅ حفظ store_id
    };
  }

  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      imagePath: json['imagePath']?.toString(),
      subCategories: (json['subCategories'] as List? ?? [])
          .map((s) => SubCategory.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      storeId: json['store_id']?.toString() ?? json['storeId']?.toString(), // ✅ قراءة store_id
    );
  }
}

class SubCategory {
  final String id;
  String name;
  String? imagePath;
  List<SubCategory>? subCategories;
  List<Flavor>? flavors;
  final String? storeId; // ✅ إضافة

  SubCategory({
    String? id,
    required this.name,
    this.imagePath,
    this.subCategories,
    this.flavors,
    this.storeId, // ✅ إضافة
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString() {
    subCategories ??= [];
    flavors ??= [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'subCategories': subCategories?.map((s) => s.toJson()).toList() ?? [],
      'flavors': flavors?.map((f) => f.toJson()).toList() ?? [],
      'store_id': storeId, // ✅ حفظ store_id
    };
  }

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      imagePath: json['imagePath']?.toString(),
      subCategories: (json['subCategories'] as List?)
          ?.map((s) => SubCategory.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList() ??
          [],
      flavors: (json['flavors'] as List?)
          ?.map((f) => Flavor.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList() ??
          [],
      storeId: json['store_id']?.toString() ?? json['storeId']?.toString(), // ✅ قراءة store_id
    );
  }
}

class Flavor {
  String name;
  final String id;
  final DateTime createdAt;
  final String? storeId; // ✅ إضافة

  Flavor({
    String? id,
    required this.name,
    DateTime? createdAt,
    this.storeId, // ✅ إضافة
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'store_id': storeId, // ✅ حفظ store_id
    };
  }

  factory Flavor.fromJson(Map<String, dynamic> json) {
    return Flavor(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      storeId: json['store_id']?.toString() ?? json['storeId']?.toString(), // ✅ قراءة store_id
    );
  }
}