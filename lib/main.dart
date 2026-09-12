import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_strategy/url_strategy.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/badge_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/store_id_service.dart';
import 'features/store_service/product_controller.dart';
import 'features/store_service/customer_controller.dart';
import 'features/store_service/order_controller.dart';
import 'features/store_service/sales_screen.dart';
import 'features/store_service/store_login_page.dart';
import 'features/store_service/subscription_page.dart';
import 'features/store_service/translations.dart';
import 'features/store_service/store_home.dart';
import 'features/store_service/user_stats_controller.dart';
import 'core/services/sync_service.dart';
import 'services/cloud_service.dart';
import 'firebase_options.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة Firebase أولاً
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized');
  await StoreIdService.validateStoreId();

  // 2. تهيئة Supabase
  await Supabase.initialize(
    url: 'https://xxxxx.supabase.co',
    anonKey: 'your-anon-key',
  );
  print('✅ Supabase initialized');

  // 3. تهيئة Hive
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('products');
  await Hive.openBox('customers');
  await Hive.openBox('orders');
  await Hive.openBox('box_name');
  await Hive.openBox('categories');

  // 4. حفظ بريد المستخدم من FirebaseAuth (غير الويب)
  if (!kIsWeb) {
    try {
      await StoreIdService.validateStoreId();
    } catch (e) {
      print('⚠️ FirebaseAuth غير متاح: $e');
    }
  }

  // 5. تهيئة الإشعارات (غير الويب فقط)
  if (!kIsWeb) {
    try {
      final notificationService = NotificationService();
      await notificationService.init();
      print('🔔 NotificationService initialized');
    } catch (e) {
      print('⚠️ فشل تهيئة الإشعارات: $e');
    }
  }

  // 6. إعداد الصوت
  try {
    AudioPlayer.global.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notificationEvent,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    ));
  } catch (e) {
    print('⚠️ فشل إعداد الصوت: $e');
  }

  // 7. تسجيل الخدمات
  Get.put(CloudService(), permanent: true);
  Get.put(UserStatsController(), permanent: true);
  Get.put(ProductController(), permanent: true);
  Get.put(CustomerController(), permanent: true);
  Get.put(OrderController(), permanent: true);

  setPathUrlStrategy();

  await _autoFixDataOnStartup();

  // 8. ضمان store_id
  final settingsBox = Hive.box('settings');
  if (!settingsBox.containsKey('store_id')) {
    settingsBox.put('store_id', 'default_store');
  }

  // 9. مسح العداد
  try {
    await BadgeService.updateBadge(0);
  } catch (e) {
    print('⚠️ فشل تحديث العداد: $e');
  }

  runApp(const StoreApp());
}

/// ✅ إصلاح تلقائي للبيانات عند بدء التشغيل
Future<void> _autoFixDataOnStartup() async {
  try {
    final settingsBox = Hive.box('settings');

    final keysToFix = [
      'store_logged_in',
      'store_subscribed',
      'darkMode',
      'is_admin',
      'needs_data_fix'
    ];

    for (var key in keysToFix) {
      final value = settingsBox.get(key);
      if (value != null && value is String) {
        final fixedValue = value.toLowerCase().trim() == 'true';
        await settingsBox.put(key, fixedValue);
        print('🔧 تم إصلاح $key: $value -> $fixedValue');
      }
    }

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
      print('🔧 بدء إصلاح البيانات تلقائياً...');
      try {
        final syncService = SyncService();
        await syncService.fixAllData();
      } catch (e) {
        print('⚠️ SyncService fix failed, continuing...');
      }
      await settingsBox.put('needs_data_fix', false);
      print('✅ تم إصلاح البيانات تلقائياً');
    } else {
      print('✅ البيانات سليمة، لا حاجة للإصلاح');
    }
  } catch (e) {
    print('❌ خطأ في الإصلاح التلقائي: $e');
  }
}

class StoreApp extends StatelessWidget {
  const StoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box('settings');

    final isDarkMode = _safeGetBool(settingsBox, 'darkMode', defaultValue: false);
    final savedLang = _safeGetString(settingsBox, 'language', defaultValue: 'ar');

    final uri = Uri.base;
    final host = uri.host;
    final isShopingDomain = host.startsWith('sh.') || host.startsWith('shoping');
    final storeIdFromUrl = uri.queryParameters['storeId'];
    final phoneFromUrl = uri.queryParameters['phone'];
    final emailFromUrl = uri.queryParameters['email'];

    print('🌐 Host: $host');
    print('🔍 storeId: $storeIdFromUrl');
    print('🏪 isShopingDomain: $isShopingDomain');

    return GetMaterialApp(
      title: isShopingDomain ? 'المتجر' : 'خدمة متجري',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: Locale(savedLang),
      fallbackLocale: const Locale('ar'),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: isShopingDomain || storeIdFromUrl != null
          ? SalesScreen(
        storeIdFromUrl: storeIdFromUrl,
        phoneFromUrl: phoneFromUrl,
        emailFromUrl: emailFromUrl,
        showBackButton: false,
      )
          : const SplashScreen(),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF1A2332),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2332),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF1A2332),
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2332),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E2E),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ==================== Splash Screen ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();

    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _navigateToNextScreen();
      }
    });
  }

  void _navigateToNextScreen() {
    try {
      final settingsBox = Hive.box('settings');

      final isLoggedIn =
      _safeGetBool(settingsBox, 'store_logged_in', defaultValue: false);
      final isSubscribed =
      _safeGetBool(settingsBox, 'store_subscribed', defaultValue: false);
      final isAdmin =
      _safeGetBool(settingsBox, 'is_admin', defaultValue: false);

      print('🔍 Navigation check:');
      print('   isLoggedIn: $isLoggedIn');
      print('   isSubscribed: $isSubscribed');
      print('   isAdmin: $isAdmin');

      // ═══════════════════════════════════════════════════════
      //  🚪 1) غير مسجل دخول → شاشة الدخول
      // ═══════════════════════════════════════════════════════
      if (!isLoggedIn) {
        print('→ StoreLoginPage (not logged in)');
        Get.off(() => const StoreLoginPage());
        return;
      }

      // ═══════════════════════════════════════════════════════
      //  🔐 2) الأدمن → الشاشة الرئيسية مباشرة
      // ═══════════════════════════════════════════════════════
      if (isAdmin) {
        print('→ StoreServiceHome (admin)');
        Get.off(() => const StoreServiceHome());
        return;
      }

      // ═══════════════════════════════════════════════════════
      //  💎 3) مشترك → الشاشة الرئيسية
      // ═══════════════════════════════════════════════════════
      if (isSubscribed) {
        print('→ StoreServiceHome (subscribed)');
        Get.off(() => const StoreServiceHome());
        return;
      }

      // ═══════════════════════════════════════════════════════
      //  ⏱️ 4) تجربة مجانية → تحقق من التاريخ
      // ═══════════════════════════════════════════════════════
      final trialEndDateRaw = settingsBox.get('trial_end_date');

      if (trialEndDateRaw != null) {
        DateTime? endDate;

        if (trialEndDateRaw is String) {
          endDate = DateTime.tryParse(trialEndDateRaw);
        } else if (trialEndDateRaw is DateTime) {
          endDate = trialEndDateRaw;
        }

        if (endDate != null && DateTime.now().isBefore(endDate)) {
          print('→ StoreServiceHome (trial active)');
          Get.off(() => const StoreServiceHome());
          return;
        }

        // التجربة انتهت
        print('→ SubscriptionPage (trial expired)');
        Get.off(() => const SubscriptionPage());
        return;
      }

      // ═══════════════════════════════════════════════════════
      //  ❓ 5) مسجل دخول لكن بدون تجربة → الشاشة الرئيسية
      //     (هذا يحدث للأدمن أو الحسابات القديمة)
      // ═══════════════════════════════════════════════════════
      print('→ StoreServiceHome (logged in, no trial)');
      Get.off(() => const StoreServiceHome());
    } catch (e) {
      print('❌ Error in _navigateToNextScreen: $e');
      Get.off(() => const StoreLoginPage());
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/gogo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A2332), Color(0xFF2D3A4E)],
                  ),
                ),
              );
            },
          ),
          Container(color: Colors.black.withOpacity(0.4)),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Image.asset(
                    'assets/images/logo.png',
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.store_rounded,
                          color: Colors.white, size: 60);
                    },
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'app_name'.tr,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 60),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 4,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'store_from_nitham'.tr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== دوال مساعدة ====================

bool _safeGetBool(Box box, String key, {bool defaultValue = false}) {
  try {
    final value = box.get(key);
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase().trim() == 'true';
    if (value is int) return value == 1;
    return defaultValue;
  } catch (e) {
    return defaultValue;
  }
}

String _safeGetString(Box box, String key, {String defaultValue = ''}) {
  try {
    final value = box.get(key);
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  } catch (e) {
    return defaultValue;
  }
}

int _safeGetInt(Box box, String key, {int defaultValue = 0}) {
  try {
    final value = box.get(key);
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  } catch (e) {
    return defaultValue;
  }
}