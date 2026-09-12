// promo_item_model.dart
import 'package:flutter/material.dart';

class PromoItem {
  final String id;
  String title;
  String subtitle;
  String? badge;
  IconData icon;
  int colorValue;       // ← لون أساسي (يُبنى منه التدرج)
  Color color2Value;    // ← لون ثانوي للتدرج
  String actionType;    // 'subscription' | 'add_product' | 'sales' | 'customers' | 'orders' | 'url' | 'none'
  String? actionValue;  // للـ url أو أي معرّف مخصص
  bool isActive;
  int order;

  PromoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.icon,
    required this.colorValue,
    required this.color2Value,
    required this.actionType,
    this.actionValue,
    this.isActive = true,
    this.order = 0,
  });

  // ─── من Map إلى Object ───
  factory PromoItem.fromMap(Map<String, dynamic> map) {
    return PromoItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      badge: map['badge']?.toString(),
      icon: _iconFromCodePoint(map['iconCodePoint'] as int? ?? 0xe1bd),
      colorValue: map['colorValue'] as int? ?? 0xFFD4AF37,
      color2Value: Color(map['color2Value'] as int? ?? 0xFF6B5214),
      actionType: map['actionType']?.toString() ?? 'none',
      actionValue: map['actionValue']?.toString(),
      isActive: map['isActive'] as bool? ?? true,
      order: map['order'] as int? ?? 0,
    );
  }

  // ─── من Object إلى Map ───
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'badge': badge,
      'iconCodePoint': icon.codePoint,
      'colorValue': colorValue,
      'color2Value': color2Value.value,
      'actionType': actionType,
      'actionValue': actionValue,
      'isActive': isActive,
      'order': order,
    };
  }

  // ─── تحويل IconData من codePoint ───
  static IconData _iconFromCodePoint(int codePoint) {
    // نبحث في أيقونات Material المعروفة
    // الحل: نحتفظ بالمرجع في قائمة الأيقونات المتاحة
    return _availableIcons.firstWhere(
          (i) => i.codePoint == codePoint,
      orElse: () => Icons.star_rounded,
    );
  }

  // ─── قائمة الأيقونات المتاحة للأدمن ───
  static const List<IconData> _availableIcons = [
    Icons.workspace_premium_rounded,
    Icons.add_box_rounded,
    Icons.insights_rounded,
    Icons.groups_rounded,
    Icons.local_offer_rounded,
    Icons.star_rounded,
    Icons.receipt_long_rounded,
    Icons.shopping_cart_rounded,
    Icons.celebration_rounded,
    Icons.card_giftcard_rounded,
    Icons.trending_up_rounded,
    Icons.flash_on_rounded,
    Icons.favorite_rounded,
    Icons.storefront_rounded,
    Icons.inventory_2_rounded,
    Icons.people_alt_rounded,
    Icons.support_agent_rounded,
    Icons.sell_rounded,
    Icons.auto_awesome_rounded,
    Icons.new_releases_rounded,
  ];

  static List<IconData> get availableIcons => _availableIcons;

  // ─── قائمة التدرجات الجاهزة ───
  static const List<List<Color>> availableGradients = [
    [Color(0xFF9A7B1F), Color(0xFFD4AF37), Color(0xFF6B5214)], // ذهبي
    [Color(0xFF065F46), Color(0xFF10B981), Color(0xFF064E3B)], // زمردي
    [Color(0xFF3730A3), Color(0xFF6366F1), Color(0xFF1E1B4B)], // بنفسجي
    [Color(0xFF831843), Color(0xFFE11D48), Color(0xFF4C0519)], // ياقوتي
    [Color(0xFF7C2D12), Color(0xFFF59E0B), Color(0xFF451A03)], // عنبري
    [Color(0xFF0C4A6E), Color(0xFF0EA5E9), Color(0xFF082F49)], // سماوي
    [Color(0xFF134E4A), Color(0xFF14B8A6), Color(0xFF042F2E)], // تركوازي
    [Color(0xFF581C87), Color(0xFFA855F7), Color(0xFF3B0764)], // أرجواني
    [Color(0xFF1E3A5F), Color(0xFF3B82F6), Color(0xFF0F172A)], // كحلي
    [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFF450A0A)], // أحمر
  ];

  // ─── قائمة أنواع الأحداث ───
  static const List<Map<String, String>> actionTypes = [
    {'value': 'subscription', 'label': 'الاشتراك'},
    {'value': 'add_product', 'label': 'إضافة منتج'},
    {'value': 'sales', 'label': 'تقارير المبيعات'},
    {'value': 'customers', 'label': 'العملاء'},
    {'value': 'orders', 'label': 'الطلبات'},
    {'value': 'url', 'label': 'رابط خارجي'},
    {'value': 'none', 'label': 'بدون إجراء'},
  ];
}