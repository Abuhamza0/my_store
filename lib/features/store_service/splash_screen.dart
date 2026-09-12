import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'store_home.dart';
class StoreServiceSplash extends StatefulWidget {
  const StoreServiceSplash({super.key});

  @override
  State<StoreServiceSplash> createState() => _StoreServiceSplashState();
}

class _StoreServiceSplashState extends State<StoreServiceSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // ✅ الانتقال للصفحة الرئيسية
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Get.off(() => const StoreServiceHome());
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D325E), Color(0xFF2A4B8C), Color(0xFF3B6BC4)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
                ),
                child: const Icon(Icons.store_rounded, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 40),
              const Text(
                'خدمة متجري',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
              ),
              const SizedBox(height: 20),
              const Text(
                'لحظات ويتم تجهيز خدمتك',
                style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}