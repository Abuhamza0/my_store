import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mystore/core/services/pairing_service.dart';
import 'package:mystore/core/services/store_id_service.dart';

import '../../core/services/session_service.dart';
import 'qr_scanner_page.dart';

class DeviceManagementPage extends StatefulWidget {
  const DeviceManagementPage({super.key});

  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  bool _isAddingDevice = false;

  @override
  Widget build(BuildContext context) {
    final storeId = StoreIdService.getStoreId();

    return Scaffold(
      appBar: AppBar(
        title: Text('device_management_title'.tr),
        backgroundColor: const Color(0xFF1D325E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAddingDevice ? null : _scanAndAddDevice,
        backgroundColor: const Color(0xFF1D325E),
        foregroundColor: Colors.white,
        icon: _isAddingDevice
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )
            : const Icon(Icons.qr_code_scanner_rounded),
        label: Text('add_device'.tr),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'trusted_devices'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D325E),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(  // ✅ تحديد النوع
              stream: FirebaseFirestore.instance
                  .collection('trusted_devices')
                  .doc(storeId)
                  .collection('devices')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices_other_rounded,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'no_trusted_devices'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'scan_to_add_device'.tr,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final deviceDoc = docs[index];
                    final deviceId = deviceDoc.id;
                    final data = deviceDoc.data(); // ✅ Map<String, dynamic>?
                    final trustedAt = data != null ? data['trusted_at'] as Timestamp? : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D325E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.devices_rounded,
                              color: Color(0xFF1D325E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  deviceId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D325E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (trustedAt != null)
                                  Text(
                                    '${'added_on'.tr}: ${_formatDate(trustedAt.toDate())}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            onPressed: () => _confirmRemoveDevice(storeId, deviceId),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // مسح رمز وإضافة جهاز
  // ═══════════════════════════════════════════════════════

  Future<void> _scanAndAddDevice() async {
    if (_isAddingDevice) return;
    setState(() => _isAddingDevice = true);

    try {
      final scannedCode = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );

      if (scannedCode == null || scannedCode.isEmpty) {
        setState(() => _isAddingDevice = false);
        return;
      }

      final storeId = StoreIdService.getStoreId();
      final deviceId = await SessionService.getDeviceId();

      final success = await PairingService.verifyPairingCode(
        scannedCode,
        storeId,
        deviceId,
      );

      if (success) {
        Get.snackbar(
          'success'.tr,
          'device_added_successfully'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'error'.tr,
          'invalid_qr_code'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ خطأ أثناء المسح: $e');
      Get.snackbar(
        'error'.tr,
        'scan_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingDevice = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // حذف جهاز
  // ═══════════════════════════════════════════════════════

  Future<void> _confirmRemoveDevice(String storeId, String deviceId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('remove_device'.tr),
        content: Text('remove_device_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('trusted_devices')
          .doc(storeId)
          .collection('devices')
          .doc(deviceId)
          .delete();

      Get.snackbar(
        'success'.tr,
        'device_removed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // تنسيق التاريخ
  // ═══════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}