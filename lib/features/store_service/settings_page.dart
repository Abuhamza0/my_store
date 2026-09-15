// settings_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:universal_html/html.dart' as html;

import 'custom_category_model.dart';
import 'customer_controller.dart';
import 'order_controller.dart';
import 'product_controller.dart';
import 'store_home.dart';
import 'store_login_page.dart';
import 'package:mystore/core/services/locale_service.dart';

// ═══════════════════════════════════════════════════════════════
//  🎨 لوحة ألوان هادئة
// ═══════════════════════════════════════════════════════════════
abstract class _S {
  static const Color navy = Color(0xFF1A2332);
  static const Color navySoft = Color(0xFF2A3548);
  static const Color cream = Color(0xFFFAFBFD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8ECF2);
  static const Color textMuted = Color(0xFF8B95A5);

  static const Color blue = Color(0xFF5B8DEF);
  static const Color green = Color(0xFF34B37E);
  static const Color orange = Color(0xFFE89B4C);
  static const Color purple = Color(0xFF9B7DD4);
  static const Color red = Color(0xFFE85C5C);
  static const Color teal = Color(0xFF4DA8B0);

  static const Color darkBg = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1A2129);
  static const Color darkBorder = Color(0xFF2A323D);
}

// ═══════════════════════════════════════════════════════════════
//  ⚙️ Settings Page
// ═══════════════════════════════════════════════════════════════
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showPassword = false;
  bool _isDark = false;
  String _currentLang = 'ar';
  String _currency = 'SAR';
  String _storeName = '';

  final TextEditingController _storeNameController =
  TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final box = Hive.box('settings');
    setState(() {
      _isDark = box.get('is_dark_mode', defaultValue: false);
      _currentLang = box.get('language', defaultValue: 'ar');
      _currency = box.get('currency', defaultValue: 'SAR');
      _storeName = box.get('store_name', defaultValue: '');
      _storeNameController.text = _storeName;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔧 Actions
  // ═══════════════════════════════════════════════════════════════

  void _toggleDarkMode(bool value) {
    setState(() => _isDark = value);
    Hive.box('settings').put('is_dark_mode', value);
  }

  void _changeLanguage(String lang) {
    if (_currentLang == lang) return;
    setState(() => _currentLang = lang);
    Hive.box('settings').put('language', lang);
    LocaleService.changeLocale(lang);
  }

  void _changeCurrency(String currency) {
    if (_currency == currency) return;
    setState(() => _currency = currency);
    Hive.box('settings').put('currency', currency);
    _showSnack('done'.tr, '${'currency_changed_to'.tr} $currency');
  }

  void _saveStoreName() {
    final name = _storeNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _storeName = name);
    Hive.box('settings').put('store_name', name);
    _showSnack('done'.tr, 'store_name_saved'.tr);
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔔 Snackbar
  // ═══════════════════════════════════════════════════════════════

  void _showSnack(String title, String message, {bool isError = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      backgroundColor: isError ? _S.red : _S.navy,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      icon: Icon(
        isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
        color: Colors.white,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  📊 Admin Data
  // ═══════════════════════════════════════════════════════════════

  Map<String, String> get _adminData {
    final box = Hive.box('settings');
    return {
      'email': box.get('store_email', defaultValue: '').toString(),
      'password': box.get('store_password', defaultValue: '').toString(),
      'phone': box.get('store_phone', defaultValue: '').toString(),
      'isAdmin': box.get('is_admin', defaultValue: false).toString(),
    };
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔗 Links
  // ═══════════════════════════════════════════════════════════════

  void _generateSalesLink() {
    final box = Hive.box('settings');
    final storeId = box.get('store_id', defaultValue: '').toString();

    if (storeId.isEmpty) {
      _showSnack('error'.tr, 'no_store_id'.tr, isError: true);
      return;
    }

    final link = 'https://app.nithamsoft.com/sales?storeId=$storeId';
    _showLinkDialog(link, 'sales_link'.tr, 'copy_link_instruction'.tr);
  }

  void _generateLoginLink() {
    final box = Hive.box('settings');
    final storeId = box.get('store_id', defaultValue: '').toString();
    final email = box.get('store_email', defaultValue: '').toString();
    final password = box.get('store_password', defaultValue: '').toString();

    if (storeId.isEmpty || email.isEmpty) {
      _showSnack('error'.tr, 'no_store_id'.tr, isError: true);
      return;
    }

    final credentials = base64Url.encode(utf8.encode('$email:$password'));
    final link =
        'https://app.nithamsoft.com/login?storeId=$storeId&token=$credentials';
    _showLinkDialog(link, 'magic_login_link'.tr, 'magic_link_instruction'.tr);
  }

  void _showLinkDialog(String link, String title, String instruction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _S.blue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.link_rounded,
                color: _S.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              instruction,
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                color: _S.textMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _S.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _S.border),
              ),
              child: SelectableText(
                link,
                style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _S.navy,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _linkActionButton(
                  icon: Icons.copy_rounded,
                  label: 'copy_link'.tr,
                  color: _S.navy,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: link));
                    Navigator.pop(ctx);
                    _showSnack('done'.tr, 'link_copied'.tr);
                  },
                ),
                const SizedBox(width: 8),
                _linkActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: 'whatsapp'.tr,
                  color: const Color(0xFF25D366),
                  onTap: () {
                    launchUrlString(
                      'https://wa.me/?text=${Uri.encodeComponent(link)}',
                    );
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(width: 8),
                _linkActionButton(
                  icon: Icons.share_rounded,
                  label: 'share'.tr,
                  color: _S.blue,
                  onTap: () async {
                    await Share.share(link);
                    if (mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('close'.tr),
          ),
        ],
      ),
    );
  }

  Widget _linkActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  💾 Backup & Restore
  // ═══════════════════════════════════════════════════════════════

  Future<void> _createLocalBackup() async {
    try {
      final productsBox = Hive.box('products');
      final settingsBox = Hive.box('settings');

      final productsMap = <dynamic, dynamic>{};
      for (var key in productsBox.keys) {
        final value = productsBox.get(key);
        if (value is Map) {
          final productData = Map<dynamic, dynamic>.from(value);
          productData.remove('store_id');
          productData.remove('storeId');
          productsMap[key] = productData;
        } else {
          productsMap[key] = value;
        }
      }

      final categoriesData =
      settingsBox.get('custom_categories_data', defaultValue: []);

      final backupData = {
        'products': productsMap,
        'custom_categories_data': categoriesData,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final backupJson = jsonEncode(backupData);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(backupData);

      if (kIsWeb) {
        _showWebDownloadDialog(backupJson, prettyJson);
      } else {
        _showMobileSaveDialog(backupJson);
      }
    } catch (e) {
      debugPrint('❌ Backup error: $e');
      _showSnack('error'.tr, 'backup_create_failed'.tr, isError: true);
    }
  }

  void _showWebDownloadDialog(String json, String pretty) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('choose_download_type'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogOption(
              icon: Icons.code_rounded,
              color: _S.blue,
              title: 'download_json'.tr,
              subtitle: 'formatted_json_file'.tr,
              onTap: () {
                Navigator.pop(ctx);
                _downloadWebFile(json, 'json', 'application/json');
              },
            ),
            const Divider(height: 1),
            _dialogOption(
              icon: Icons.description_rounded,
              color: _S.teal,
              title: 'download_txt'.tr,
              subtitle: 'text_file'.tr,
              onTap: () {
                Navigator.pop(ctx);
                _downloadWebFile(pretty, 'txt', 'text/plain');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
        ],
      ),
    );
  }

  void _showMobileSaveDialog(String json) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('choose_save_method'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogOption(
              icon: Icons.save_rounded,
              color: _S.green,
              title: 'save_inside_app'.tr,
              onTap: () async {
                Navigator.pop(ctx);
                await Hive.box('settings').put('local_backup', json);
                if (!mounted) return;
                _showSnack('success'.tr, 'saved_inside_app'.tr);
              },
            ),
            const Divider(height: 1),
            _dialogOption(
              icon: Icons.share_rounded,
              color: _S.blue,
              title: 'share_as_json'.tr,
              onTap: () {
                Navigator.pop(ctx);
                Share.share(json, subject: 'backup'.tr);
              },
            ),
            const Divider(height: 1),
            _dialogOption(
              icon: Icons.folder_rounded,
              color: _S.orange,
              title: 'save_as_file'.tr,
              onTap: () async {
                Navigator.pop(ctx);
                await _saveBackupToFile(json);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
        ],
      ),
    );
  }

  Widget _dialogOption({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: GoogleFonts.cairo(
          fontSize: 11.5,
          color: _S.textMuted,
        ),
      )
          : null,
      onTap: onTap,
    );
  }

  void _downloadWebFile(String content, String ext, String mime) {
    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'backup_${DateTime.now().millisecondsSinceEpoch}.$ext',
        )
        ..click();
      html.Url.revokeObjectUrl(url);
      _showSnack('success'.tr, 'backup_downloaded'.tr);
    } catch (e) {
      debugPrint('❌ Download error: $e');
      _showSnack('error'.tr, 'backup_download_failed'.tr, isError: true);
    }
  }

  Future<void> _saveBackupToFile(String json) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final file = File(
        '${backupDir.path}/backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(json);
      await Hive.box('settings').put('last_backup_path', file.path);
      if (!mounted) return;
      _showSnack('success'.tr, 'file_saved'.tr);
    } catch (e) {
      debugPrint('❌ Save file error: $e');
      if (!mounted) return;
      _showSnack('error'.tr, 'backup_create_failed'.tr, isError: true);
    }
  }

  Future<void> _shareLocalBackup() async {
    try {
      final json = Hive.box('settings')
          .get('local_backup', defaultValue: '')
          ?.toString() ??
          '';
      if (json.isEmpty) {
        _showSnack('warning'.tr, 'no_local_backup'.tr);
        return;
      }
      await Share.share(json, subject: 'local_backup'.tr);
    } catch (e) {
      debugPrint('❌ Share error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  📥 Import Backup — نسخة مصححة لـ file_picker v12
  // ═══════════════════════════════════════════════════════════════


  Future<void> _restoreBackupData(Map<String, dynamic> data) async {
    // Products
    if (data.containsKey('products') && data['products'] is Map) {
      final box = Hive.box('products');
      await box.clear();
      (data['products'] as Map).forEach((key, value) {
        if (value is Map) {
          value.remove('store_id');
          value.remove('storeId');
        }
        box.put(key, value);
      });
      if (Get.isRegistered<ProductController>()) {
        Get.find<ProductController>().loadProducts();
      }
    }

    // Categories
    final raw = data['custom_categories_data'];
    if (raw != null) {
      final settingsBox = Hive.box('settings');
      if (raw is List) {
        final list = raw
            .map((item) {
          if (item is Map) return Map<String, dynamic>.from(item);
          if (item is String) {
            try {
              return jsonDecode(item) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          }
          return null;
        })
            .whereType<Map<String, dynamic>>()
            .toList();
        await settingsBox.put('custom_categories_data', list);
      } else if (raw is Map) {
        await settingsBox.put('custom_categories_data', raw);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  🔐 Change Password
  // ═══════════════════════════════════════════════════════════════

  void _showChangePasswordDialog(String currentPassword) {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'change_password'.tr,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _passwordField(
              currentPw,
              'current_password'.tr,
              Icons.lock_rounded,
            ),
            const SizedBox(height: 12),
            _passwordField(
              newPw,
              'new_password'.tr,
              Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 12),
            _passwordField(
              confirmPw,
              'confirm_password'.tr,
              Icons.check_circle_outline_rounded,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              final current = currentPw.text.trim();
              final newp = newPw.text.trim();
              final confirm = confirmPw.text.trim();

              if (current.isEmpty || newp.isEmpty || confirm.isEmpty) {
                _showSnack('error'.tr, 'all_fields_required'.tr,
                    isError: true);
                return;
              }
              if (current != currentPassword) {
                _showSnack('error'.tr, 'wrong_current_password'.tr,
                    isError: true);
                return;
              }
              if (newp.length < 6) {
                _showSnack('error'.tr, 'password_too_short'.tr,
                    isError: true);
                return;
              }
              if (newp != confirm) {
                _showSnack('error'.tr, 'password_mismatch'.tr,
                    isError: true);
                return;
              }

              await Hive.box('settings').put('store_password', newp);
              if (!mounted) return;
              Navigator.pop(ctx);
              setState(() {});
              _showSnack('done'.tr, 'password_updated'.tr);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _S.navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'save'.tr,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(
      TextEditingController controller,
      String label,
      IconData icon,
      ) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(fontSize: 13),
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🚪 Logout
  // ═══════════════════════════════════════════════════════════════

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'logout'.tr,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'logout_confirm'.tr,
          style: GoogleFonts.cairo(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('no'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // ✅ بدون await — عمليات متزامنة
              Hive.box('settings').put('store_logged_in', false);
              Hive.box('settings').put('is_admin', false);
              Get.offAll(() => const StoreLoginPage());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _S.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'yes'.tr,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  🎨 BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final admin = _adminData;
    final isAdmin = admin['isAdmin'] == 'true';
    final hasAccount =
        admin['email']!.isNotEmpty || admin['phone']!.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? _S.darkBg : _S.cream,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ Appearance ═══
            _SectionHeader(
              title: 'appearance'.tr,
              icon: Icons.palette_rounded,
              color: _S.purple,
              isDark: isDark,
            ),
            _Card(
              isDark: isDark,
              children: [
                _LanguageRow(
                  currentLang: _currentLang,
                  onChanged: _changeLanguage,
                  isDark: isDark,
                ),
                _Divider(isDark: isDark),
                _DarkModeRow(
                  value: _isDark,
                  onChanged: _toggleDarkMode,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ═══ Store ═══
            _SectionHeader(
              title: 'store_settings'.tr,
              icon: Icons.storefront_rounded,
              color: _S.orange,
              isDark: isDark,
            ),
            _Card(
              isDark: isDark,
              children: [
                _StoreNameRow(
                  controller: _storeNameController,
                  onSave: _saveStoreName,
                  isDark: isDark,
                ),
                _Divider(isDark: isDark),
                _CurrencyRow(
                  currentCurrency: _currency,
                  onChanged: _changeCurrency,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ═══ Links ═══
            _SectionHeader(
              title: 'store_links'.tr,
              icon: Icons.link_rounded,
              color: _S.blue,
              isDark: isDark,
            ),
            _Card(
              isDark: isDark,
              children: [
                _ActionTile(
                  icon: Icons.shopping_cart_rounded,
                  color: _S.blue,
                  label: 'generate_sales_link'.tr,
                  onTap: _generateSalesLink,
                ),
                if (hasAccount) ...[
                  _Divider(isDark: isDark),
                  _ActionTile(
                    icon: Icons.auto_awesome_rounded,
                    color: _S.purple,
                    label: 'generate_login_link'.tr,
                    onTap: _generateLoginLink,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // ═══ Backup ═══
            _SectionHeader(
              title: 'local_backup'.tr,
              icon: Icons.backup_rounded,
              color: _S.green,
              isDark: isDark,
            ),
            _Card(
              isDark: isDark,
              children: [
                _ActionTile(
                  icon: Icons.backup_rounded,
                  color: _S.green,
                  label: 'create_local_backup'.tr,
                  onTap: _createLocalBackup,
                ),
                _Divider(isDark: isDark),
                _ActionTile(
                  icon: Icons.share_rounded,
                  color: _S.blue,
                  label: 'share_backup_file'.tr,
                  onTap: _shareLocalBackup,
                ),

              ],
            ),
            const SizedBox(height: 24),

            // ═══ Account ═══
            if (hasAccount) ...[
              _SectionHeader(
                title: isAdmin ? 'admin_account_info'.tr : 'account_info'.tr,
                icon: Icons.person_rounded,
                color: _S.teal,
                isDark: isDark,
              ),
              _Card(
                isDark: isDark,
                children: [
                  if (admin['email']!.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.email_rounded,
                      color: _S.blue,
                      label: 'email'.tr,
                      value: admin['email']!,
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                  ],
                  if (admin['phone']!.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.phone_android_rounded,
                      color: _S.orange,
                      label: 'phone'.tr,
                      value: admin['phone']!,
                      isDark: isDark,
                    ),
                    _Divider(isDark: isDark),
                  ],
                  _PasswordRow(
                    password: admin['password']!,
                    isVisible: _showPassword,
                    onToggle: () =>
                        setState(() => _showPassword = !_showPassword),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.key_rounded,
                    color: _S.navy,
                    label: 'change_password'.tr,
                    onTap: () =>
                        _showChangePasswordDialog(admin['password']!),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // ═══ Logout ═══
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: _S.red,
                  size: 20,
                ),
                label: Text(
                  'logout'.tr,
                  style: GoogleFonts.cairo(
                    color: _S.red,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side:
                  BorderSide(color: _S.red.withOpacity(0.35), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ═══ Copyright ═══
            Center(
              child: Text(
                '© 2025 ${'nitham_soft'.tr}',
                style: GoogleFonts.cairo(
                  color: _S.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _S.navy,
      foregroundColor: Colors.white,
      centerTitle: true,
      title: Text(
        'settings'.tr,
        style: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Get.back(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  🧩 Widgets مساعدة
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _S.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _Card({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _S.darkSurface : _S.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? _S.darkBorder : _S.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.20 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? _S.darkBorder : _S.border,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: _S.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : _S.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _S.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRow extends StatelessWidget {
  final String password;
  final bool isVisible;
  final VoidCallback onToggle;
  final bool isDark;

  const _PasswordRow({
    required this.password,
    required this.isVisible,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _S.purple.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
            const Icon(Icons.lock_rounded, color: _S.purple, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'password'.tr,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: _S.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isVisible ? password : '•' * 8,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : _S.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: _S.textMuted,
                        size: 18,
                      ),
                      onPressed: onToggle,
                      tooltip: isVisible
                          ? 'hide_password'.tr
                          : 'show_password'.tr,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String currentLang;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _LanguageRow({
    required this.currentLang,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _S.orange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: _S.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'language'.tr,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: _S.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Chip(
                      label: 'العربية',
                      isSelected: currentLang == 'ar',
                      onTap: () => onChanged('ar'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'English',
                      isSelected: currentLang == 'en',
                      onTap: () => onChanged('en'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkModeRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _DarkModeRow({
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _S.navy.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              value ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: _S.navy,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value ? 'dark_mode_on'.tr : 'light_mode_on'.tr,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _S.purple,
          ),
        ],
      ),
    );
  }
}

class _StoreNameRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;
  final bool isDark;

  const _StoreNameRow({
    required this.controller,
    required this.onSave,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _S.orange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.store_rounded,
              color: _S.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : _S.navy,
              ),
              decoration: InputDecoration(
                labelText: 'store_name'.tr,
                labelStyle: GoogleFonts.cairo(
                  fontSize: 12,
                  color: _S.textMuted,
                ),
                hintText: 'enter_store_name'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => onSave(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: _S.green),
            onPressed: onSave,
            tooltip: 'save'.tr,
          ),
        ],
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  final String currentCurrency;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _CurrencyRow({
    required this.currentCurrency,
    required this.onChanged,
    required this.isDark,
  });

  static const _currencies = {
    'SAR': '﷼',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'د.إ',
    'EGP': 'ج.م',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _S.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: _S.green,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'currency'.tr,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: _S.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _currencies.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final code = _currencies.keys.elementAt(index);
                      final symbol = _currencies[code]!;
                      return _Chip(
                        label: '$code ($symbol)',
                        isSelected: currentCurrency == code,
                        onTap: () => onChanged(code),
                        isDark: isDark,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? _S.navy
              : (isDark ? _S.darkBorder : _S.cream),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _S.navy
                : (isDark ? _S.darkBorder : _S.border),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : _S.navy),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}