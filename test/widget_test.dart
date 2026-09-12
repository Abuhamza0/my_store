import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mystore/main.dart';
import 'package:mystore/features/store_service/product_controller.dart';
import 'package:mystore/features/store_service/customer_controller.dart';
import 'package:mystore/features/store_service/order_controller.dart';

void main() {
  setUp(() async {
    // تهيئة Hive للاختبار
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('products');
    await Hive.openBox('customers');
    await Hive.openBox('orders');

    // تسجيل المتحكمات
    Get.put(ProductController(), permanent: true);
    Get.put(CustomerController(), permanent: true);
    Get.put(OrderController(), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('يجب أن يفتح التطبيق ويعرض شاشة البداية', (WidgetTester tester) async {
    await tester.pumpWidget(const StoreApp());
    await tester.pump();

    // التحقق من وجود نص "خدمة متجري"
    expect(find.text('خدمة متجري'), findsOneWidget);
    expect(find.text('لحظات ويتم تجهيز خدمتك'), findsOneWidget);
  });

  testWidgets('يجب أن ينتقل إلى الصفحة الرئيسية بعد شاشة البداية', (WidgetTester tester) async {
    await tester.pumpWidget(const StoreApp());
    await tester.pump();

    // الانتظار لمدة شاشة البداية
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // التحقق من وجود عنوان الصفحة الرئيسية
    expect(find.text('متجري'), findsOneWidget);
  });
}