// Premium_Product_Expanded_View.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/image_helper.dart';
import 'order_model.dart';
import 'product_model.dart';

class PremiumProductExpandedView extends StatefulWidget {
  final Product product;
  final List<String> images;
  final PageController pageController;
  final RxInt currentIndex;
  final RxList<OrderItem> cart;
  final RxDouble total;
  final bool isDark;
  final String currency;
  final BuildContext parentContext;
  final VoidCallback onAddToCart;
  final bool isAddedToCart;

  const PremiumProductExpandedView({
    Key? key,
    required this.product,
    required this.images,
    required this.pageController,
    required this.currentIndex,
    required this.cart,
    required this.total,
    required this.isDark,
    required this.currency,
    required this.parentContext,
    required this.onAddToCart,
    this.isAddedToCart = false,
  }) : super(key: key);

  @override
  State<PremiumProductExpandedView> createState() =>
      _PremiumProductExpandedViewState();
}

class _PremiumProductExpandedViewState
    extends State<PremiumProductExpandedView> {
  final Map<int, TransformationController> _zoomControllers = {};

  late int _localCurrentIndex;

  int get currentIndex => _localCurrentIndex;

  @override
  void initState() {
    super.initState();
    _localCurrentIndex = widget.currentIndex.value;
  }

  TransformationController _getZoomController(int index) {
    return _zoomControllers.putIfAbsent(
      index,
          () => TransformationController(),
    );
  }

  void _resetZoom(int index) {
    final controller = _zoomControllers[index];
    if (controller != null) {
      controller.value = Matrix4.identity();
    }
  }

  void _nextImage() {
    if (_localCurrentIndex >= widget.images.length - 1) return;
    widget.pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousImage() {
    if (_localCurrentIndex <= 0) return;
    widget.pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _addToCartDirectly() {
    final p = widget.product;
    final idx = widget.cart.indexWhere((i) => i.productId == p.id);
    if (idx != -1) {
      final e = widget.cart[idx];
      widget.cart[idx] = OrderItem(
        productId: p.id,
        productName: p.name,
        price: p.price,
        quantity: e.quantity + 1,
        total: p.price * (e.quantity + 1),
      );
    } else {
      widget.cart.add(OrderItem(
        productId: p.id,
        productName: p.name,
        price: p.price,
        quantity: 1,
        total: p.price,
      ));
    }
    widget.total.value = widget.cart.fold(0.0, (s, i) => s + i.total);
    widget.cart.refresh();
  }

  @override
  void dispose() {
    for (final controller in _zoomControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = widget.images;
    final isDark = widget.isDark;

    final background = isDark ? const Color(0xFF151C2B) : Colors.white;
    final surface = isDark ? const Color(0xFF1B2435) : const Color(0xFFF7F8FA);
    final textColor = isDark ? Colors.white : const Color(0xFF172033);
    final secondaryText = isDark ? Colors.white70 : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      width: MediaQuery.of(context).size.width * 0.88,
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (images.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_rounded,
                            color: Color(0xFFD4AF37), size: 15),
                        const SizedBox(width: 5),
                        Text(
                          '${_localCurrentIndex + 1}/${images.length}',
                          style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: textColor, size: 21),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Image Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.38,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D1320)
                    : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: widget.pageController,
                      itemCount: images.length,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) {
                        _resetZoom(_localCurrentIndex);
                        setState(() {
                          _localCurrentIndex = index;
                          widget.currentIndex.value = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final zoomController = _getZoomController(index);
                        return InteractiveViewer(
                          transformationController: zoomController,
                          minScale: 1.0,
                          maxScale: 3.5,
                          boundaryMargin: const EdgeInsets.all(40),
                          clipBehavior: Clip.hardEdge,
                          child: Center(
                            child: ImageHelper.displayImage(
                              imagePath: images[index],
                              fit: BoxFit.contain,
                              placeholder:
                              _buildPremiumImageLoading(isDark),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (images.length > 1 && _localCurrentIndex > 0)
                    Positioned(
                      left: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _buildGalleryArrow(
                          icon: Icons.chevron_left_rounded,
                          onTap: _previousImage,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  if (images.length > 1 && _localCurrentIndex < images.length - 1)
                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _buildGalleryArrow(
                          icon: Icons.chevron_right_rounded,
                          onTap: _nextImage,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'zoom'.tr,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Thumbnails
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final selected = index == _localCurrentIndex;
                    return GestureDetector(
                      onTap: () {
                        widget.pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: selected ? 64 : 56,
                        height: selected ? 56 : 50,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFD4AF37)
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: selected
                              ? [
                            BoxShadow(
                                color: const Color(0xFFD4AF37)
                                    .withOpacity(0.25),
                                blurRadius: 10)
                          ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: ImageHelper.displayImage(
                            imagePath: images[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Details
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.currency}${p.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 19,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 14, color: secondaryText),
                            const SizedBox(width: 5),
                            Text('${p.stock}',
                                style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (p.flavor != null && p.flavor!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Text('🍹', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            p.flavor!,
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (p.description.isNotEmpty)
                    Text(
                      p.description,
                      style: TextStyle(
                          color: secondaryText,
                          fontSize: 13,
                          height: 1.55),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (p.description.isEmpty)
                    Text(
                      'no_description'.tr,
                      style: TextStyle(color: secondaryText, fontSize: 13),
                    ),
                ],
              ),
            ),
          ),

          // Add Button
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAddToCart();
                },
                icon: const Icon(
                  Icons.add_shopping_cart_rounded,
                  color: Colors.white,
                  size: 19,
                ),
                label: Text(
                  widget.isAddedToCart ? 'done'.tr : 'add_to_cart'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isAddedToCart ? Colors.green : const Color(0xFF1A2332),
                  disabledBackgroundColor: Colors.green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryArrow({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 40,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.38),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildPremiumImageLoading(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1320) : const Color(0xFFF0F2F5),
      ),
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
          ),
        ),
      ),
    );
  }
}