// add_customer_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide debugPrint;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/services/store_id_service.dart';
import 'customer_model.dart';
import 'customer_controller.dart';
import '../../services/cloud_service.dart';
import 'sales_screen.dart';
import '../../../core/services/locale_service.dart';

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

class AddCustomerPage extends StatefulWidget {
  final Customer? customer;

  const AddCustomerPage({super.key, this.customer});

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();

  final CustomerController _customerController = Get.find();
  bool _isLoading = false;

  // ✨ أنيميشن دخول الحقول
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ✨ مفاتيح التركيز
  final _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();

    if (widget.customer != null) {
      _phoneController.text = widget.customer!.phone;
      _nameController.text = widget.customer!.name;
    }

    ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _phoneFocus.dispose();
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

  // ═══════════════════════════════════════════════════════════════
  //  المنطق البرمجي (محفوظ بالكامل بدون تغيير)
  // ═══════════════════════════════════════════════════════════════

  void _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final formattedPhone = _phoneController.text.trim();

    final existingPhone = _customerController.customers.firstWhereOrNull(
          (c) => c.phone == formattedPhone && c.id != widget.customer?.id,
    );
    if (existingPhone != null) {
      Get.snackbar(
        'warning'.tr,
        'phone_exists'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _Lux.amber,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storeId = _getStoreId();

      final customer = Customer(
        id: widget.customer?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        phone: formattedPhone,
        password: '',
        isActive: true,
        loginMethod: 'phone',
      );

      if (widget.customer != null) {
        _customerController.updateCustomer(customer);
      } else {
        _customerController.addCustomer(customer);
      }

      try {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(customer.id)
            .set({
          'id': customer.id,
          'name': customer.name,
          'phone': customer.phone,
          'password': '',
          'store_id': storeId,
          'isActive': true,
          'loginMethod': 'phone',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ Customer saved to cloud - storeId: $storeId');
      } catch (e) {
        print('❌ Cloud save error: $e');
      }

      setState(() => _isLoading = false);
      Get.back();
      _showStoreQRCode(customer);
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'error'.tr,
        'save_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _Lux.ruby,
        colorText: Colors.white,
      );
    }
  }

  void _showStoreQRCode(Customer customer) {
    final storeUrl = _getStoreUrl();
    final storeName = Hive.box('settings')
        .get('store_name', defaultValue: 'my_store'.tr)
        ?.toString() ??
        'my_store'.tr;

    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: _Lux.bgLight,
            body: SafeArea(
              child: Column(
                children: [
                  // ═══ هيدر ذهبي فاخر ═══
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: _Lux.royalGold,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _Lux.gold.withOpacity(0.40),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.store_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (rect) =>
                                    const LinearGradient(
                                      colors: [
                                        Colors.white,
                                        _Lux.champagne,
                                        Colors.white,
                                      ],
                                    ).createShader(rect),
                                child: Text(
                                  storeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                'your_store_link'.tr,
                                style: GoogleFonts.cairo(
                                  color: Colors.white54,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(dialogContext),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 19),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ═══ معلومات العميل ═══
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _Lux.emerald.withOpacity(0.10),
                                  _Lux.emerald.withOpacity(0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _Lux.emerald.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _Lux.emerald.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.person_add_rounded,
                                      color: _Lux.emerald,
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _Lux.midnight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        customer.phone,
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        textDirection: TextDirection.ltr,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: _Lux.emerald,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ═══ رمز QR بتصميم ذهبي ═══
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _Lux.gold.withOpacity(0.40),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _Lux.gold.withOpacity(0.20),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // شعار صغير فوق QR
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        gradient: _Lux.royalGold,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.qr_code_2_rounded,
                                          color: Colors.white,
                                          size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'امسح الرمز',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _Lux.midnight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                RepaintBoundary(
                                  key: _qrKey,
                                  child: QrImageView(
                                    data: storeUrl,
                                    version: QrVersions.auto,
                                    size: 210,
                                    backgroundColor: Colors.white,
                                    foregroundColor: _Lux.midnight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ═══ الرابط ═══
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _Lux.gold.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _Lux.gold.withOpacity(0.22),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.link_rounded,
                                    color: _Lux.goldDeep, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    storeUrl,
                                    style: GoogleFonts.cairo(
                                      fontSize: 10.5,
                                      color: _Lux.midnight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ═══ أزرار النسخ والمشاركة ═══
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.copy_rounded,
                                  label: 'copy'.tr,
                                  gradient: _Lux.midnightSky,
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: storeUrl));
                                    Get.snackbar(
                                      'done'.tr,
                                      'link_copied'.tr,
                                      backgroundColor: _Lux.emerald,
                                      colorText: Colors.white,
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.share_rounded,
                                  label: 'share'.tr,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2563EB),
                                      Color(0xFF1E40AF)
                                    ],
                                  ),
                                  onPressed: () async {
                                    try {
                                      final boundary = _qrKey.currentContext
                                          ?.findRenderObject()
                                      as RenderRepaintBoundary?;
                                      if (boundary != null) {
                                        final image = await boundary
                                            .toImage(pixelRatio: 3.0);
                                        final byteData =
                                        await image.toByteData(
                                            format: ui.ImageByteFormat
                                                .png);
                                        if (byteData != null) {
                                          final tempDir =
                                          await getTemporaryDirectory();
                                          final file = File(
                                              '${tempDir.path}/qr_store.png');
                                          await file.writeAsBytes(byteData
                                              .buffer
                                              .asUint8List());
                                          await Share.shareXFiles(
                                            [XFile(file.path)],
                                            text:
                                            '🏪 $storeName\n🔗 $storeUrl',
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      await Share.share(
                                          '🏪 $storeName\n🔗 $storeUrl');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ═══ زر فتح المتجر ═══
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: _buildActionButton(
                              icon: Icons.storefront_rounded,
                              label: 'open_store'.tr,
                              gradient: _Lux.royalGold,
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Get.to(() => SalesScreen(
                                  storeIdFromUrl: _getStoreId(),
                                  showBackButton: true,
                                ));
                              },
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ═══ زر تم ═══
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Get.back();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _Lux.gold.withOpacity(0.45),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'done'.tr,
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _Lux.midnight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 13,
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
  //  🎨 الصفحة الرئيسية
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.customer != null;

    return Scaffold(
      backgroundColor: isDark ? _Lux.bgDark : _Lux.bgLight,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildHeader(isEditing, isSmallScreen, isDark),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(isSmallScreen ? 16 : 22),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        _buildInfoCard(isSmallScreen, isDark),
                        SizedBox(height: isSmallScreen ? 22 : 30),
                        _buildNameField(isDark),
                        const SizedBox(height: 14),
                        _buildPhoneField(isDark),
                        SizedBox(height: isSmallScreen ? 26 : 36),
                        _buildSaveButton(isSmallScreen),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎯 الهيدر الفاخر
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(bool isEditing, bool isSmallScreen, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 14,
        right: 14,
        bottom: isSmallScreen ? 18 : 24,
      ),
      decoration: BoxDecoration(
        gradient: _Lux.midnightSky,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _Lux.gold.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // زر الرجوع
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Get.back(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 17),
                  ),
                ),
              ),
              const Spacer(),
              // شعار QR متوهج
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _Lux.royalGold,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _Lux.gold.withOpacity(0.45),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: Colors.white, size: 28),
              ),
              const Spacer(),
              // زر إفراغ (placeholder للحفاظ على التوازن)
              const SizedBox(width: 40),
            ],
          ),
          SizedBox(height: isSmallScreen ? 14 : 18),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [Colors.white, _Lux.champagne, Colors.white],
            ).createShader(rect),
            child: Text(
              isEditing ? 'edit_customer_title'.tr : 'add_customer_title'.tr,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: isSmallScreen ? 19 : 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'store_link_will_be_created'.tr,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: Colors.white60,
              fontSize: isSmallScreen ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ℹ️ بطاقة المعلومات
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInfoCard(bool isSmallScreen, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _Lux.sapphire.withOpacity(0.10),
            _Lux.sapphire.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _Lux.sapphire.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _Lux.sapphire.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: _Lux.sapphire, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'store_link_will_be_created'.tr,
              style: GoogleFonts.cairo(
                fontSize: isSmallScreen ? 11 : 12,
                color: isDark ? Colors.white70 : _Lux.midnight,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  📝 حقل الاسم (للقراءة فقط)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildNameField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Icon(Icons.person_rounded, size: 14, color: _Lux.violet),
              const SizedBox(width: 6),
              Text(
                'name_auto_filled'.tr,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : _Lux.midnight,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: _nameController,
          readOnly: true,
          style: GoogleFonts.cairo(
            color: Colors.grey.shade500,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'name_auto_filled'.tr,
            hintStyle: GoogleFonts.cairo(
              color: Colors.grey.shade500,
              fontSize: 12.5,
            ),
            prefixIcon: Icon(Icons.person_rounded,
                color: _Lux.violet.withOpacity(0.6), size: 20),
            filled: true,
            fillColor: isDark
                ? _Lux.navyCard.withOpacity(0.5)
                : Colors.grey.shade100,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  📱 حقل رقم الهاتف (الحقل الأساسي)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPhoneField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: _Lux.royalGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.phone_android_rounded,
                    size: 12, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                '${'phone_number'.tr} *',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : _Lux.midnight,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.done,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : _Lux.midnight,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            hintText: 'phone_hint'.tr,
            hintStyle: GoogleFonts.cairo(
              color: Colors.grey.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _Lux.royalGold,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _Lux.gold.withOpacity(0.30),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.phone_android_rounded,
                  color: Colors.white, size: 18),
            ),
            filled: true,
            fillColor: isDark ? _Lux.navyCard : Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? _Lux.gold.withOpacity(0.15)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? _Lux.gold.withOpacity(0.15)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _Lux.gold, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _Lux.ruby, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _Lux.ruby, width: 1.8),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'phone_required'.tr;
            return null;
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  💾 زر الحفظ الفاخر
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSaveButton(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      height: isSmallScreen ? 54 : 58,
      decoration: BoxDecoration(
        gradient: _isLoading
            ? LinearGradient(
            colors: [Colors.grey.shade400, Colors.grey.shade600])
            : _Lux.royalGold,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _isLoading
            ? []
            : [
          BoxShadow(
            color: _Lux.gold.withOpacity(0.42),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isLoading ? null : _saveCustomer,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                else
                  const Icon(Icons.qr_code_2_rounded,
                      color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  _isLoading ? 'saving'.tr : 'save_create_link'.tr,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14 : 16,
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
}