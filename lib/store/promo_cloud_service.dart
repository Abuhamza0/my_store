// promo_cloud_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'promo_item_model.dart';

class PromoCloudService {
  static const String _collection = 'promo_cards';
  static const String _docId = 'global';
  static const String _hiveKey = 'cloud_promo_items';
  static const String _hiveLastSync = 'cloud_promo_last_sync';

  // ═══════════════════════════════════════════════════════════
  //  📤 للأدمن: رفع البطاقات إلى السحابة (عامة)
  // ═══════════════════════════════════════════════════════════
  static Future<bool> uploadGlobalPromos(List<PromoItem> items) async {
    try {
      final data = {
        'items': items.map((e) => e.toMap()).toList(),
        'updated_at': FieldValue.serverTimestamp(),
        'count': items.length,
      };

      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .set(data, SetOptions(merge: false));

      // تحديث آخر مزامنة محلياً
      Hive.box('settings').put(
        _hiveLastSync,
        DateTime.now().toIso8601String(),
      );

      // تخزين نسخة محلية
      await _cacheLocally(items);

      print('✅ Global promos uploaded: ${items.length}');
      return true;
    } catch (e) {
      print('❌ Upload failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  📥 لجميع المستخدمين: تحميل البطاقات من السحابة
  // ═══════════════════════════════════════════════════════════
  static Future<List<PromoItem>?> fetchGlobalPromos({
    bool forceRefresh = false,
  }) async {
    try {
      // ═══ 1) محاولة القراءة من الكاش (إن لم يكن forceRefresh) ═══
      if (!forceRefresh) {
        final cached = _loadFromCache();
        final lastSync = Hive.box('settings').get(_hiveLastSync)?.toString();

        if (cached != null && cached.isNotEmpty && lastSync != null) {
          final lastSyncTime = DateTime.tryParse(lastSync);
          // إذا كان الكاش حديثاً (أقل من ساعة)، استخدمه
          if (lastSyncTime != null &&
              DateTime.now().difference(lastSyncTime).inMinutes < 60) {
            print('📦 Using cached promos: ${cached.length}');
            return cached;
          }
        }
      }

      // ═══ 2) القراءة من Firestore ═══
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();

      if (!doc.exists) {
        print('⚠️ No global promos in cloud');
        return _loadFromCache();
      }

      final data = doc.data();
      if (data == null || data['items'] == null) {
        return _loadFromCache();
      }

      final itemsList = (data['items'] as List)
          .map((j) => PromoItem.fromMap(Map<String, dynamic>.from(j)))
          .where((p) => p.isActive) // ← النشطة فقط
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      // ═══ 3) تخزين في الكاش ═══
      await _cacheLocally(itemsList);
      Hive.box('settings').put(
        _hiveLastSync,
        DateTime.now().toIso8601String(),
      );

      print('✅ Fetched ${itemsList.length} promos from cloud');
      return itemsList;
    } catch (e) {
      print('❌ Fetch failed: $e');
      // في حالة الفشل، نرجع الكاش
      return _loadFromCache();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🗑️ للأدمن: حذف البطاقات السحابية
  // ═══════════════════════════════════════════════════════════
  static Future<bool> deleteGlobalPromos() async {
    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .delete();

      Hive.box('settings').delete(_hiveKey);
      Hive.box('settings').delete(_hiveLastSync);

      print('✅ Global promos deleted');
      return true;
    } catch (e) {
      print('❌ Delete failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  📡 Stream مباشر للتحديثات الفورية (اختياري)
  // ═══════════════════════════════════════════════════════════
  static Stream<List<PromoItem>> watchGlobalPromos() {
    return FirebaseFirestore.instance
        .collection(_collection)
        .doc(_docId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <PromoItem>[];

      final data = doc.data();
      if (data == null || data['items'] == null) return <PromoItem>[];

      return (data['items'] as List)
          .map((j) => PromoItem.fromMap(Map<String, dynamic>.from(j)))
          .where((p) => p.isActive)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  🔧 دوال مساعدة (تخزين/استرجاع من Hive)
  // ═══════════════════════════════════════════════════════════
  static Future<void> _cacheLocally(List<PromoItem> items) async {
    try {
      await Hive.box('settings').put(
        _hiveKey,
        items.map((e) => e.toMap()).toList(),
      );
    } catch (e) {
      print('⚠️ Cache error: $e');
    }
  }

  static List<PromoItem>? _loadFromCache() {
    try {
      final saved = Hive.box('settings').get(_hiveKey);
      if (saved is List && saved.isNotEmpty) {
        return saved
            .map((j) => PromoItem.fromMap(Map<String, dynamic>.from(j)))
            .toList();
      }
    } catch (e) {
      print('⚠️ Load cache error: $e');
    }
    return null;
  }


  /// الحصول على البطاقات من الكاش فقط (بدون سحابة)
  static List<PromoItem>? getCachedPromos() {
    return _loadFromCache();
  }


  // ═══════════════════════════════════════════════════════════
  //  🕐 وقت آخر مزامنة
  // ═══════════════════════════════════════════════════════════
  static DateTime? getLastSyncTime() {
    final raw = Hive.box('settings').get(_hiveLastSync)?.toString();
    return raw != null ? DateTime.tryParse(raw) : null;
  }
}