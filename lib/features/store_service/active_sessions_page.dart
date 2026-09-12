import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mystore/core/services/store_id_service.dart';

class ActiveSessionsPage extends StatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  State<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends State<ActiveSessionsPage> {
  @override
  Widget build(BuildContext context) {
    final storeId = StoreIdService.getStoreId();

    return Scaffold(
      appBar: AppBar(
        title: Text('active_sessions_title'.tr),
        backgroundColor: const Color(0xFF1D325E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('store_devices')
            .doc(storeId)
            .collection('sessions')
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
                  Icon(Icons.wifi_off_rounded,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'no_active_sessions'.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final sessions = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final deviceId = session.id;
              final data = session.data();
              final lastActive = data['last_active'] as Timestamp?;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.devices_rounded,
                        color: Colors.green,
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
                          if (lastActive != null)
                            Text(
                              '${'last_active'.tr}: ${_formatTime(lastActive.toDate())}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // زر إنهاء الجلسة
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.red),
                      onPressed: () => _confirmEndSession(storeId, deviceId),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmEndSession(String storeId, String deviceId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('end_session'.tr),
        content: Text('end_session_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('end'.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('store_devices')
          .doc(storeId)
          .collection('sessions')
          .doc(deviceId)
          .delete();

      Get.snackbar(
        'success'.tr,
        'session_ended'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now'.tr;
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes_ago'.tr;
    if (diff.inHours < 24) return '${diff.inHours} hours_ago'.tr;
    return '${diff.inDays} days_ago'.tr;
  }
}