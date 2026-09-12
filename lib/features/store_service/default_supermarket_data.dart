import 'package:hive/hive.dart';
import 'custom_category_model.dart';
import 'product_model.dart';
import 'product_controller.dart';
import 'customer_model.dart';
import 'customer_controller.dart';

class DefaultSupermarketData {

  // ==================== استيراد كل شيء ====================
  static Future<void> importAll(ProductController productController) async {
    print('📦 بدء الاستيراد...');

    final categories = _getCategories();
    await Hive.box('settings').put('custom_categories_data', categories.map((c) => c.toJson()).toList());
    print('✅ تم حفظ ${categories.length} قسم');

    final products = _getProducts();
    for (var product in products) {
      await Hive.box('products').put(product.id, product.toJson());
    }
    print('✅ تم حفظ ${products.length} منتج');

    final customers = _getCustomers();
    for (var customer in customers) {
      await Hive.box('customers').put(customer.id, customer.toJson());
    }
    print('✅ تم حفظ ${customers.length} عميل');

    print('📦 عملاء Hive بعد الحفظ: ${Hive.box('customers').length}');

    productController.loadProducts();
  }
  // ==================== استيراد الفئات فقط ====================
  static Future<void> importCategoriesOnly() async {
    final categories = _getCategories();
    await Hive.box('settings').put('custom_categories_data', categories.map((c) => c.toJson()).toList());
  }

  // ==================== استيراد المنتجات فقط ====================
  static Future<void> importProductsOnly(ProductController productController) async {
    for (var product in _getProducts()) {
      await Hive.box('products').put(product.id, product.toJson());
    }
    productController.loadProducts();
  }

  // ==================== استيراد العملاء فقط ====================
  static Future<void> importCustomersOnly(CustomerController customerController) async {
    for (var customer in _getCustomers()) {
      await Hive.box('customers').put(customer.id, customer.toJson());
    }
    customerController.loadCustomers();
  }

  // ==================== الأقسام (مأكولات) ====================
  static List<CustomCategory> _getCategories() {
    return [
      // ✅ قسم: مأكولات
      CustomCategory(
        name: 'مأكولات',
        subCategories: [
          // صنف: مشويات
          SubCategory(
            name: 'مشويات',
            flavors: [
              Flavor(name: 'دجاج'),
              Flavor(name: 'لحم'),
              Flavor(name: 'كبدة'),
              Flavor(name: 'ريش'),
            ],
            subCategories: [
              // نوع: مشاوي دجاج
              SubCategory(
                name: 'مشاوي دجاج',
                flavors: [],
                subCategories: [],
              ),
              // نوع: مشاوي لحم
              SubCategory(
                name: 'مشاوي لحم',
                flavors: [],
                subCategories: [],
              ),
              // نوع: برجر دجاج
              SubCategory(
                name: 'برجر دجاج',
                flavors: [],
                subCategories: [],
              ),
              // نوع: برجر لحم
              SubCategory(
                name: 'برجر لحم',
                flavors: [],
                subCategories: [],
              ),
            ],
          ),
          // صنف: مقبلات
          SubCategory(
            name: 'مقبلات',
            flavors: [
              Flavor(name: 'حار'),
              Flavor(name: 'عادي'),
            ],
            subCategories: [
              SubCategory(name: 'سلطات', flavors: [], subCategories: []),
              SubCategory(name: 'شوربات', flavors: [], subCategories: []),
              SubCategory(name: 'مقليات', flavors: [], subCategories: []),
            ],
          ),
          // صنف: حلويات
          SubCategory(
            name: 'حلويات',
            flavors: [
              Flavor(name: 'شوكولاتة'),
              Flavor(name: 'فانيليا'),
              Flavor(name: 'فراولة'),
              Flavor(name: 'كراميل'),
            ],
            subCategories: [
              SubCategory(name: 'كيك', flavors: [], subCategories: []),
              SubCategory(name: 'بسكويت', flavors: [], subCategories: []),
              SubCategory(name: 'كنافة', flavors: [], subCategories: []),
            ],
          ),
          // صنف: مشروبات
          SubCategory(
            name: 'مشروبات',
            flavors: [
              Flavor(name: 'برتقال'),
              Flavor(name: 'ليمون'),
              Flavor(name: 'مانجو'),
              Flavor(name: 'فراولة'),
            ],
            subCategories: [
              SubCategory(name: 'عصائر', flavors: [], subCategories: []),
              SubCategory(name: 'مشروبات غازية', flavors: [], subCategories: []),
              SubCategory(name: 'قهوة', flavors: [], subCategories: []),
            ],
          ),
        ],
      ),

      // ✅ قسم: مخبوزات
      CustomCategory(
        name: 'مخبوزات',
        subCategories: [
          // صنف: خبز
          SubCategory(
            name: 'خبز',
            flavors: [
              Flavor(name: 'أبيض'),
              Flavor(name: 'أسمر'),
              Flavor(name: 'شعير'),
            ],
            subCategories: [
              SubCategory(name: 'خبز عربي', flavors: [], subCategories: []),
              SubCategory(name: 'خبز فرنسي', flavors: [], subCategories: []),
              SubCategory(name: 'خبز توست', flavors: [], subCategories: []),
            ],
          ),
          // صنف: معجنات
          SubCategory(
            name: 'معجنات',
            flavors: [
              Flavor(name: 'جبن'),
              Flavor(name: 'لحم'),
              Flavor(name: 'خضار'),
            ],
            subCategories: [
              SubCategory(name: 'فطائر', flavors: [], subCategories: []),
              SubCategory(name: 'بيتزا', flavors: [], subCategories: []),
              SubCategory(name: 'سمبوسة', flavors: [], subCategories: []),
            ],
          ),
        ],
      ),
    ];
  }

  // ==================== المنتجات (مأكولات) ====================
  static List<Product> _getProducts() {
    return [
      Product(
        id: 'food_001',
        name: 'شيش طاووق',
        description: 'شيش طاووق مشوي على الفحم مع الخضار',
        price: 35.00,
        category: 'مشاوي دجاج',
        imagePath: 'assets/images/product_placeholder.png',
        stock: 50,
        rating: 4.8,
        reviewCount: 350,
        flavor: 'دجاج',
        hasMultipleSizes: true,
        sizes: [
          ProductSize(name: 'نصف كيلو', price: 35.00, stock: 30),
          ProductSize(name: 'كيلو كامل', price: 65.00, stock: 20),
        ],
      ),
      Product(
        id: 'food_002',
        name: 'أوراك مشوية',
        description: 'أوراك دجاج متبلة ومشوية',
        price: 30.00,
        category: 'مشاوي دجاج',
        imagePath: 'assets/images/product_placeholder.png',
        stock: 40,
        rating: 4.7,
        reviewCount: 280,
        flavor: 'دجاج',
        hasMultipleSizes: false,
      ),
      Product(
        id: 'food_003',
        name: 'برجر لحم كلاسيك',
        description: 'برجر لحم بقري مع الجبن والخضار',
        price: 25.00,
        category: 'برجر لحم',
        imagePath: 'assets/images/product_placeholder.png',
        stock: 60,
        rating: 4.6,
        reviewCount: 420,
        flavor: 'لحم',
        hasMultipleSizes: true,
        sizes: [
          ProductSize(name: 'عادي', price: 25.00, stock: 40),
          ProductSize(name: 'دبل', price: 40.00, stock: 20),
        ],
      ),
      Product(
        id: 'food_004',
        name: 'سلطة سيزر',
        description: 'سلطة سيزر مع الدجاج والجبن',
        price: 18.00,
        category: 'سلطات',
        imagePath: 'assets/images/product_placeholder.png',
        stock: 30,
        rating: 4.5,
        reviewCount: 200,
        flavor: 'عادي',
        hasMultipleSizes: false,
      ),
      Product(
        id: 'food_005',
        name: 'كيك شوكولاتة',
        description: 'كيك شوكولاتة فاخر مع صوص الشوكولاتة',
        price: 15.00,
        category: 'كيك',
        imagePath: 'assets/images/product_placeholder.png',
        stock: 25,
        rating: 4.9,
        reviewCount: 380,
        flavor: 'شوكولاتة',
        hasMultipleSizes: true,
        sizes: [
          ProductSize(name: 'قطعة', price: 15.00, stock: 20),
          ProductSize(name: 'كيكة كاملة', price: 80.00, stock: 5),
        ],
      ),
      Product(
        id: 'food_006',
        name: 'عصير مانجو طازج',
        description: 'عصير مانجو طبيعي 100%',
        price: 12.00,
        category: 'عصائر',
        imagePath: 'assets/images/product_placeholder.png',
        stock: 80,
        rating: 4.7,
        reviewCount: 300,
        flavor: 'مانجو',
        hasMultipleSizes: true,
        sizes: [
          ProductSize(name: 'صغير', price: 12.00, stock: 50),
          ProductSize(name: 'كبير', price: 18.00, stock: 30),
        ],
      ),
      Product(
        id: 'food_007',
        name: 'خبز عربي طازج',
        description: 'خبز عربي طازج يومياً',
        price: 5.00,
        category: 'خبز عربي',
        imagePath: 'assets/images/product_placeholder.png',
        stock: 100,
        rating: 5.0,
        reviewCount: 500,
        flavor: 'أبيض',
        hasMultipleSizes: true,
        sizes: [
          ProductSize(name: 'حبة', price: 5.00, stock: 80),
          ProductSize(name: 'ربطة (5 حبات)', price: 20.00, stock: 20),
        ],
      ),
      Product(
        id: 'food_008',
        name: 'فطيرة جبن',
        description: 'فطيرة محشوة بالجبن الطازج',
        price: 8.00,
        category: 'فطائر',
        imagePath: 'assets/images/product_placeholder.png',
        stock: 50,
        rating: 4.5,
        reviewCount: 180,
        flavor: 'جبن',
        hasMultipleSizes: false,
      ),
    ];
  }

  // ==================== العملاء ====================
  static List<Customer> _getCustomers() {
    return [
      Customer(
        id: 'customer_001',
        name: 'أحمد محمد',
        phone: '+966512345678',
        password: Customer.hashPassword('1234'),
        isActive: true,
        loginMethod: 'credentials',
        createdAt: DateTime.now(),
        lastOrderDate: DateTime.now(),
      ),
      Customer(
        id: 'customer_002',
        name: 'خالد عبدالله',
        phone: '+966598765432',
        password: '',
        isActive: true,
        loginMethod: 'phone',
        createdAt: DateTime.now(),
        lastOrderDate: DateTime.now(),
      ),
      Customer(
        id: 'customer_003',
        name: 'سارة علي',
        phone: '+966555555555',
        password: Customer.hashPassword('5678'),
        isActive: true,
        loginMethod: 'credentials',
        createdAt: DateTime.now(),
        lastOrderDate: DateTime.now(),
      ),
    ];
  }
}