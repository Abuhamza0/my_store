// animated_hero_stat_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class _Lux {
  static const Color midnight = Color(0xFF0F172A);
}

class AnimatedHeroStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  /// قيمة من -1 (يسار) إلى 0 (المركز) إلى +1 (يمين)
  /// تُحسب خارجياً من موضع البطاقة في العجلة
  final double distortion;

  /// في حال كانت البطاقة خلفية (مخفية)، نُخفيها بالكامل
  final bool isBackground;

  const AnimatedHeroStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.distortion,
    this.onTap,
    this.isBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final double d = distortion.clamp(-1.0, 1.0);

    // 🎬 حسابات الحركة الساحرة
    final double scale = (1 - (d.abs() * 0.18)).clamp(0.82, 1.0);
    final double opacity = isBackground ? 0.0 : (1 - (d.abs() * 0.25)).clamp(0.75, 1.0);
    final double rotateY = d * 0.22;              // دوران ثلاثي الأبعاد
    final double rotateZ = d * 0.14;              // ميلان ثنائي (الذي نريده للعجلة)
    final double iconOffset = d * 35.0;           // Parallax للأيقونة الخلفية
    final double translateX = d * 82.0;           // الانزياح الأفقي

    return Transform.translate(
      offset: Offset(translateX, 0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)  // منظور 3D
          ..rotateY(rotateY)
          ..rotateZ(rotateZ)
          ..scale(scale),
        child: Opacity(
          opacity: opacity,
          child: _buildCardContent(iconOffset),
        ),
      ),
    );
  }

  Widget _buildCardContent(double iconOffset) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                accentColor,
                Color.lerp(accentColor, _Lux.midnight, 0.78) ?? accentColor,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.45),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.38),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // دائرة زخرفية تتحرك مع الـ parallax
              Positioned(
                left: -35 + (iconOffset * 0.5),
                bottom: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),

              // الأيقونة الضخمة مع Parallax عكسي
              Positioned(
                right: 12 - iconOffset,
                bottom: -10,
                child: Icon(
                  icon,
                  size: 92,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),

              // لمعة زجاجية علوية
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.40),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // المحتوى
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.28),
                            Colors.white.withOpacity(0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 27),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: Colors.white.withOpacity(0.90),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null)
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}