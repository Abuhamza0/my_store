// customer_list_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/store_id_service.dart';
import 'customer_controller.dart';
import 'customer_model.dart';
import 'add_customer_page.dart';

// ═══════════════════════════════════════════════════════════════
//  🎨 لوحة ألوان فاخرة موحّدة
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
}

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage>
    with SingleTickerProviderStateMixin {
  final onlineTick = 0.obs;

  // ✨ أنيميشن دخول القائمة
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();

    final cc = Get.find<CustomerController>();
    print('📊 Customers: ${cc.customers.length}');
    for (var c in cc.customers) {
      print('👤 ${c.name} - lastActive: ${c.lastActive}');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getStoreId() {
    return StoreIdService.getStoreId();
  }

  String _getStoreUrl() {
    final storeId = _getStoreId();
    return 'https://sh.nithamsoft.com?storeId=$storeId';
  }

  String get currency => Hive.box('settings')
      .get('currency', defaultValue: 'SAR')
      ?.toString() ??
      'SAR';
  String get storeName => Hive.box('settings')
      .get('store_name', defaultValue: 'my_store'.tr)
      ?.toString() ??
      'my_store'.tr;

  // ═══════════════════════════════════════════════════════════════
  //  🏗️ البناء الرئيسي
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CustomerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _Lux.bgDark : _Lux.bgLight,
      body: Column(
        children: [
          _buildHeader(controller, isDark),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    _buildStatsBar(controller, isDark),
                    _buildSearchIndicator(controller),
                    Expanded(
                      child: Obx(() {
                        if (controller.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _Lux.gold,
                              strokeWidth: 2.5,
                            ),
                          );
                        }

                        if (controller.filteredCustomers.isEmpty) {
                          return _buildEmptyState(isDark);
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                          itemCount: controller.filteredCustomers.length,
                          itemBuilder: (context, index) => _buildCustomerCard(
                            controller.filteredCustomers[index],
                            controller,
                            isDark,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingButton(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎯 الهيدر الفاخر
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(CustomerController controller, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 14,
        right: 14,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        gradient: _Lux.midnightSky,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _Lux.gold.withOpacity(0.08),
            blurRadius: 26,
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
          // زر الرجوع
          _headerIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Get.back(),
          ),
          const SizedBox(width: 10),
          // الشعار
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: _Lux.royalGold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _Lux.gold.withOpacity(0.40),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Colors.white, _Lux.champagne, Colors.white],
                  ).createShader(rect),
                  child: Text(
                    'customers'.tr,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Obx(() => Text(
                  '${controller.totalCustomers} ${'customers_count'.tr}',
                  style: GoogleFonts.cairo(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                )),
              ],
            ),
          ),
          _headerIconButton(
            icon: Icons.search_rounded,
            onTap: () => _showSearchDialog(context, controller),
            tooltip: 'search'.tr,
          ),
          _headerIconButton(
            icon: Icons.cloud_sync_rounded,
            onTap: () async {
              try {
                final storeId = _getStoreId();
                final snapshot = await FirebaseFirestore.instance
                    .collection('customers')
                    .where('store_id', isEqualTo: storeId)
                    .get();

                print('📊 Store customers ($storeId): ${snapshot.docs.length}');
                for (var doc in snapshot.docs) {
                  final data = doc.data();
                  print('👤 ${data['name']} - ${data['phone']}');
                  print('   lastActive: ${data['lastActive']}');
                  print('---');
                }

                Get.snackbar(
                  'result'.tr,
                  '${snapshot.docs.length} ${'customers_count_for_store'.tr}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: _Lux.sapphire,
                  colorText: Colors.white,
                );
              } catch (e) {
                print('❌ Error: $e');
                Get.snackbar('error'.tr, '$e',
                    backgroundColor: _Lux.ruby, colorText: Colors.white);
              }
            },
          ),
          _buildMoreMenu(controller),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(CustomerController controller) {
    return PopupMenuButton<String>(
      tooltip: 'more'.tr,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      onSelected: (value) {
        if (value == 'all') {
          controller.searchQuery.value = '';
          controller.filterCustomers();
        } else if (value == 'active') {
          controller.searchQuery.value = '';
          controller.filterCustomers();
        }
      },
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1,
          ),
        ),
        child: const Icon(Icons.more_vert_rounded,
            color: Colors.white, size: 18),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'all',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _Lux.sapphire.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people_rounded,
                    size: 16, color: _Lux.sapphire),
              ),
              const SizedBox(width: 10),
              Text('all_customers'.tr,
                  style: GoogleFonts.cairo(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'active',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _Lux.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 16, color: _Lux.emerald),
              ),
              const SizedBox(width: 10),
              Text('active_customers'.tr,
                  style: GoogleFonts.cairo(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  📊 شريط الإحصائيات
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatsBar(CustomerController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _Lux.midnightSky,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _Lux.gold.withOpacity(0.20),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: _Lux.gold.withOpacity(0.10),
              blurRadius: 28,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Obx(() => Row(
          children: [
            Expanded(
              child: _buildStatItem(
                label: 'total_customers'.tr,
                value: '${controller.totalCustomers}',
                icon: Icons.people_alt_rounded,
                accent: _Lux.sapphire,
              ),
            ),
            Container(
              width: 1,
              height: 48,
              color: Colors.white.withOpacity(0.15),
            ),
            Expanded(
              child: _buildStatItem(
                label: 'total_sales'.tr,
                value:
                '${controller.totalSales.toStringAsFixed(0)} $currency',
                icon: Icons.monetization_on_rounded,
                accent: _Lux.gold,
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withOpacity(0.30),
                accent.withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.35), width: 1),
          ),
          child: Icon(icon, color: accent == _Lux.gold ? _Lux.goldLight : Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔍 مؤشر البحث
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSearchIndicator(CustomerController controller) {
    return Obx(() {
      if (controller.searchQuery.value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _Lux.sapphire.withOpacity(0.12),
                _Lux.sapphire.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _Lux.sapphire.withOpacity(0.30),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _Lux.sapphire.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.search_rounded,
                    color: _Lux.sapphire, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${'search_results_for'.tr} "${controller.searchQuery.value}"',
                  style: GoogleFonts.cairo(
                    color: _Lux.sapphire,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  controller.searchQuery.value = '';
                  controller.filterCustomers();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _Lux.ruby.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: _Lux.ruby, size: 14),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎴 بطاقة العميل
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCustomerCard(
      Customer customer, CustomerController controller, bool isDark) {
    controller.onlineTick.value;

    final lastActive = customer.lastActive;
    final isOnline = lastActive != null &&
        DateTime.now().difference(lastActive).inSeconds < 180;

    final accentColor = isOnline ? _Lux.emerald : _Lux.sapphire;

    return GestureDetector(
      onTap: () => _showCustomerDetails(customer, controller),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? _Lux.navyCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOnline
                ? _Lux.emerald.withOpacity(0.35)
                : (isDark
                ? _Lux.gold.withOpacity(0.10)
                : Colors.black.withOpacity(0.05)),
            width: isOnline ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            if (isOnline)
              BoxShadow(
                color: _Lux.emerald.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // الصورة الرمزية
              _buildAvatar(customer, isOnline),
              const SizedBox(width: 12),
              // المعلومات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name.isNotEmpty
                          ? customer.name
                          : customer.phone,
                      style: GoogleFonts.cairo(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : _Lux.midnight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.phone_android_rounded,
                            size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customer.phone,
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(isOnline, lastActive),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // الأزرار
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.link_rounded,
                    color: _Lux.emerald,
                    onTap: () => _copyStoreLink(),
                    tooltip: 'copy_store_link'.tr,
                  ),
                  const SizedBox(height: 6),
                  _buildActionButton(
                    icon: Icons.edit_rounded,
                    color: _Lux.sapphire,
                    onTap: () =>
                        Get.to(() => AddCustomerPage(customer: customer)),
                    tooltip: 'edit'.tr,
                  ),
                  const SizedBox(height: 6),
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: _Lux.ruby,
                    onTap: () => _showDeleteConfirmation(
                        controller, customer.id, customer.name),
                    tooltip: 'delete'.tr,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Customer customer, bool isOnline) {
    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _Lux.royalGold,
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _Lux.gold.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              customer.name.isNotEmpty
                  ? customer.name[0].toUpperCase()
                  : '?',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isOnline ? _Lux.emerald : Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: isOnline
                  ? [
                BoxShadow(
                  color: _Lux.emerald.withOpacity(0.6),
                  blurRadius: 8,
                ),
              ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isOnline, DateTime? lastActive) {
    final color = isOnline ? _Lux.emerald : Colors.grey.shade500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 6,
                ),
              ]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              isOnline
                  ? 'online_now'.tr
                  : '${'last_seen'.tr}: ${lastActive != null ? _formatLastSeen(lastActive) : 'never_seen'.tr}',
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.25), width: 0.8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🗑️ الحالة الفارغة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _Lux.gold.withOpacity(0.15),
                    _Lux.gold.withOpacity(0.04),
                  ],
                ),
                border: Border.all(
                  color: _Lux.gold.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 58,
                color: _Lux.gold.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'no_customers'.tr,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _Lux.midnight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'add_first_customer'.tr,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            _buildPrimaryButton(
              icon: Icons.person_add_rounded,
              label: 'add_customer'.tr,
              onTap: () => Get.to(() => const AddCustomerPage()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: _Lux.royalGold,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _Lux.gold.withOpacity(0.40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ➕ زر عائم
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFloatingButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _Lux.gold.withOpacity(0.45),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const AddCustomerPage()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        label: Container(
          decoration: BoxDecoration(
            gradient: _Lux.royalGold,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.person_add_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'add_customer'.tr,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔧 الدوال المنطقية (محفوظة بالكامل)
  // ═══════════════════════════════════════════════════════════════

  String _formatLastSeen(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'now'.tr;
    if (difference.inMinutes < 60) {
      return '${'minutes_ago'.tr} ${difference.inMinutes}';
    }
    if (difference.inHours < 24) {
      return '${'hours_ago'.tr} ${difference.inHours}';
    }
    if (difference.inDays < 7) {
      return '${'days_ago'.tr} ${difference.inDays}';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _copyStoreLink() {
    final storeId = _getStoreId();
    final url = 'https://sh.nithamsoft.com?storeId=$storeId';
    Clipboard.setData(ClipboardData(text: url));
    Get.snackbar(
      'done'.tr,
      'link_copied'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _Lux.emerald,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _shareStoreLink() {
    final url = _getStoreUrl();
    Share.share('🏪 $storeName\n🔗 $url', subject: storeName);
  }

  void _showCustomerDetails(Customer customer, CustomerController controller) {
    final storeUrl = _getStoreUrl();

    showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // مقبض السحب
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // الصورة الرمزية الكبيرة
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _Lux.royalGold,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _Lux.gold.withOpacity(0.40),
                            blurRadius: 22,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      customer.name.isNotEmpty
                          ? customer.name
                          : customer.phone,
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _Lux.midnight,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildDetailItem(
                        Icons.phone_android_rounded, 'phone_number'.tr,
                        customer.phone, _Lux.sapphire),
                    if (customer.name.isNotEmpty)
                      _buildDetailItem(Icons.person_rounded, 'name'.tr,
                          customer.name, _Lux.violet),
                    const SizedBox(height: 16),

                    // بطاقة الرابط
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _Lux.gold.withOpacity(0.10),
                            _Lux.gold.withOpacity(0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _Lux.gold.withOpacity(0.30),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: _Lux.royalGold,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.link_rounded,
                                    color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'store_link'.tr,
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _Lux.midnight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'store_link_description'.tr,
                            style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade200),
                            ),
                            child: SelectableText(
                              storeUrl,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: _Lux.midnight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniActionButton(
                                  icon: Icons.copy_rounded,
                                  label: 'copy_link'.tr,
                                  gradient: _Lux.midnightSky,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _copyStoreLink();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMiniActionButton(
                                  icon: Icons.share_rounded,
                                  label: 'share'.tr,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF059669),
                                      Color(0xFF047857),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _shareStoreLink();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // زر التعديل
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _Lux.royalGold,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _Lux.gold.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(context);
                              Get.to(() =>
                                  AddCustomerPage(customer: customer));
                            },
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'edit'.tr,
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(
      IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _Lux.midnight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(
      BuildContext context, CustomerController controller) {
    final searchCtrl =
    TextEditingController(text: controller.searchQuery.value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _Lux.royalGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('search_customer'.tr,
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: searchCtrl,
          autofocus: true,
          style: GoogleFonts.cairo(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'search_customer_hint'.tr,
            hintStyle: GoogleFonts.cairo(
                color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _Lux.gold),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
              BorderSide(color: Colors.grey.withOpacity(0.20)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _Lux.gold, width: 1.6),
            ),
          ),
          onChanged: (q) {
            controller.searchQuery.value = q;
            controller.filterCustomers();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.searchQuery.value = '';
              controller.filterCustomers();
              Navigator.pop(context);
            },
            child: Text('clear'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Lux.midnight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('done'.tr,
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      CustomerController controller, String customerId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _Lux.ruby.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _Lux.ruby, size: 20),
            ),
            const SizedBox(width: 10),
            Text('confirm_delete'.tr,
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '${'delete_customer_confirm'.tr} "$name"؟',
          style: GoogleFonts.cairo(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr,
                style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              controller.deleteCustomer(customerId);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_rounded,
                color: Colors.white, size: 16),
            label: Text('delete'.tr,
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Lux.ruby,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}