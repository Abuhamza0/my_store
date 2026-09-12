import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ استيراد FirebaseAuth

class InteractiveBellIcon extends StatefulWidget {
  final VoidCallback onTap;

  const InteractiveBellIcon({super.key, required this.onTap});

  @override
  State<InteractiveBellIcon> createState() => _InteractiveBellIconState();
}

class _InteractiveBellIconState extends State<InteractiveBellIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _lastCount = 0;
  Stream<QuerySnapshot>? _ordersStream;

  // ✅ دالة الحصول على الـ UID (المعرف الموحد لصاحب المتجر)
  String _getStoreId() {
    // 1. الأولوية القصوى: قراءة uid من الحساب
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      // حفظ uid في Hive لضمان توفرها دائماً
      Hive.box('settings').put('store_id', uid);
      return uid;
    }

    // 2. احتياطي: قراءة store_id المحفوظة في Hive
    final storedId = Hive.box('settings').get('store_id', defaultValue: '');
    if (storedId.toString().isNotEmpty) {
      return storedId.toString();
    }

    // 3. احتياطي أخير: توليد من البريد الإلكتروني (لا يُفضل)
    final email = Hive.box('settings').get('store_email', defaultValue: '')?.toString() ?? '';
    return email.isNotEmpty
        ? email.trim().replaceAll('@', '_').replaceAll('.', '_')
        : 'default_store';
  }

  @override
  void initState() {
    super.initState();

    final storeId = _getStoreId();
    print('🔔 جرس - storeId: $storeId');

    // ✅ الاستماع للطلبات الجديدة غير المقروءة فقط (بناءً على الصورة المرفقة)
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('store_id', isEqualTo: storeId) // ✅ تصحيح اسم الحقل ليطابق الصورة
        .where('isRead', isEqualTo: false)     // ✅ الطلبات غير المقروءة فقط
        .where('status', isEqualTo: 'pending') // ✅ الطلبات قيد الانتظار فقط
        .snapshots();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification3.mp3'));
    } catch (e) {
      print('❌ خطأ في الصوت: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: StreamBuilder<QuerySnapshot>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

          // ✅ تشغيل الصوت عند وصول طلب جديد فعلياً (زيادة العدد عن الصفر)
          if (count > _lastCount && _lastCount != 0) {
            _playNotificationSound();
          }
          _lastCount = count;

          print('🔔 عدد الطلبات الجديدة: $count');

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (count > 0)
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        size: 26,
                        color: Colors.amberAccent,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                if (count > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A2332), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Center(
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}