import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConnectedStoresPage extends StatefulWidget {
  const ConnectedStoresPage({super.key});

  @override
  State<ConnectedStoresPage> createState() => _ConnectedStoresPageState();
}

class _ConnectedStoresPageState extends State<ConnectedStoresPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('connected_stores'.tr),
        backgroundColor: const Color(0xFF1D325E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('store_devices')
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
                  Icon(Icons.storefront_rounded,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'no_stores_found'.tr,
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

          final stores = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              final data = store.data();
              final storeId = store.id;
              final storeName = data['store_name']?.toString() ?? storeId;
              final isOnline = data['is_online'] ?? false;
              final lastActive = data['last_active'] as Timestamp?;
              final isSubscribed = data['is_subscribed'] ?? false;
              final subscriptionType = data['subscription_type']?.toString() ?? 'free';

              return _buildStoreCard(
                storeId: storeId,
                storeName: storeName,
                isOnline: isOnline,
                lastActive: lastActive,
                isSubscribed: isSubscribed,
                subscriptionType: subscriptionType,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStoreCard({
    required String storeId,
    required String storeName,
    required bool isOnline,
    required Timestamp? lastActive,
    required bool isSubscribed,
    required String subscriptionType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? Colors.green.withOpacity(0.4) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: isOnline ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D325E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  storeId,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                // ✅ عرض أنواع الأجهزة
                FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  future: FirebaseFirestore.instance
                      .collection('store_devices')
                      .doc(storeId)
                      .collection('sessions')
                      .get()
                      .then((snap) => snap.docs),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    final sessions = snapshot.data ?? [];
                    if (sessions.isEmpty) {
                      return Text(
                        'no_devices'.tr,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: sessions.map((session) {
                        final deviceType = session.data()['device_type']?.toString() ?? 'unknown';
                        return Tooltip(
                          message: deviceType,
                          child: Icon(
                            _iconForDeviceType(deviceType),
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                if (lastActive != null)
                  Text(
                    '${'last_active'.tr}: ${_formatTime(lastActive.toDate())}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSubscribed
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isSubscribed
                  ? 'activated_account'.tr
                  : subscriptionType == 'trial'
                  ? 'trial_account'.tr
                  : 'free_account'.tr,
              style: TextStyle(
                color: isSubscribed ? Colors.green : Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForDeviceType(String type) {
    switch (type) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
        return Icons.language;
      case 'windows':
        return Icons.laptop_windows;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.device_unknown;
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