// settings_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/services.dart';
import 'custom_category_model.dart';
import 'customer_controller.dart';
import 'order_controller.dart';
import 'product_controller.dart';
import 'store_home.dart';
import 'store_login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showPassword = false;
  bool _isDark = false;
  String _currentLang = 'ar';
  String _currency = 'USD';
  String _storeName = '';
  final TextEditingController _storeNameController = TextEditingController();

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
      _currency = box.get('currency', defaultValue: 'USD');
      _storeName = box.get('store_name', defaultValue: '');
      _storeNameController.text = _storeName;
    });
  }

  void _toggleDarkMode(bool value) {
    setState(() => _isDark = value);
    final box = Hive.box('settings');
    box.put('is_dark_mode', value);
  }

  void _changeLanguage(String lang) {
    setState(() => _currentLang = lang);
    final box = Hive.box('settings');
    box.put('language', lang);
    Get.updateLocale(Locale(lang));
  }

  void _changeCurrency(String currency) {
    setState(() => _currency = currency);
    final box = Hive.box('settings');
    box.put('currency', currency);
    Get.snackbar(
      'done'.tr,
      '${'currency_changed_to'.tr} $currency',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  void _saveStoreName() {
    final name = _storeNameController.text.trim();
    if (name.isNotEmpty) {
      setState(() => _storeName = name);
      final box = Hive.box('settings');
      box.put('store_name', name);
      Get.snackbar(
        'done'.tr,
        'store_name_saved'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  Map<String, String> get adminData {
    final box = Hive.box('settings');
    final email = box.get('store_email', defaultValue: '');
    final password = box.get('store_password', defaultValue: '');
    final phone = box.get('store_phone', defaultValue: '');
    final isAdmin = box.get('is_admin', defaultValue: false);

    return {
      'email': email.toString(),
      'password': password.toString(),
      'phone': phone.toString(),
      'isAdmin': isAdmin.toString(),
    };
  }

  String _getStoreId() {
    try {
      final settingsBox = Hive.box('settings');

      final email = settingsBox.get('store_email', defaultValue: '');
      if (email != null && email.toString().trim().isNotEmpty) {
        return email.toString().trim().replaceAll('@', '_').replaceAll('.', '_');
      }

      final storeName = settingsBox.get('store_name', defaultValue: '');
      if (storeName != null && storeName.toString().trim().isNotEmpty) {
        return 'store_${storeName.toString().trim().toLowerCase().replaceAll(' ', '_')}';
      }

      final oldStoreId = settingsBox.get('store_id', defaultValue: '');
      if (oldStoreId != null && oldStoreId.toString().trim().isNotEmpty) {
        return oldStoreId.toString().trim();
      }

      final newStoreId = 'store_${DateTime.now().millisecondsSinceEpoch}';
      settingsBox.put('store_id', newStoreId);
      return newStoreId;
    } catch (e) {
      print('❌ Error in _getStoreId: $e');
      return 'default_store';
    }
  }

  void _generateSalesLink(BuildContext context) async {
    final box = Hive.box('settings');
    final storeId = box.get('store_id', defaultValue: '');
    final storeName = box.get('store_name', defaultValue: 'my_store'.tr);

    if (storeId.isEmpty) {
      Get.snackbar('error'.tr, 'no_store_id'.tr, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final link = 'https://app.nithamsoft.com/sales?storeId=$storeId';
    _showLinkDialog(context, link, 'sales_link'.tr);
  }

  void _showLinkDialog(BuildContext context, String link, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF2196F3), size: 28),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'copy_link_instruction'.tr,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1A2332)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    Get.snackbar('done'.tr, 'link_copied'.tr, backgroundColor: Colors.green, colorText: Colors.white);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                  label: Text('copy_link'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2332),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(link)}';
                    launchUrlString(whatsappUrl);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                  label: Text('whatsapp'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Share.share(link);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  label: Text('share'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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

  void _showLoginLinkDialog(BuildContext context, String link) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF2196F3), size: 28),
            const SizedBox(width: 12),
            Text('magic_login_link'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'magic_link_instruction'.tr,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1A2332)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    Get.snackbar('done'.tr, 'link_copied'.tr, backgroundColor: Colors.green, colorText: Colors.white);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                  label: Text('copy_link'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2332),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(link)}';
                    launchUrlString(whatsappUrl);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                  label: Text('whatsapp'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Share.share(link);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  label: Text('share'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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

  Future<void> _createLocalBackup() async {
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

    final categoriesData = settingsBox.get('custom_categories_data', defaultValue: []);

    final backupData = {
      'products': productsMap,
      'custom_categories_data': categoriesData,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final backupJson = jsonEncode(backupData);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(backupData);

    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('choose_download_type'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.code_rounded, color: Color(0xFF2196F3)),
                title: Text('download_json'.tr),
                subtitle: Text('formatted_json_file'.tr),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadBackupFile(backupJson, 'json', 'application/json');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.description_rounded, color: Colors.teal),
                title: Text('download_txt'.tr),
                subtitle: Text('text_file'.tr),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadBackupFile(prettyJson, 'txt', 'text/plain');
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
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('choose_save_method'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_rounded, color: Color(0xFF4CAF50)),
              title: Text('save_inside_app'.tr),
              onTap: () {
                Navigator.pop(ctx);
                _saveBackupToHive(backupJson);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Color(0xFF2196F3)),
              title: Text('share_as_json'.tr),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(backupJson, subject: 'backup'.tr);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_rounded, color: Color(0xFFFF9800)),
              title: Text('save_as_file'.tr),
              onTap: () {
                Navigator.pop(ctx);
                _saveBackupToFile(backupJson);
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

  void _downloadBackupFile(String content, String extension, String mimeType) {
    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'backup_${DateTime.now().millisecondsSinceEpoch}.$extension')
        ..click();
      html.Url.revokeObjectUrl(url);

      Get.snackbar('success'.tr, 'backup_downloaded'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e) {
      print('❌ Download failed: $e');
      Get.snackbar('error'.tr, 'backup_download_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }

  Future<void> _saveBackupToHive(String backupJson) async {
    try {
      final settingsBox = Hive.box('settings');
      await settingsBox.put('local_backup', backupJson);
      Get.snackbar('success'.tr, 'saved_inside_app'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e) {
      print('❌ Failed: $e');
    }
  }

  Future<void> _saveBackupToFile(String backupJson) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(backupJson);
      await Hive.box('settings').put('last_backup_path', file.path);
      Get.snackbar('success'.tr, 'file_saved'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e) {
      print('❌ Failed: $e');
    }
  }

  Future<void> _shareLocalBackup() async {
    try {
      final settingsBox = Hive.box('settings');
      final backupJson = settingsBox.get('local_backup', defaultValue: '')?.toString() ?? '';

      if (backupJson.isEmpty) {
        Get.snackbar('warning'.tr, 'no_local_backup'.tr);
        return;
      }

      await Share.share(backupJson, subject: 'local_backup'.tr);
    } catch (e) {
      print('❌ Share failed: $e');
    }
  }

  Future<void> _importBackupFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.isEmpty) return;

      final file = result.first;
      final bytes = await file.xFile.readAsBytes();
      final backupJson = utf8.decode(bytes);

      final backupData = jsonDecode(backupJson);
      if (backupData is! Map<String, dynamic>) {
        throw Exception('invalid_file'.tr);
      }

      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: Text('restore_backup'.tr),
          content: Text('restore_backup_confirm'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('restore'.tr, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _restoreBackupData(backupData);

      Get.snackbar('success'.tr, 'backup_restored_successfully'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e) {
      print('❌ Import failed: $e');
      Get.snackbar('error'.tr, 'backup_import_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }

  Future<void> _restoreBackupData(Map<String, dynamic> data) async {
    try {
      print('📦 Starting data restore...');

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
        print('✅ Products restored');
      }

      final raw = data['custom_categories_data'];
      if (raw != null) {
        final settingsBox = Hive.box('settings');

        if (raw is List) {
          final normalizedList = raw.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else if (item is String) {
              try {
                return jsonDecode(item);
              } catch (_) {
                return null;
              }
            }
            return null;
          }).whereType<Map<String, dynamic>>().toList();

          await settingsBox.put('custom_categories_data', normalizedList);
          print('✅ Categories restored');
        } else if (raw is Map) {
          await settingsBox.put('custom_categories_data', raw);
        }
      }
    } catch (e) {
      print('❌ Restore error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final admin = adminData;
    final isAdmin = admin['isAdmin'] == 'true';
    final hasAccount = admin['email']!.isNotEmpty || admin['phone']!.isNotEmpty;
    final currencySymbols = {
      'USD': '\$',
      'SAR': '﷼',
      'EUR': '€',
      'GBP': '£',
      'AED': 'د.إ',
      'EGP': 'ج.م',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr),
        backgroundColor: const Color(0xFF1A2332),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionHeader('appearance'.tr, Icons.palette_rounded, const Color(0xFF667eea)),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildLanguageRow(isDark),
                    const Divider(),
                    _buildDarkModeRow(isDark),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Backup Section
            _buildSectionHeader('local_backup'.tr, Icons.backup_rounded, const Color(0xFF4CAF50)),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _createLocalBackup(),
                        icon: const Icon(Icons.backup_rounded, color: Colors.white, size: 16),
                        label: Text(
                          'create_local_backup'.tr,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _shareLocalBackup(),
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 16),
                        label: Text(
                          'share_backup_file'.tr,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _importBackupFromFile,
                        icon: const Icon(Icons.file_upload_rounded, color: Colors.white, size: 16),
                        label: Text(
                          'import_backup_from_file'.tr,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Store Settings Section
            _buildSectionHeader('store_settings'.tr, Icons.storefront_rounded, const Color(0xFFFF9800)),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStoreNameRow(isDark),
                    const Divider(),
                    _buildCurrencyRow(isDark, currencySymbols),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Store Links Section
            _buildSectionHeader('store_links'.tr, Icons.link_rounded, const Color(0xFF667eea)),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _generateSalesLink(context),
                        icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 16),
                        label: Text(
                          'generate_sales_link'.tr,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2332),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Admin Account Section
            if (hasAccount) ...[
              _buildSectionHeader(
                isAdmin ? 'admin_account_info'.tr : 'account_info'.tr,
                Icons.admin_panel_settings_rounded,
                const Color(0xFF4CAF50),
              ),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (admin['email']!.isNotEmpty) ...[
                        _buildInfoRow(
                          icon: Icons.email_rounded,
                          label: 'email'.tr,
                          value: admin['email']!,
                          iconColor: const Color(0xFF2196F3),
                          isDark: isDark,
                        ),
                        const Divider(),
                      ],
                      if (admin['phone']!.isNotEmpty) ...[
                        _buildInfoRow(
                          icon: Icons.phone_android_rounded,
                          label: 'phone'.tr,
                          value: admin['phone']!,
                          iconColor: const Color(0xFFFF9800),
                          isDark: isDark,
                        ),
                        const Divider(),
                      ],
                      _buildPasswordRow(
                        password: admin['password']!,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showChangePasswordDialog(context, admin['email']!, admin['password']!),
                          icon: const Icon(Icons.key_rounded, color: Colors.white, size: 16),
                          label: Text(
                            'change_password'.tr,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2332),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _generateSalesLink(context),
                          icon: const Icon(Icons.link_rounded, color: Colors.white, size: 16),
                          label: Text(
                            'generate_login_link'.tr,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                label: Text(
                  'logout'.tr,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Copyright
            Center(
              child: Text(
                '© 2025 ${'nitham_soft'.tr}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A2332),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreNameRow(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.store_rounded, color: Color(0xFFFF9800), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'store_name'.tr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _storeNameController,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A2332),
                      ),
                      decoration: InputDecoration(
                        hintText: 'enter_store_name'.tr,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _saveStoreName(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.save_rounded, color: Color(0xFFFF9800)),
                    onPressed: _saveStoreName,
                    tooltip: 'save'.tr,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyRow(bool isDark, Map<String, String> symbols) {
    final currencies = ['USD', 'SAR', 'EUR', 'GBP', 'AED', 'EGP'];

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF4CAF50), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'currency'.tr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: currencies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final code = currencies[index];
                    final isSelected = _currency == code;
                    final symbol = symbols[code] ?? code;
                    return GestureDetector(
                      onTap: () => _changeCurrency(code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF4CAF50) : const Color(0xFF1A2332))
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? const Color(0xFF4CAF50) : const Color(0xFF1A2332))
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '$code ($symbol)',
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRow({
    required String password,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFf093fb).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_rounded, color: Color(0xFFf093fb), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'password'.tr,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showPassword ? password : '•' * 8,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A2332),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      tooltip: _showPassword ? 'hide_password'.tr : 'show_password'.tr,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

  Widget _buildLanguageRow(bool isDark) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.language_rounded, color: Color(0xFFFF9800), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'language'.tr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildLangButton('ar', 'العربية', isDark),
                  const SizedBox(width: 8),
                  _buildLangButton('en', 'English', isDark),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLangButton(String lang, String label, bool isDark) {
    final isSelected = _currentLang == lang;
    return GestureDetector(
      onTap: () => _changeLanguage(lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF667eea) : const Color(0xFF1A2332))
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF667eea) : const Color(0xFF1A2332))
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDarkModeRow(bool isDark) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.dark_mode_rounded, color: Color(0xFF1A2332), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'dark_mode'.tr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Switch(
                value: _isDark,
                onChanged: _toggleDarkMode,
                activeThumbColor: const Color(0xFF1A2332),
                activeTrackColor: const Color(0xFF1A2332).withOpacity(0.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context, String email, String currentPassword) {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('change_password'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPw,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'current_password'.tr,
                prefixIcon: const Icon(Icons.lock_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPw,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'new_password'.tr,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPw,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'confirm_password'.tr,
                prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
                Get.snackbar('error'.tr, 'all_fields_required'.tr, backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }

              if (current != currentPassword) {
                Get.snackbar('error'.tr, 'wrong_current_password'.tr, backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }

              if (newp.length < 6) {
                Get.snackbar('error'.tr, 'password_too_short'.tr, backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }

              if (newp != confirm) {
                Get.snackbar('error'.tr, 'password_mismatch'.tr, backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }

              final box = Hive.box('settings');
              box.put('store_password', newp);
              Navigator.pop(ctx);
              setState(() {});
              Get.snackbar('done'.tr, 'password_updated'.tr, backgroundColor: Colors.green, colorText: Colors.white);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2332),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('save'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('logout'.tr),
        content: Text('logout_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('no'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final settingsBox = Hive.box('settings');
              settingsBox.put('store_logged_in', false);
              settingsBox.put('is_admin', false);
              Get.offAll(() => const StoreLoginPage());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('yes'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}