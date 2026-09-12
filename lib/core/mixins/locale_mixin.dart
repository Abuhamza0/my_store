import 'package:flutter/material.dart';

/// Mixin بسيط لإعادة بناء الصفحة عند تغيير اللغة
mixin LocaleMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    _setupLocaleWatcher();
  }

  void _setupLocaleWatcher() {
    // ✅ نستخدم ever مع Rx متغير بسيط
    // أسهل طريقة: نضيف Listener يدوي
  }

  /// استدع هذه الدالة عند تغيير اللغة لتحديث الصفحة
  void refreshUI() {
    if (mounted) {
      setState(() {});
    }
  }
}