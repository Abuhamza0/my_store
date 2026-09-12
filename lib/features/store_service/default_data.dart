import 'package:hive/hive.dart';
import 'product_controller.dart';
import 'customer_controller.dart';
import 'product_model.dart';
import 'customer_model.dart';

class DefaultData {
  // ==================== المنتجات الافتراضية ====================
  static List<Product> getDefaultProducts() {
    return [
      Product(
        name: 'آيفون 15 برو ماكس',
        description: 'أحدث إصدار من آيفون مع شاشة 6.7 بوصة وكاميرا 48 ميجابكسل ومعالج A17 Pro',
        price: 5999,
        category: 'إلكترونيات',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 15,
        rating: 4.8,
        reviewCount: 256,
      ),
      Product(
        name: 'ساعة أبل الترا 2',
        description: 'ساعة ذكية متطورة مع شاشة Retina ومقاومة للماء وعمر بطارية يصل إلى 36 ساعة',
        price: 3499,
        category: 'ساعات',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 10,
        rating: 4.9,
        reviewCount: 189,
      ),
      Product(
        name: 'سماعات ايربودز برو',
        description: 'سماعات لاسلكية مع خاصية إلغاء الضوضاء النشطة ومكبر صوت مخصص عالي الاستطاعة',
        price: 1099,
        category: 'إلكترونيات',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 30,
        rating: 4.7,
        reviewCount: 412,
      ),
      Product(
        name: 'لابتوب ديل XPS 15',
        description: 'لابتوب احترافي بشاشة 4K ومعالج i9 ورام 32GB وقرص 1TB SSD',
        price: 7999,
        category: 'إلكترونيات',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 8,
        rating: 4.6,
        reviewCount: 67,
      ),
      Product(
        name: 'جهاز بلايستيشن 5',
        description: 'أحدث جهاز ألعاب من سوني مع قرص 825GB SSD ودعم 8K',
        price: 2299,
        category: 'إلكترونيات',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: false,
        stock: 0,
        rating: 4.9,
        reviewCount: 890,
      ),
      Product(
        name: 'قميص رجالي كلاسيك',
        description: 'قميص قطني 100% تصميم كلاسيكي أنيق مناسب للعمل والمناسبات الرسمية',
        price: 199,
        category: 'ملابس',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 50,
        rating: 4.3,
        reviewCount: 87,
      ),
      Product(
        name: 'فستان سهرة أنيق',
        description: 'فستان سهرة طويل بتصميم عصري مع تطريز يدوي فاخر',
        price: 499,
        category: 'ملابس',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 20,
        rating: 4.6,
        reviewCount: 65,
      ),
      Product(
        name: 'طقم كنب عصري',
        description: 'طقم كنب 3+2+1 مع طاولة قهوة خشبية فاخرة وتصميم مودرن',
        price: 4999,
        category: 'أثاث',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 5,
        rating: 4.5,
        reviewCount: 32,
      ),
      Product(
        name: 'مكتب خشبي فاخر',
        description: 'مكتب خشب زان طبيعي مع أدراج تخزين وتصميم كلاسيكي فاخر',
        price: 2999,
        category: 'أثاث',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 3,
        rating: 4.4,
        reviewCount: 28,
      ),
      Product(
        name: 'تمور سعودية فاخرة',
        description: 'تمور خلاص القصيم درجة أولى معبأة بعناية في علبة خشبية فاخرة',
        price: 149,
        category: 'مواد غذائية',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 100,
        rating: 4.7,
        reviewCount: 89,
      ),
      Product(
        name: 'قهوة عربية محمصة',
        description: 'أجود أنواع القهوة العربية محمصة طازجة مع هيل وزعفران',
        price: 79,
        category: 'مواد غذائية',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 80,
        rating: 4.5,
        reviewCount: 156,
      ),
      Product(
        name: 'عطر شانيل رقم 5',
        description: 'عطر فرنسي أصلي للنساء برائحة زهرية جذابة تدوم طويلاً',
        price: 599,
        category: 'عطور',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 25,
        rating: 4.9,
        reviewCount: 534,
      ),
      Product(
        name: 'عطر ديور سوفاج',
        description: 'عطر رجالي فاخر برائحة خشبية منعشة تناسب جميع المناسبات',
        price: 449,
        category: 'عطور',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 18,
        rating: 4.8,
        reviewCount: 321,
      ),
      Product(
        name: 'حذاء رياضي نايك',
        description: 'حذاء رياضي خفيف ومريح بتقنية Air Max للرجال والنساء',
        price: 399,
        category: 'أحذية',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 40,
        rating: 4.4,
        reviewCount: 198,
      ),
      Product(
        name: 'حذاء كلاسيك رسمي',
        description: 'حذاء جلدي طبيعي تصميم كلاسيكي أنيق للعمل والمناسبات',
        price: 299,
        category: 'أحذية',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 35,
        rating: 4.2,
        reviewCount: 76,
      ),
      Product(
        name: 'ساعة رولكس ديت جست',
        description: 'ساعة سويسرية أصلية مع علبة من الذهب عيار 18 قيراط ومينا أزرق',
        price: 45000,
        category: 'ساعات',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 2,
        rating: 5.0,
        reviewCount: 45,
      ),
      Product(
        name: 'سجادة صلاة فاخرة',
        description: 'سجادة صلاة مخملية ناعمة مع حقيبة حمل أنيقة',
        price: 129,
        category: 'أخرى',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 60,
        rating: 4.8,
        reviewCount: 234,
      ),
      Product(
        name: 'طقم أواني طبخ',
        description: 'طقم أواني جرانيت 10 قطع مع أغطية زجاجية ومقابض مقاومة للحرارة',
        price: 599,
        category: 'أخرى',
        imagePath: 'assets/images/product_placeholder.png',
        isAvailable: true,
        stock: 15,
        rating: 4.3,
        reviewCount: 112,
      ),
    ];
  }

  // ==================== العملاء الافتراضيون ====================
  static List<Customer> getDefaultCustomers() {
    return [
      Customer(
        name: 'أحمد محمد',
        phone: '770123456',
        email: 'ahmed@example.com',
        password: Customer.hashPassword('123456'),
        city: 'صنعاء',
        address: 'شارع القاهرة، مبنى 12',
        notes: 'عميل مميز - يطلب باستمرار',
        totalPurchases: 12500,
        orderCount: 15,
        loginMethod: 'credentials',
      ),
      Customer(
        name: 'فاطمة علي',
        phone: '777654321',
        email: 'fatima@example.com',
        password: Customer.hashPassword('123456'),
        city: 'عدن',
        address: 'خور مكسر، عمارة النور',
        notes: 'تفضل المنتجات الغذائية',
        totalPurchases: 5600,
        orderCount: 8,
        loginMethod: 'link',
      ),
      Customer(
        name: 'محمد عبدالله',
        phone: '773456789',
        email: 'mohammed@example.com',
        password: Customer.hashPassword('123456'),
        city: 'تعز',
        address: 'شارع جمال، حي الروضة',
        notes: '',
        totalPurchases: 3200,
        orderCount: 4,
        loginMethod: 'credentials',
      ),
      Customer(
        name: 'سارة حسن',
        phone: '771234567',
        email: 'sara@example.com',
        password: Customer.hashPassword('123456'),
        city: 'الحديدة',
        address: 'شارع الميناء، بجوار البنك',
        notes: 'عميلة جديدة',
        totalPurchases: 850,
        orderCount: 2,
        loginMethod: 'link',
      ),
      Customer(
        name: 'خالد عمر',
        phone: '778901234',
        email: 'khaled@example.com',
        password: Customer.hashPassword('123456'),
        city: 'إب',
        address: 'شارع العدين، أمام المستشفى',
        notes: 'يحتاج متابعة للمدفوعات',
        totalPurchases: 0,
        orderCount: 0,
        loginMethod: 'credentials',
      ),
    ];
  }

  // ==================== استيراد المنتجات ====================
  static Future<void> importProducts(ProductController productController) async {
    final products = getDefaultProducts();
    for (var product in products) {
      await Hive.box('products').put(product.id, product.toJson());
    }
    productController.loadProducts();
  }

  // ==================== استيراد العملاء ====================
  static Future<void> importCustomers(CustomerController customerController) async {
    final customers = getDefaultCustomers();
    for (var customer in customers) {
      await Hive.box('customers').put(customer.id, customer.toJson());
    }
    customerController.loadCustomers();
  }

  // ==================== استيراد الكل ====================
  static Future<void> importAll({
    required ProductController productController,
    required CustomerController customerController,
  }) async {
    await importProducts(productController);
    await importCustomers(customerController);
  }
}