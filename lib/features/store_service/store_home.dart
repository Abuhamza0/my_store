// store_home.dart
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../core/services/badge_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/store_id_service.dart';
import '../../store/promo_cloud_service.dart';
import '../../store/promo_item_model.dart';
import '../../widgets/interactive_bell_icon.dart';
import 'animated_hero_stat_card.dart';
import 'category_display_view.dart';
import 'device_management_page.dart';
import 'orders_page.dart';
import 'product_controller.dart';
import 'customer_controller.dart';
import 'order_controller.dart';
import 'product_model.dart';
import 'add_product_page.dart';
import 'add_customer_page.dart';
import 'customer_list_page.dart';
import 'sales_screen.dart';
import 'default_data.dart';
import 'settings_page.dart';
import 'custom_category_model.dart';
import 'category_detail_page.dart';
import 'order_model.dart';
import 'package:mystore/utils/image_helper.dart';
import 'default_supermarket_data.dart';
import 'subscription_page.dart';
import 'package:flutter/foundation.dart';
import 'store_login_page.dart';
import 'package:mystore/core/services/locale_service.dart';
import '../../widgets/pressed_scale_widget.dart';
import '../../core/services/sync_service.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════
//  🎨 لوحة الألوان الفاخرة الموحّدة
// ═══════════════════════════════════════════════════════════════
abstract class _Lux {
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF0D97A);
  static const Color goldDeep = Color(0xFF9A7B1F);
  static const Color champagne = Color(0xFFE8D9A8);

  static const Color midnight = Color(0xFF0A1322);
  static const Color navy = Color(0xFF0F1A2B);
  static const Color navySoft = Color(0xFF182945);
  static const Color navyCard = Color(0xFF111A2A);

  static const Color bgDark = Color(0xFF060A12);
  static const Color bgLight = Color(0xFFF5F7FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color emerald = Color(0xFF10B981);
  static const Color ruby = Color(0xFFE11D48);
  static const Color sapphire = Color(0xFF2563EB);
  static const Color amber = Color(0xFFF59E0B);
  static const Color violet = Color(0xFF7C3AED);
  static const Color teal = Color(0xFF14B8A6);

  static const LinearGradient royalGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
  );

  static const LinearGradient midnightSky = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy, navySoft, midnight],
  );

  static const LinearGradient premiumDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF111B2E), Color(0xFF1B2A45), Color(0xFF0B1322)],
  );
}

class StoreServiceHome extends StatefulWidget {
  const StoreServiceHome({super.key});

  @override
  State<StoreServiceHome> createState() => _StoreServiceHomeState();
}

class _StoreServiceHomeState extends State<StoreServiceHome>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  //  المتغيرات
  // ═══════════════════════════════════════════════════════════
  final RxString selectedCategory = 'all'.obs;
  final RxString selectedType = 'all'.obs;
  final RxString selectedFlavor = 'all'.obs;
  final RxString selectedSubCategory = 'all'.obs;
  final RxString selectedSub = 'all'.obs;
  final RxList<CustomCategory> cats = <CustomCategory>[].obs;
  // في المتغيرات
  final RxList<PromoItem> _cloudPromos = <PromoItem>[].obs;

  final SyncService _syncService = SyncService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? get currentUserEmail => FirebaseAuth.instance.currentUser?.email;
  final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
  RxBool isHorizontalMode = RxBool(false);
  int connectedCustomersCount = 0;

  // ✨ Animated Hero
  int _heroStatsIndex = 0;
  bool _showSearchBar = false;

  // ✋ حالة السحب باليد
  bool _isHolding = false;
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;
  double _dragStartX = 0;
  static const double _kMaxDragX = 140.0;
  static const double _kFlingThreshold = 70.0;

  // 🎯 بطاقات دعائية
  final PageController _promoPageController =
  PageController(viewportFraction: 0.92);
  Timer? _promoAutoPlayTimer;
  int _promoIndex = 0;

  final List<_HeroStatType> _heroStats = [
    _HeroStatType.welcome,
    _HeroStatType.products,
    _HeroStatType.customers,
    _HeroStatType.orders,
  ];

  late final AnimationController _shimmerController;

  final TextEditingController _searchController = TextEditingController();
  Timer? _activeCustomersTimer;
  Timer? _heartbeatTimer;
  StreamSubscription? _newOrdersSubscription;
  StreamSubscription? _connectedCustomersSubscription;
  Worker? _syncWorker;
  Worker? _localeWorker;

  // 🌙 الوضع الداكن
  final RxBool _isDarkMode = false.obs;

  @override
  void initState() {
    super.initState();

    // 🌙 استرجاع الوضع الداكن من Hive
    _isDarkMode.value =
        Hive.box('settings').get('dark_mode', defaultValue: false) == true;

    BadgeService.updateBadge(0);
    _syncService.startAutoSync();
    _loadCloudPromos();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _loadCategoriesFromHive();
    _listenForNewOrders();
    _checkActiveCustomers();

    _activeCustomersTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _checkActiveCustomers(),
    );

    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => SessionService.heartbeat(),
    );

    _startPromoAutoPlay();

    _syncWorker = ever(_syncService.lastSyncTime, (_) {
      if (mounted) setState(() {});
    });

    _localeWorker = ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoFixAndReloadData();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCloudPromos();
    });
  }

  @override
  void dispose() {
    _promoAutoPlayTimer?.cancel();
    _activeCustomersTimer?.cancel();
    _heartbeatTimer?.cancel();
    _newOrdersSubscription?.cancel();
    _connectedCustomersSubscription?.cancel();
    _syncWorker?.dispose();
    _localeWorker?.dispose();
    _searchController.dispose();
    _promoPageController.dispose();
    _shimmerController.dispose();
    _audioPlayer.dispose();
    _syncService.stopAutoSync();
    super.dispose();
  }

  Future<void> _loadCloudPromos() async {
    try {
      final box = Hive.box('settings');
      final isFirstLaunch = box.get('promo_first_launch', defaultValue: true) == true;

      // ═══ إذا كان أول تشغيل، تأجيل التحديث ═══
      if (isFirstLaunch) {
        print('⏸️ First launch detected - skipping promo cloud fetch');
        print('📦 Loading from cache only...');

        // نحمّل من الكاش فقط (بدون سحابة)
        final cached = PromoCloudService.getCachedPromos();
        if (cached != null && cached.isNotEmpty && mounted) {
          _cloudPromos.assignAll(cached);
        }

        // نضع علامة أن أول تشغيل انتهى
        await box.put('promo_first_launch', false);
        return;
      }

      // ═══ تشغيل عادي → نحدّث من السحابة ═══
      print('🔄 Fetching promos from cloud...');
      final items = await PromoCloudService.fetchGlobalPromos(
        forceRefresh: true,
      );

      if (items != null && mounted) {
        _cloudPromos.assignAll(items);
        print('✅ Loaded ${items.length} cloud promos');
      }
    } catch (e) {
      print('❌ Load cloud promos failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🌙 تبديل الوضع الداكن
  // ═══════════════════════════════════════════════════════════
  void _toggleDarkMode() {
    _isDarkMode.value = !_isDarkMode.value;
    Hive.box('settings').put('dark_mode', _isDarkMode.value);
    Get.changeThemeMode(
      _isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
    );
    HapticFeedback.selectionClick();
  }

  // ═══════════════════════════════════════════════════════════
  //  المنطق البرمجي (محفوظ)
  // ═══════════════════════════════════════════════════════════

  void _checkActiveCustomers() async {
    try {
      final storeId = StoreIdService.getStoreId();
      if (storeId.isEmpty) return;

      final threeMinutesAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 3)),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('store_id', isEqualTo: storeId)
          .where('lastActive', isGreaterThan: threeMinutesAgo)
          .get();

      if (mounted) {
        setState(() => connectedCustomersCount = snapshot.docs.length);
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  void _autoFixAndReloadData() {
    try {
      final settingsBox = Hive.box('settings');
      final needsFixRaw = settingsBox.get('needs_data_fix');
      bool needsFix = true;

      if (needsFixRaw != null) {
        if (needsFixRaw is bool) {
          needsFix = needsFixRaw;
        } else if (needsFixRaw is String) {
          needsFix = needsFixRaw.toLowerCase() == 'true';
        }
      }

      if (needsFix) {
        _syncService.fixAllData().then((success) {
          if (success) {
            settingsBox.put('needs_data_fix', false);
            _reloadAllControllers();
            if (mounted) setState(() {});
          }
        });
      }
    } catch (e) {
      print('❌ Auto fix error: $e');
    }
  }

  void _listenForNewOrders() {
    final storeId = StoreIdService.getStoreId();
    _newOrdersSubscription?.cancel();
    _newOrdersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .where('status', isEqualTo: 'pending')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      final oc = Get.find<OrderController>();
      oc.unreadOrdersCount.value = snapshot.docs.length;
      BadgeService.updateBadge(oc.unreadOrdersCount.value);

      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data == null) continue;

          Get.snackbar(
            '🔔 ${'new_order'.tr}!',
            '${data['customerName'] ?? 'customer'.tr} - ${data['totalAmount'] ?? 0} ${'currency_symbol'.tr}',
            snackPosition: SnackPosition.TOP,
            backgroundColor: _Lux.midnight,
            colorText: Colors.white,
            duration: const Duration(seconds: 6),
            icon: const Icon(Icons.notifications_rounded, color: _Lux.gold),
            mainButton: TextButton(
              onPressed: () =>
                  Get.to(() => const OrdersPage(initialFilter: 'pending')),
              child: Text('view_cart'.tr,
                  style: const TextStyle(color: _Lux.gold)),
            ),
          );

          _playNotificationSound();
        }
      }

      if (mounted) setState(() {});
    });
  }

  void _reloadAllControllers() {
    try {
      final pc = Get.find<ProductController>();
      final cc = Get.find<CustomerController>();
      final oc = Get.find<OrderController>();

      pc.products.clear();
      cc.customers.clear();
      oc.orders.clear();

      pc.loadProducts();
      cc.loadCustomers();
      oc.loadOrders();
    } catch (e) {
      print('❌ Controllers reload error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  🏗️ البناء الرئيسي
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<ProductController>();
    final cc = Get.find<CustomerController>();
    final oc = Get.find<OrderController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsBox = Hive.box('settings');

    final trialRaw = settingsBox.get('trial_end_date');
    final isSubscribed =
        settingsBox.get('store_subscribed', defaultValue: false) == true;

    DateTime? trialEndDate;
    if (trialRaw is DateTime) {
      trialEndDate = trialRaw;
    } else if (trialRaw != null) {
      trialEndDate = DateTime.tryParse(trialRaw.toString());
    }

    final now = DateTime.now();
    final isTrialExpired = !isSubscribed &&
        trialEndDate != null &&
        now.isAfter(trialEndDate);

    int? remainingDays;
    if (!isSubscribed && trialEndDate != null && !isTrialExpired) {
      remainingDays = trialEndDate.difference(now).inDays;
      if (remainingDays < 0) remainingDays = 0;
    }

    final storeName = settingsBox
        .get('store_name', defaultValue: 'my_store'.tr)
        .toString();

    return Scaffold(
      backgroundColor: isDark ? _Lux.bgDark : _Lux.bgLight,
      body: isTrialExpired
          ? _buildTrialExpiredPage()
          : SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!isSubscribed && remainingDays != null)
              _buildTrialBanner(remainingDays, isDark),
            _buildModernHeader(storeName, isDark),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: _showSearchBar
                  ? _buildSearchBar(pc, isDark)
                  : const SizedBox.shrink(),
            ),
            Obx(() {
              final count = oc.unreadOrdersCount.value;
              if (count == 0) return const SizedBox.shrink();
              return _buildNewOrdersBanner(count, isDark);
            }),
            Obx(() {
              if (isHorizontalMode.value) {
                return const SizedBox.shrink();
              }
              return _buildCircularStats(pc, cc, oc);
            }),
            Obx(() {
              if (isHorizontalMode.value) {
                return const SizedBox.shrink();
              }
              return _buildPromoCarousel(isDark);
            }),

            Expanded(
              child: Obx(() {
                // نتائج البحث
                if (pc.searchQuery.value.trim().isNotEmpty) {
                  return _buildSearchResults(pc, isDark);
                }

                // عرض الأقسام (وضع عرض المنتجات)
                if (isHorizontalMode.value) {
                  return Column(
                    children: [
                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(14, 4, 14, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius:
                                  BorderRadius.circular(12),
                                  onTap: () =>
                                  isHorizontalMode.value = false,
                                  child: Container(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        vertical: 10, horizontal: 14),
                                    decoration: BoxDecoration(
                                      gradient: _Lux.midnightSky,
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _Lux.midnight
                                              .withOpacity(0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                            Icons.arrow_back_rounded,
                                            color: _Lux.goldLight,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          'back_to_cards'.tr,
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight:
                                            FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CategoryDisplayView(
                          pc: pc,
                          cats: cats,
                          isDark: isDark,
                          selectedCategory: selectedCategory,
                          selectedSub: selectedSub,
                          selectedType: selectedType,
                          selectedFlavor: selectedFlavor,
                        ),
                      ),
                    ],
                  );
                }

                // ✨ البطاقات الرئيسية + الأزرار السريعة
                return _buildMainActionCards(pc, isDark);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🎴 البطاقات الرئيسية + الأزرار السريعة
  // ═══════════════════════════════════════════════════════════

  Widget _buildMainActionCards(ProductController pc, bool isDark) {
    // ═══ الأزرار السريعة ═══
    final quickActions = [
      _QuickAction(
        label: 'add_customer_quick'.tr,
        icon: Icons.person_add_alt_1_rounded,
        color: _Lux.amber,
        onTap: () => Get.to(() => const AddCustomerPage()),
      ),
      _QuickAction(
        label: 'add_offer_quick'.tr,
        icon: Icons.local_offer_rounded,
        color: _Lux.violet,
        onTap: () {
          Get.snackbar(
            'add_offer_quick'.tr,
            'coming_soon'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: _Lux.violet,
            colorText: Colors.white,
          );
        },
      ),
      _QuickAction(
        label: 'add_product_quick'.tr,
        icon: Icons.add_box_rounded,
        color: _Lux.emerald,
        onTap: () => Get.to(() => const AddProductPage()),
      ),
    ];

    // ═══ البطاقات الرئيسية ═══
    final mainCards = [
      _MainActionCard(
        title: 'manage_orders'.tr,
        subtitle: 'orders_list_subtitle'.tr,
        icon: Icons.receipt_long_rounded,
        color: _Lux.amber,
        onTap: () => Get.to(() => const OrdersPage()),
      ),

      _MainActionCard(
        title: 'manage_customers'.tr,
        subtitle: 'customers_list_subtitle'.tr,
        icon: Icons.people_alt_rounded,
        color: _Lux.sapphire,
        onTap: () => Get.to(() => const CustomerListPage()),
      ),
      _MainActionCard(
        title: 'add_products_card'.tr,
        subtitle: 'browse_sections'.tr,
        icon: Icons.inventory_2_rounded,
        color: _Lux.emerald,
        onTap: () {
          isHorizontalMode.value = true;
        },
      ),
      _MainActionCard(
        title: 'manage_offers'.tr,
        subtitle: 'offers_discounts'.tr,
        icon: Icons.local_offer_rounded,
        color: _Lux.violet,
        onTap: () {
          Get.snackbar(
            'manage_offers'.tr,
            'coming_soon'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: _Lux.violet,
            colorText: Colors.white,
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ═══════════════════════════════════════════════
        //  1️⃣ الأزرار السريعة — ثابتة (خارج التمرير)
        // ═══════════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildRealButton(quickActions[0], isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildRealButton(quickActions[1], isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildRealButton(quickActions[2], isDark)),
              ],
            ),
          ),
        ),

        // ═══════════════════════════════════════════════
        //  2️⃣ البطاقات الرئيسية — قابلة للتمرير وحدها
        // ═══════════════════════════════════════════════
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.40,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: mainCards.length,
              itemBuilder: (context, index) =>
                  _buildMainActionCardTile(mainCards[index], isDark),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🔘 زر حقيقي (يبدو مرتفعاً عن السطح - 3D Effect)
  // ═══════════════════════════════════════════════════════════

  Widget _buildRealButton(_QuickAction action, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        splashColor: action.color.withOpacity(0.15),
        highlightColor: action.color.withOpacity(0.08),
        child: Container(
          // ✅ ارتفاع أدنى ثابت
          constraints: const BoxConstraints(minHeight: 82),
          decoration: BoxDecoration(
            // 🎨 خلفية شفافة حسب الوضع
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : action.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : action.color.withOpacity(0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.20)
                    : action.color.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // أيقونة دائرية ملونة
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark
                        ? action.color.withOpacity(0.25)
                        : action.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: action.color.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    action.icon,
                    color: isDark ? Colors.white : action.color,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 6),
                // النص
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      action.label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : _Lux.midnight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🎴 بطاقة رئيسية كبيرة (شفافة - مختلفة عن الأزرار)
  // ═══════════════════════════════════════════════════════════

  Widget _buildMainActionCardTile(_MainActionCard card, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: card.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : card.color.withOpacity(0.20),
              width: 1.2,
            ),
            boxShadow: isDark
                ? []
                : [
              BoxShadow(
                color: card.color.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -12,
                bottom: -12,
                child: Icon(
                  card.icon,
                  size: 90,
                  color: card.color.withOpacity(isDark ? 0.08 : 0.06),
                ),
              ),
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: card.color.withOpacity(isDark ? 0.10 : 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  // ✅ توسيط أفقي
                  crossAxisAlignment: CrossAxisAlignment.center,
                  // ✅ توسيط عمودي
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // الأيقونة
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: card.color.withOpacity(isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: card.color.withOpacity(0.30),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        card.icon,
                        color: isDark ? Colors.white : card.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),  // ← مسافة بدل Spacer

                    // العنوان
                    Text(
                      card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,   // ← توسيط النص
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white : _Lux.midnight,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // الوصف
                    Text(
                      card.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,   // ← توسيط النص
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  👑 الهيدر
  // ═══════════════════════════════════════════════════════════

  Widget _buildModernHeader(String storeName, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: _Lux.midnightSky,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _Lux.gold.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: _Lux.gold.withOpacity(0.22),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ═══════════════════════════════════════════════════════
          //  ⬅️ اليسار: الوضع الداكن + الطلبات
          // ═══════════════════════════════════════════════════════
          Obx(() => _buildDarkModeButton(_isDarkMode.value)),
          const SizedBox(width: 6),
          _buildHeaderIconButton(
            icon: Icons.cloud_sync_rounded,
            tooltip: 'cloud_orders'.tr,
            onPressed: () =>
                Get.to(() => const OrdersPage(initialFilter: 'pending')),
          ),

          // ═══════════════════════════════════════════════════════
          //  🎯 الوسط: الجرس
          // ═══════════════════════════════════════════════════════
          const Spacer(),
          InteractiveBellIcon(onTap: _showNotificationsOnly),
          const Spacer(),

          // ═══════════════════════════════════════════════════════
          //  ➡️ اليمين: البحث + القائمة الجانبية
          // ═══════════════════════════════════════════════════════
          _buildHeaderIconButton(
            icon: _showSearchBar
                ? Icons.close_rounded
                : Icons.search_rounded,
            tooltip: 'search'.tr,
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  Get.find<ProductController>().searchQuery.value = '';
                  Get.find<ProductController>().filterProducts();
                }
              });
            },
          ),
          const SizedBox(width: 4),
          _buildHeaderMenu(isDark),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🌙 زر الوضع الداكن (مع أنيميشن دوران + توهج)
  // ═══════════════════════════════════════════════════════════

  Widget _buildDarkModeButton(bool isDarkActive) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _toggleDarkMode,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDarkActive
                ? _Lux.gold.withOpacity(0.20)
                : Colors.white.withOpacity(0.10),
            border: Border.all(
              color: isDarkActive
                  ? _Lux.gold.withOpacity(0.50)
                  : Colors.white.withOpacity(0.20),
              width: 1.2,
            ),
            boxShadow: isDarkActive
                ? [
              BoxShadow(
                color: _Lux.gold.withOpacity(0.35),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ]
                : null,
          ),
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            turns: isDarkActive ? 0.5 : 0.0,
            child: Icon(
              isDarkActive
                  ? Icons.wb_sunny_rounded
                  : Icons.nightlight_round,
              color: isDarkActive ? _Lux.goldLight : Colors.white70,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 20,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🔍 شريط البحث المنزلق
  // ═══════════════════════════════════════════════════════════

  Widget _buildSearchBar(ProductController pc, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        gradient: _Lux.midnightSky,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? _Lux.navyCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _Lux.gold.withOpacity(0.30),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _Lux.gold.withOpacity(0.15),
              blurRadius: 12,
            ),
          ],
        ),
        child: Obx(() => TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (v) {
            pc.searchQuery.value = v;
            pc.filterProducts();
          },
          textInputAction: TextInputAction.search,
          style: TextStyle(
            color: isDark ? Colors.white : _Lux.midnight,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'search_products_hint'.tr,
            hintStyle:
            TextStyle(color: Colors.grey.shade500, fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded,
                color: _Lux.gold, size: 20),
            suffixIcon: pc.searchQuery.value.isEmpty
                ? null
                : IconButton(
              onPressed: () {
                _searchController.clear();
                pc.searchQuery.value = '';
                pc.filterProducts();
              },
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        )),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🎯 بطاقات دعائية (مُصغّرة)
  // ═══════════════════════════════════════════════════════════

  void _startPromoAutoPlay() {
    _promoAutoPlayTimer?.cancel();
    _promoAutoPlayTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_promoPageController.hasClients) return;
      final promos = _promoItems();
      if (promos.isEmpty) return;
      final next = (_promoIndex + 1) % promos.length;
      _promoPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutQuart,
      );
    });
  }

  List<_PromoItem> _promoItems() {
    // ═══ 1) إذا توجد بطاقات سحابية، استخدمها ═══
    if (_cloudPromos.isNotEmpty) {
      return _cloudPromos.map((item) {
        return _PromoItem(
          title: item.title,
          subtitle: item.subtitle,
          badge: item.badge,
          icon: item.icon,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(item.colorValue),
              item.color2Value,
            ],
          ),
          onTap: () => _handlePromoAction(item.actionType, item.actionValue),
        );
      }).toList();
    }

    // ═══ 2) Fallback: البطاقات الافتراضية ═══
    return [
      _PromoItem(
        title: 'exclusive_offers'.tr,
        subtitle: 'upgrade_store'.tr,
        badge: '⭐',
        icon: Icons.workspace_premium_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9A7B1F), Color(0xFFD4AF37), Color(0xFF6B5214)],
        ),
        onTap: () => Get.to(() => const SubscriptionPage()),
      ),
      _PromoItem(
        title: 'add_your_products'.tr,
        subtitle: 'smart_inventory'.tr,
        badge: '🆕',
        icon: Icons.add_box_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF065F46), Color(0xFF10B981), Color(0xFF064E3B)],
        ),
        onTap: () => Get.to(() => const AddProductPage()),
      ),
      _PromoItem(
        title: 'sales_reports'.tr,
        subtitle: 'track_profits'.tr,
        badge: '📊',
        icon: Icons.insights_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3730A3), Color(0xFF6366F1), Color(0xFF1E1B4B)],
        ),
        onTap: () => Get.to(() => const SalesScreen(showBackButton: true)),
      ),
      _PromoItem(
        title: 'manage_customers'.tr,
        subtitle: 'build_relationships'.tr,
        badge: '💎',
        icon: Icons.groups_rounded,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF831843), Color(0xFFE11D48), Color(0xFF4C0519)],
        ),
        onTap: () => Get.to(() => const CustomerListPage()),
      ),
    ];
  }

  void _handlePromoAction(String actionType, String? actionValue) {
    switch (actionType) {
      case 'subscription':
        Get.to(() => const SubscriptionPage());
        break;
      case 'add_product':
        Get.to(() => const AddProductPage());
        break;
      case 'sales':
        Get.to(() => const SalesScreen(showBackButton: true));
        break;
      case 'customers':
        Get.to(() => const CustomerListPage());
        break;
      case 'orders':
        Get.to(() => const OrdersPage());
        break;
      case 'url':
        if (actionValue != null && actionValue.isNotEmpty) {
          Get.snackbar('رابط', actionValue,
              snackPosition: SnackPosition.BOTTOM);
        }
        break;
      default:
        break;
    }
  }

  Widget _buildPromoCarousel(bool isDark) {
    final promos = _promoItems();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: SizedBox(
        height: 62,
        child: PageView.builder(
          controller: _promoPageController,
          itemCount: promos.length,
          onPageChanged: (i) => setState(() => _promoIndex = i),
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final item = promos[index];
            return AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: index == _promoIndex ? 0 : 4,
              ),
              child: _buildPromoCard(item, isDark),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPromoCard(_PromoItem item, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: item.gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: item.gradient.colors.first.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: -6,
                child: Icon(
                  item.icon,
                  size: 50,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.28),
                        ),
                      ),
                      child: Icon(item.icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item.badge != null) ...[
                                Text(item.badge!,
                                    style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  🎡 البطاقات الإحصائية الدائرية
  // ═══════════════════════════════════════════════════════════

  Widget _buildCircularStats(
      ProductController pc,
      CustomerController cc,
      OrderController oc,
      ) {
    final int center = _heroStatsIndex;
    final int right = (center + 1) % 4;
    final int left = (center - 1 + 4) % 4;
    final int back = (center + 2) % 4;

    final List<int> drawOrder = [back, left, right, center];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SizedBox(
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: drawOrder.map((i) {
            int delta = ((i - _heroStatsIndex) % 4 + 4) % 4;
            double distortion;
            bool isBackground = false;

            switch (delta) {
              case 0:
                distortion = 0.0;
                break;
              case 1:
                distortion = 1.0;
                break;
              case 3:
                distortion = -1.0;
                break;
              default:
                distortion = 0.0;
                isBackground = true;
                break;
            }

            const cardWidth = 255.0;
            const cardHeight = 170.0;
            final isCenter = delta == 0;

            return SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: _buildInteractiveCard(
                index: i,
                isCenter: isCenter,
                distortion: distortion,
                isBackground: isBackground,
                pc: pc,
                cc: cc,
                oc: oc,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInteractiveCard({
    required int index,
    required bool isCenter,
    required double distortion,
    required bool isBackground,
    required ProductController pc,
    required CustomerController cc,
    required OrderController oc,
  }) {
    final card = _buildAnimatedCard(
      index, pc, cc, oc, distortion, isBackground,
    );

    if (!isCenter) return IgnorePointer(child: card);

    final double visualScale =
    _isHolding ? (_isDragging ? 0.98 : 1.06) : 1.0;
    final double dragRotation = _dragOffset.dx / 900.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (_isHolding) return;
        final v = details.primaryVelocity ?? 0;
        if (v < -200) {
          HapticFeedback.selectionClick();
          setState(() => _heroStatsIndex = (_heroStatsIndex + 1) % 4);
        } else if (v > 200) {
          HapticFeedback.selectionClick();
          setState(() => _heroStatsIndex = (_heroStatsIndex - 1 + 4) % 4);
        }
      },
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isHolding = true;
          _isDragging = false;
          _dragOffset = Offset.zero;
          _dragStartX = 0;
        });
      },
      onLongPressMoveUpdate: (details) {
        if (!_isHolding) return;
        setState(() {
          _isDragging = true;
          final dx = details.offsetFromOrigin.dx;
          _dragOffset =
              Offset(dx.clamp(-_kMaxDragX, _kMaxDragX), 0);
        });
      },
      onLongPressEnd: (_) {
        HapticFeedback.selectionClick();
        if (_dragOffset.dx.abs() > _kFlingThreshold) {
          if (_dragOffset.dx > 0) {
            setState(
                    () => _heroStatsIndex = (_heroStatsIndex - 1 + 4) % 4);
          } else {
            setState(
                    () => _heroStatsIndex = (_heroStatsIndex + 1) % 4);
          }
        }
        setState(() {
          _isHolding = false;
          _isDragging = false;
          _dragOffset = Offset.zero;
        });
      },
      onTap: () {
        if (!_isHolding) _handleCardTap(index, pc, cc, oc);
      },
      child: AnimatedContainer(
        duration: _isDragging
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(_dragOffset.dx, _dragOffset.dy)
          ..rotateZ(dragRotation)
          ..scale(visualScale),
        transformAlignment: Alignment.center,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          scale: _isHolding ? 1.04 : 1.0,
          child: card,
        ),
      ),
    );
  }

  void _handleCardTap(
      int index,
      ProductController pc,
      CustomerController cc,
      OrderController oc,
      ) {
    final type = _heroStats[index];
    switch (type) {
      case _HeroStatType.customers:
        Get.to(() => const CustomerListPage());
        break;
      case _HeroStatType.orders:
        Get.to(() => const OrdersPage());
        break;
      default:
        break;
    }
  }

  Widget _buildAnimatedCard(
      int index,
      ProductController pc,
      CustomerController cc,
      OrderController oc,
      double distortion,
      bool isBackground,
      ) {
    final type = _heroStats[index];

    switch (type) {
      case _HeroStatType.welcome:
        final settingsBox = Hive.box('settings');
        final storeName = settingsBox
            .get('store_name', defaultValue: 'my_store'.tr)
            .toString();
        return AnimatedHeroStatCard(
          key: ValueKey('hero_card_$index'),
          distortion: distortion,
          isBackground: isBackground,
          title: 'welcome_message'.tr,
          value: storeName,
          subtitle: 'wish_success'.tr,
          icon: Icons.storefront_rounded,
          accentColor: _Lux.goldDeep,
          onTap: null,
        );

      case _HeroStatType.products:
        return AnimatedHeroStatCard(
          key: ValueKey('hero_card_$index'),
          distortion: distortion,
          isBackground: isBackground,
          title: 'stats_products'.tr,
          value: '${pc.totalProducts}',
          subtitle: 'total_products_subtitle'.tr,
          icon: Icons.inventory_2_rounded,
          accentColor: _Lux.emerald,
          onTap: null,
        );

      case _HeroStatType.customers:
        return AnimatedHeroStatCard(
          key: ValueKey('hero_card_$index'),
          distortion: distortion,
          isBackground: isBackground,
          title: 'stats_customers'.tr,
          value: '${cc.totalCustomers}',
          subtitle: '$connectedCustomersCount ${'online_now'.tr}',
          icon: Icons.people_alt_rounded,
          accentColor: _Lux.sapphire,
          onTap: () => Get.to(() => const CustomerListPage()),
        );

      case _HeroStatType.orders:
        return AnimatedHeroStatCard(
          key: ValueKey('hero_card_$index'),
          distortion: distortion,
          isBackground: isBackground,
          title: 'stats_orders'.tr,
          value: '${oc.orders.length}',
          subtitle: 'total_orders_subtitle'.tr,
          icon: Icons.receipt_long_rounded,
          accentColor: _Lux.amber,
          onTap: () => Get.to(() => const OrdersPage()),
        );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  بقية الدوال (محفوظة كما هي)
  // ═══════════════════════════════════════════════════════════

  Widget _buildTrialBanner(int remainingDays, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.to(() => const SubscriptionPage()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9F1C), Color(0xFFFF5A36)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5A36).withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${'free_trial'.tr} • ${'remaining_days'.tr} $remainingDays ${'days'.tr}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'upgrade'.tr,
                  style: GoogleFonts.cairo(
                    color: const Color(0xFFFF5A36),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewOrdersBanner(int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () =>
              Get.to(() => const OrdersPage(initialFilter: 'pending')),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7043), Color(0xFFE53935)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    count == 1
                        ? 'one_new_order'.tr
                        : '${'new_orders_count'.tr} $count ${'new_orders_suffix'.tr}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderMenu(bool isDark) {
    return PopupMenuButton<String>(
      tooltip: 'more'.tr,
      color: isDark ? _Lux.navyCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Obx(() => _syncService.isSyncing.value
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: _Lux.gold),
      )
          : const Icon(Icons.more_horiz_rounded,
          color: Colors.white70, size: 22)),
      onSelected: (v) async {
        switch (v) {
          case 'settings':
            Get.to(() => const SettingsPage());
            break;
          case 'sync':
            await _runFullSync();
            break;
          case 'devices':
            Get.to(() => const DeviceManagementPage());
            break;
          case 'backup':
            await _syncService.createBackup();
            Get.snackbar('success'.tr, 'backup_created'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: _Lux.emerald,
                colorText: Colors.white);
            break;
          case 'import_supermarket':
            _importSupermarketData(Get.find<ProductController>(), cats);
            break;
          case 'import_default':
            _importDefault(Get.find<ProductController>(),
                Get.find<CustomerController>());
            break;
          case 'clear':
            _clearAll(Get.find<ProductController>(),
                Get.find<CustomerController>(),
                Get.find<OrderController>(), cats);
            break;
          case 'logout':
            await _logout();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
            value: 'sync',
            child: _menuItem(
                Icons.sync_rounded, 'sync_data'.tr, _Lux.sapphire)),
        PopupMenuItem(
            value: 'devices',
            child: _menuItem(Icons.devices_rounded,
                'device_management'.tr, _Lux.violet)),
        PopupMenuItem(
            value: 'backup',
            child: _menuItem(
                Icons.backup_rounded, 'create_backup'.tr, _Lux.teal)),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'settings',
            child: _menuItem(
                Icons.settings_rounded, 'settings'.tr, _Lux.midnight)),
        PopupMenuItem(
            value: 'import_supermarket',
            child: _menuItem(Icons.shopping_cart_outlined,
                'import_supermarket'.tr, _Lux.amber)),
        PopupMenuItem(
            value: 'import_default',
            child: _menuItem(Icons.folder_open_outlined,
                'import_default'.tr, Colors.blueGrey)),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'clear',
            child: _menuItem(Icons.delete_outline_rounded,
                'clear_all_data'.tr, _Lux.ruby)),
        PopupMenuItem(
            value: 'logout',
            child:
            _menuItem(Icons.logout_rounded, 'logout'.tr, _Lux.ruby)),
      ],
    );
  }

  Widget _menuItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _runFullSync() async {
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: _Lux.gold)),
      barrierDismissible: false,
    );
    try {
      await _syncService.syncAllData();
      await _syncService.fetchAllData();
      Get.find<ProductController>().loadProducts();
      Get.find<CustomerController>().loadCustomers();
      Get.find<OrderController>().loadOrders();
      _loadCategoriesFromHive();
    } catch (e) {
      Get.snackbar('error'.tr, '$e',
          backgroundColor: _Lux.ruby, colorText: Colors.white);
    } finally {
      if (Get.isDialogOpen ?? false) Get.back();
    }
  }

  Widget _buildSearchResults(ProductController pc, bool isDark) {
    final searchResults = pc.filteredProducts;
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _Lux.gold.withOpacity(0.08),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 52,
                color: _Lux.gold.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'no_search_results'.tr,
              style: GoogleFonts.cairo(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final product = searchResults[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? _Lux.navyCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? _Lux.gold.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
            ),
          ),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.imagePath.isNotEmpty
                  ? Image.network(
                product.imagePath,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported),
              )
                  : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _Lux.gold.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: _Lux.gold),
              ),
            ),
            title: Text(
              product.name,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${product.price} ${'currency_symbol'.tr}  •  ${product.category}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            trailing: Text(
              '${'stock_label'.tr}: ${product.stock}',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: _Lux.goldDeep,
                fontSize: 11,
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  الإشعارات
  // ═══════════════════════════════════════════════════════════

  void _showNotificationsOnly() {
    final storeId = StoreIdService.getStoreId();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _Lux.royalGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('order_notifications'.tr,
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('storeId', isEqualTo: storeId)
                .where('status', isEqualTo: 'pending')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _Lux.gold));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('no_new_notifications'.tr,
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data();
                  final customerName =
                      data['customerName']?.toString() ?? 'customer'.tr;
                  final customerPhone =
                      data['customerPhone']?.toString() ?? '';
                  final totalAmount =
                      (data['totalAmount'] as num?)?.toDouble() ?? 0;
                  final notes = data['notes']?.toString() ?? '';

                  String orderTime = 'now'.tr;
                  if (data['orderDate'] != null) {
                    try {
                      final timestamp = data['orderDate'] as Timestamp;
                      orderTime = _formatOrderTime(timestamp.toDate());
                    } catch (_) {}
                  }

                  return GestureDetector(
                    onTap: () async {
                      await doc.reference.update({'isRead': true});
                      Navigator.pop(ctx);
                      Get.to(() =>
                      const OrdersPage(initialFilter: 'pending'));
                      _refreshUnreadCount();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _Lux.amber.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _Lux.amber.withOpacity(0.30)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                _Lux.amber.withOpacity(0.20),
                                child: Text(
                                  customerName.isNotEmpty
                                      ? customerName[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.cairo(
                                    color: _Lux.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(customerName,
                                        style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    Text(customerPhone,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Text(
                                '$totalAmount ${'currency_symbol'.tr}',
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(notes,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade800)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Get.to(() => const OrdersPage(initialFilter: 'all'));
            },
            child: Text('view_all_orders'.tr,
                style: GoogleFonts.cairo(color: _Lux.goldDeep)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('close'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final storeId = StoreIdService.getStoreId();
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('status', isEqualTo: 'pending')
          .where('isRead', isEqualTo: false)
          .get();

      final oc = Get.find<OrderController>();
      oc.unreadOrdersCount.value = snapshot.docs.length;
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Counter update error: $e');
    }
  }

  String _formatOrderTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now'.tr;
    if (diff.inMinutes < 60) return '${'minutes_ago'.tr} ${diff.inMinutes}';
    if (diff.inHours < 24) return '${'hours_ago'.tr} ${diff.inHours}';
    return '${time.day}/${time.month} ${time.hour}:${time.minute}';
  }

  void _loadCategoriesFromHive() {
    cats.clear();
    final savedCats = Hive.box('settings')
        .get('custom_categories_data', defaultValue: <Map>[]);
    if (savedCats is List) {
      for (var j in savedCats) {
        try {
          cats.add(CustomCategory.fromJson(Map<String, dynamic>.from(j)));
        } catch (_) {}
      }
    }
  }

  Future<void> _logout() async {
    await SessionService.endSession();
    final settingsBox = Hive.box('settings');
    settingsBox.put('store_logged_in', false);
    settingsBox.delete('store_email');
    settingsBox.delete('store_password');
    settingsBox.delete('store_name');
    settingsBox.delete('store_id');
    Get.offAll(() => const StoreLoginPage());
  }

  Widget _buildTrialExpiredPage() {
    return Container(
      decoration: const BoxDecoration(gradient: _Lux.premiumDark),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _Lux.ruby.withOpacity(0.25),
                      _Lux.ruby.withOpacity(0.08),
                    ],
                  ),
                  border: Border.all(
                      color: _Lux.ruby.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.lock_clock_rounded,
                    color: _Lux.ruby, size: 52),
              ),
              const SizedBox(height: 28),
              Text(
                'trial_expired_title'.tr,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'trial_expired_msg'.tr,
                style: GoogleFonts.cairo(
                    color: Colors.white60, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Get.offAll(() => const SubscriptionPage()),
                  icon: const Icon(Icons.credit_card_rounded,
                      color: _Lux.midnight),
                  label: Text(
                    'subscribe_now'.tr,
                    style: GoogleFonts.cairo(
                        color: _Lux.midnight,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Lux.gold,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  استيراد / تفريغ / حوارات
  // ═══════════════════════════════════════════════════════════

  void _importSupermarketData(
      ProductController pc, RxList<CustomCategory> cats) async {
    showDialog(
      context: Get.context!,
      barrierDismissible: false,
      builder: (c) => const Center(
          child: CircularProgressIndicator(color: _Lux.gold)),
    );
    await DefaultSupermarketData.importAll(pc);
    cats.clear();
    final saved = Hive.box('settings')
        .get('custom_categories_data', defaultValue: <Map>[]);
    if (saved is List) {
      for (var j in saved) {
        try {
          cats.add(CustomCategory.fromJson(Map<String, dynamic>.from(j)));
        } catch (_) {}
      }
    }
    Get.back();
    Get.snackbar('success'.tr, 'supermarket_imported'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _Lux.emerald,
        colorText: Colors.white);
  }

  void _importDefault(ProductController pc, CustomerController cc) async {
    showDialog(
      context: Get.context!,
      barrierDismissible: false,
      builder: (c) => const Center(
          child: CircularProgressIndicator(color: _Lux.gold)),
    );
    await DefaultData.importAll(
        productController: pc, customerController: cc);
    cc.loadCustomers();
    Get.back();
    Get.snackbar('success'.tr, 'import_success'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _Lux.emerald,
        colorText: Colors.white);
  }

  void _clearAll(ProductController pc, CustomerController cc,
      OrderController oc, RxList<CustomCategory> cats) async {
    showDialog(
      context: Get.context!,
      builder: (c) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('warning'.tr,
            style: GoogleFonts.cairo(
                color: _Lux.ruby, fontWeight: FontWeight.bold)),
        content: Text('clear_all_confirm'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await Hive.box('products').clear();
              await Hive.box('customers').clear();
              await Hive.box('orders').clear();
              await Hive.box('settings').delete('custom_categories_data');
              cats.clear();
              pc.loadProducts();
              cc.loadCustomers();
              oc.loadOrders();
              Get.snackbar('🗑️ ${'data_cleared'.tr}', '',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: _Lux.ruby,
                  colorText: Colors.white);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _Lux.ruby),
            child: Text('delete'.tr,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/Ring07.wav'));
    } catch (e) {
      SystemSound.play(SystemSoundType.alert);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  📌 الأدوات المساعدة
// ═══════════════════════════════════════════════════════════════

enum _HeroStatType { welcome, products, customers, orders }

class _PromoItem {
  final String title;
  final String subtitle;
  final String? badge;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  _PromoItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.badge,
  });
}

class _MainActionCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _MainActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}