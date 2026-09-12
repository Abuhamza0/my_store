import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../store/promo_management_page.dart';
import 'active_sessions_page.dart';
import 'connected_stores_page.dart';
import 'store_home.dart';
import 'store_login_page.dart';

class ActivationCodesPage extends StatefulWidget {
  const ActivationCodesPage({super.key});

  @override
  State<ActivationCodesPage> createState() => _ActivationCodesPageState();
}

class _ActivationCodesPageState extends State<ActivationCodesPage> {
  List<String> _codes = [];
  List<String> _usedCodes = [];
  List<Map<String, dynamic>> _activatedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadCodes();
    _loadActivatedAccounts();
  }

  void _loadCodes() {
    final settingsBox = Hive.box('settings');
    final rawCodes =
    settingsBox.get('activation_codes', defaultValue: <dynamic>[]);
    final rawUsed =
    settingsBox.get('used_codes', defaultValue: <dynamic>[]);

    // ✅ تحويل صريح لتجنب خطأ النوع
    _codes = List<String>.from(rawCodes);
    _usedCodes = List<String>.from(rawUsed);
    setState(() {});
  }

  // ✅ تحميل الحسابات المفعلة - مع الإصلاح
  void _loadActivatedAccounts() {
    final settingsBox = Hive.box('settings');
    final rawData =
    settingsBox.get('activated_accounts', defaultValue: <dynamic>[]);

    // ✅ تحويل كل عنصر إلى Map<String, dynamic> بشكل آمن
    _activatedAccounts = [];
    if (rawData is List) {
      for (var item in rawData) {
        if (item is Map) {
          _activatedAccounts
              .add(Map<String, dynamic>.from(item));
        }
      }
    }
    setState(() {});
  }

  String _generateCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code = '';
    for (int i = 0; i < 4; i++) {
      String segment = '';
      for (int j = 0; j < 4; j++) {
        segment += chars[random.nextInt(chars.length)];
      }
      code += (i > 0 ? '-' : '') + segment;
    }
    return code;
  }

  void _generateNewCode() {
    final newCode = _generateCode();
    setState(() => _codes.add(newCode));
    Hive.box('settings').put('activation_codes', _codes);
    Get.snackbar(
      'done'.tr,
      '${'code_generated'.tr}: $newCode',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  void _generateMultipleCodes() {
    final countController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('generate_multiple_codes'.tr),
        content: TextField(
          controller: countController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'codes_count_label'.tr,
            hintText: 'codes_count_hint'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(countController.text) ?? 1;
              for (int i = 0; i < count; i++) {
                _codes.add(_generateCode());
              }
              Hive.box('settings').put('activation_codes', _codes);
              Navigator.pop(ctx);
              setState(() {});
              Get.snackbar(
                'done'.tr,
                '${'codes_generated_count'.tr} $count ${'codes_label'.tr}',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2332)),
            child: Text(
              'create'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ تسجيل الخروج
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('logout'.tr),
        content: Text('logout_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Hive.box('settings').put('store_logged_in', false);
              Hive.box('settings').put('is_admin', false);
              Get.offAll(() => const StoreLoginPage());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'logout'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableCodes =
    _codes.where((c) => !_usedCodes.contains(c)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('manage_codes_title'.tr),
        backgroundColor: const Color(0xFF1A2332),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_rounded),
            tooltip: 'إدارة البطاقات الدعائية',
            onPressed: () => Get.to(() => const PromoManagementPage()),
          ),
          IconButton(
            icon: const Icon(Icons.store_rounded, color: Colors.white),
            onPressed: () =>
                Get.offAll(() => const StoreServiceHome()),
            tooltip: 'my_store'.tr,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: 'logout'.tr,
          ),
          IconButton(
            icon: const Icon(Icons.devices_rounded),
            onPressed: () => Get.to(() => const ActiveSessionsPage()),
            tooltip: 'active_sessions'.tr,
          ),
          IconButton(
            icon: const Icon(Icons.online_prediction_rounded),
            onPressed: () => Get.to(() => const ConnectedStoresPage()),
            tooltip: 'connected_stores'.tr,
          ),
        ],
      ),
      body: Column(
        children: [
          // أزرار إنشاء الأكواد
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateNewCode,
                    icon: const Icon(Icons.add_rounded,
                        color: Colors.white),
                    label: Text(
                      'one_code'.tr,
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2332),
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateMultipleCodes,
                    icon: const Icon(Icons.add_circle_rounded,
                        color: Colors.white),
                    label: Text(
                      'multiple_codes'.tr,
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // إحصائيات
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statCard(
                  'available_codes'.tr,
                  '${availableCodes.length}',
                  Colors.green,
                ),
                const SizedBox(width: 10),
                _statCard(
                  'used_codes'.tr,
                  '${_usedCodes.length}',
                  Colors.red,
                ),
                const SizedBox(width: 10),
                _statCard(
                  'activated_accounts'.tr,
                  '${_activatedAccounts.length}',
                  Colors.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // تبويبات: الأكواد + الحسابات المفعلة
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: const Color(0xFF1A2332),
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'available_tab'.tr),
                      Tab(text: 'used_tab'.tr),
                      Tab(text: 'activated_tab'.tr),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // ✅ الأكواد المتاحة
                        availableCodes.isEmpty
                            ? Center(
                          child: Text(
                            'no_available_codes'.tr,
                            style: const TextStyle(
                                color: Colors.grey),
                          ),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: availableCodes.length,
                          itemBuilder: (c, i) =>
                              _buildCodeCard(
                                  availableCodes[i],
                                  isUsed: false),
                        ),

                        // ✅ الأكواد المستخدمة
                        _usedCodes.isEmpty
                            ? Center(
                          child: Text(
                            'no_used_codes'.tr,
                            style: const TextStyle(
                                color: Colors.grey),
                          ),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _usedCodes.length,
                          itemBuilder: (c, i) =>
                              _buildCodeCard(_usedCodes[i],
                                  isUsed: true),
                        ),

                        // ✅ الحسابات المفعلة
                        _activatedAccounts.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Icon(
                                  Icons.people_outline_rounded,
                                  size: 60,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'no_activated_accounts'.tr,
                                style: const TextStyle(
                                    color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount:
                          _activatedAccounts.length,
                          itemBuilder: (c, i) {
                            final account =
                            _activatedAccounts[i];
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.blue
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.store_rounded,
                                          color: Colors.blue,
                                          size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          account[
                                          'store_name'] ??
                                              'no_name'.tr,
                                          style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                            fontSize: 15,
                                            color:
                                            Color(0xFF1A2332),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _infoRow(
                                    Icons.email_rounded,
                                    account['email'] ?? '',
                                  ),
                                  const SizedBox(height: 4),
                                  _infoRow(
                                    Icons.vpn_key_rounded,
                                    account[
                                    'activation_code'] ??
                                        '',
                                  ),
                                  const SizedBox(height: 4),
                                  _infoRow(
                                    Icons.calendar_today_rounded,
                                    account[
                                    'activation_date'] ??
                                        '',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(String code, {required bool isUsed}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUsed
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUsed ? Icons.block_rounded : Icons.vpn_key_rounded,
            color: isUsed ? Colors.red : Colors.green,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              code,
              style: TextStyle(
                fontSize: isUsed ? 16 : 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 2,
                color: isUsed ? Colors.grey : Colors.black87,
                decoration:
                isUsed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (!isUsed)
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  color: Color(0xFF1A2332)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Get.snackbar(
                  'done'.tr,
                  'code_copied'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            Text(
              label,
              style:
              TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}