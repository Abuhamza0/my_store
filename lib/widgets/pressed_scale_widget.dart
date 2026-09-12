import 'package:flutter/material.dart';

class PressedScaleWidget extends StatefulWidget {
  final Widget child;
  final double scaleFactor;
  final Duration duration;
  final VoidCallback? onTap;        // الأكشن عند الضغط العادي
  final VoidCallback? onLongPress;  // الأكشن عند الضغطة المطولة

  const PressedScaleWidget({
    super.key,
    required this.child,
    this.scaleFactor = 0.95, // نسبة التصغير (0.95 تعني 5%)
    this.duration = const Duration(milliseconds: 100),
    this.onTap,
    this.onLongPress,
  });

  @override
  State<PressedScaleWidget> createState() => _PressedScaleWidgetState();
}

class _PressedScaleWidgetState extends State<PressedScaleWidget> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // عند الضغط لأسفل
      onTapDown: (_) {
        setState(() {
          _scale = widget.scaleFactor;
        });
      },
      // عند رفع الإصبع (اكتمال الضغطة)
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      // عند سحب الإصبع للخارج أو الإلغاء
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      // عند الضغطة المطولة
      onLongPress: widget.onLongPress,

      // حركة التصغير والتكبير
      child: AnimatedScale(
        scale: _scale,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}