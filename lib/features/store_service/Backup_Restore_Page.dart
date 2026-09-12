import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mystore/core/services/store_id_service.dart';
import 'package:mystore/core/services/sync_service.dart';
import 'package:mystore/features/store_service/store_home.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _isSearching = false;
  bool _isRestoring = false;
  Map<String, dynamic>? _backupInfo;
  Timer? _autoSearchTimer;
  bool _autoSearchCompleted = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startAutoSearch();
  }

  @override
  void dispose() {
    _autoSearchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════
  // البحث التلقائي لمدة 30 ثانية
  // ════════════════════════════════════════════════════════
  void _startAutoSearch() {
    setState(() {
      _isSearching = true;
      _autoSearchCompleted = false;
    });

    _autoSearchTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _autoSearchCompleted = true;
      });
      if (_backupInfo == null) {
        Get.snackbar(
          'auto_search_finished_title'.tr,
          'auto_search_finished_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    });

    _performSearch(silent: true);
  }

  // ════════════════════════════════════════════════════════
  // البحث اليدوي (بدون مهلة زمنية)
  // ════════════════════════════════════════════════════════
  Future<void> _manualSearch() async {
    if (_autoSearchTimer != null && _autoSearchTimer!.isActive) {
      _autoSearchTimer!.cancel();
    }
    setState(() {
      _isSearching = true;
      _autoSearchCompleted = false;
    });

    // ✅ استخدام القيمة المدخلة إن وجدت
    final query = _searchController.text.trim();
    await _performSearch(query: query.isEmpty ? null : query);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _autoSearchCompleted = true;
      });
    }
  }

  // ════════════════════════════════════════════════════════
  // تنفيذ البحث (مع دعم storeId أو email)
  // ════════════════════════════════════════════════════════
  Future<void> _performSearch({bool silent = false, String? query}) async {
    try {
      String storeId = StoreIdService.getStoreId();

      // إذا كان هناك استعلام يدوي، نحدد storeId منه
      if (query != null && query.isNotEmpty) {
        if (query.contains('@')) {
          // البريد الإلكتروني: نحوله إلى storeId بنفس الطريقة
          storeId = query.trim().toLowerCase().replaceAll('@', '_').replaceAll('.', '_');
        } else {
          // storeId مباشرة
          storeId = query.trim();
        }
      }

      if (storeId.isEmpty) {
        if (!silent) {
          Get.snackbar(
            'error'.tr,
            'store_id_empty'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
        return;
      }

      // ✅ البحث في المجموعة store_backups
      final doc = await FirebaseFirestore.instance
          .collection('store_backups')
          .doc(storeId)
          .get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        setState(() {
          _backupInfo = doc.data();
          _isSearching = false;
        });
        if (!silent) {
          Get.snackbar(
            'backup_found_title'.tr,
            'backup_found_message'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        }
      } else {
        if (!silent) {
          Get.snackbar(
            'no_backup_title'.tr,
            'no_backup_message'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      if (!silent) {
        Get.snackbar(
          'backup_search_error_title'.tr,
          '${'backup_search_error_message'.tr}: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isSearching = false);
      }
    }
  }

  // ════════════════════════════════════════════════════════
  // استعادة النسخة
  // ════════════════════════════════════════════════════════
  Future<void> _restoreBackup() async {
    setState(() => _isRestoring = true);

    final syncService = SyncService();
    final success = await syncService.restoreBackup();

    if (!mounted) return;

    setState(() => _isRestoring = false);

    if (success) {
      Get.snackbar(
        'restore_success_title'.tr,
        'restore_success_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.offAll(() => const StoreServiceHome());
    } else {
      Get.snackbar(
        'restore_failed_title'.tr,
        'restore_failed_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ════════════════════════════════════════════════════════
  // تأكيد التخطي مع تحذير
  // ════════════════════════════════════════════════════════
  Future<void> _confirmSkip() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('skip_warning_title'.tr),
        content: Text('skip_warning_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('skip'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Get.offAll(() => const StoreServiceHome());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('backup_restore_page_title'.tr),
        backgroundColor: const Color(0xFF1D325E),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // حالة البحث
    if (_isSearching) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('searching_backup_message'.tr),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _confirmSkip,
            child: Text('skip'.tr),
          ),
        ],
      );
    }

    // لا توجد نسخة بعد اكتمال البحث
    if (_backupInfo == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 90,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'no_backup_found_title'.tr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'no_backup_found_message'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          // ✅ حقل إدخال للبحث اليدوي بـ storeId أو email
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'store_id_or_email'.tr,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _manualSearch,
            icon: const Icon(Icons.search_rounded),
            label: Text('search_for_backup'.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D325E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _confirmSkip,
            child: Text('skip'.tr),
          ),
        ],
      );
    }

    // تم العثور على نسخة
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_done_rounded,
          size: 90,
          color: Colors.green,
        ),
        const SizedBox(height: 20),
        Text(
          'backup_found_title'.tr,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'backup_date'.tr,
                  value: _backupInfo!['timestamp'] != null
                      ? (_backupInfo!['timestamp'] as Timestamp).toDate().toString()
                      : 'unknown'.tr,
                ),
                const Divider(height: 20),
                _infoRow(
                  icon: Icons.inventory_2_rounded,
                  label: 'products_count'.tr,
                  value: '${(_backupInfo!['products'] as Map?)?.length ?? 0}',
                ),
                const SizedBox(height: 12),
                _infoRow(
                  icon: Icons.people_rounded,
                  label: 'customers_count'.tr,
                  value: '${(_backupInfo!['customers'] as Map?)?.length ?? 0}',
                ),
                const SizedBox(height: 12),
                _infoRow(
                  icon: Icons.folder_rounded,
                  label: 'categories_count'.tr,
                  value: '${(_backupInfo!['custom_categories_data'] as List?)?.length ?? 0}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: _isRestoring ? null : _restoreBackup,
          icon: _isRestoring
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Icon(Icons.restore_rounded),
          label: Text('restore_now'.tr),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _confirmSkip,
          child: Text('skip'.tr),
        ),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1D325E)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D325E),
          ),
        ),
      ],
    );
  }
}