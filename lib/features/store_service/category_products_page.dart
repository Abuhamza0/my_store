import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'product_controller.dart';
import 'product_model.dart';
import 'add_product_page.dart';

class CategoryProductsPage extends StatelessWidget {
  final String categoryName;

  const CategoryProductsPage({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final ProductController productController = Get.find<ProductController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // تصفية المنتجات حسب الفئة
    final categoryProducts = productController.products
        .where((p) => p.category == categoryName)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: categoryProducts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_rounded, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('no_products_in_category'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey)),
            const SizedBox(height: 8),
            Text('add_products_to_category'.tr, style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Get.to(() => const AddProductPage()),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('add_product'.tr, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.62, crossAxisSpacing: 14, mainAxisSpacing: 14),
        itemCount: categoryProducts.length,
        itemBuilder: (context, index) => _buildProductCard(categoryProducts[index], productController),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const AddProductPage()),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('add_product'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProductCard(Product product, ProductController controller) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(color: Theme.of(Get.context!).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Stack(children: [
            Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), color: Colors.grey.shade100), child: Center(child: Icon(Icons.shopping_bag_rounded, size: 50, color: Colors.grey.shade300))),
            Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(12)), child: Text('${product.price.toStringAsFixed(0)} ${'currency'.tr}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
            Positioned(top: 10, right: 10, child: Row(children: [
              GestureDetector(onTap: () => Get.to(() => AddProductPage(product: product)), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_rounded, size: 14, color: Colors.blue))),
              const SizedBox(width: 4),
              GestureDetector(onTap: () { controller.deleteProduct(product.id); }, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_rounded, size: 14, color: Colors.red))),
            ])),
          ])),
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(product.description, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]))),
        ]),
      ),
    );
  }
}