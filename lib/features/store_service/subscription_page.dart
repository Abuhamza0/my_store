import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/locale_service.dart';
import 'store_home.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  @override
  void initState() {
    super.initState();
    // ✅ استمع لتغيير اللغة
    ever(LocaleService.current, (_) {
      if (mounted) setState(() {});
    });
  }

  void _showActivationDialog() {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: Get.context!,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.vpn_key_rounded,
                  color: Color(0xFF1A2332), size: 28),
              const SizedBox(width: 10),
              Text(
                'activate_subscription'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2332),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      Text(
                        'enter_activation_code'.tr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2332),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'XXXX-XXXX-XXXX-XXXX',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A2332),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'enter_code_required'.tr
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // معلومات التواصل
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'to_get_activation_code'.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // واتساب
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_android_rounded,
                                color: Color(0xFF1A2332), size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'call_or_whatsapp'.tr,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: () => launchUrl(
                                    Uri.parse('https://wa.me/967782000010'),
                                  ),
                                  child: const Text(
                                    '+967 782 000 010',
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A2332),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // البريد الإلكتروني
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.email_rounded,
                                color: Color(0xFF1A2332), size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'email_label'.tr,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: () => launchUrl(
                                    Uri.parse(
                                        'mailto:support@nithamsoft.com'),
                                  ),
                                  child: const Text(
                                    'support@nithamsoft.com',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A2332),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'cancel'.tr,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => isLoading = true);

                final enteredCode = codeController.text.trim();
                final activationCodes = Hive.box('settings').get(
                    'activation_codes',
                    defaultValue: <dynamic>[]);
                final usedCodes = Hive.box('settings').get(
                    'used_codes',
                    defaultValue: <dynamic>[]);

                await Future.delayed(const Duration(seconds: 1));

                if (activationCodes is List &&
                    activationCodes.contains(enteredCode)) {
                  if (usedCodes is List &&
                      usedCodes.contains(enteredCode)) {
                    setDialogState(() => isLoading = false);
                    Get.snackbar(
                      'error'.tr,
                      'code_already_used'.tr,
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  final settingsBox = Hive.box('settings');
                  settingsBox.put('store_subscribed', true);
                  settingsBox.put('subscription_type', 'monthly');
                  settingsBox.put(
                    'subscription_date',
                    DateTime.now().toIso8601String(),
                  );
                  settingsBox.put(
                    'subscription_expiry',
                    DateTime.now()
                        .add(const Duration(days: 30))
                        .toIso8601String(),
                  );
                  usedCodes.add(enteredCode);
                  settingsBox.put('used_codes', usedCodes);

                  // حفظ الحساب المفعل
                  final rawAccounts = settingsBox.get(
                      'activated_accounts',
                      defaultValue: <dynamic>[]);
                  final activatedAccounts =
                  List<Map<String, dynamic>>.from(
                      rawAccounts is List ? rawAccounts : []);
                  activatedAccounts.add({
                    'store_name': settingsBox.get('store_name',
                        defaultValue: 'my_store'.tr),
                    'email': settingsBox.get('store_email',
                        defaultValue: ''),
                    'activation_code': enteredCode,
                    'activation_date': DateTime.now()
                        .toIso8601String()
                        .substring(0, 10),
                    'type': 'monthly',
                  });
                  settingsBox.put(
                      'activated_accounts', activatedAccounts);

                  Navigator.pop(ctx);
                  Get.offAll(() => const StoreServiceHome());
                  Get.snackbar(
                    '🎉 ${'subscription_success_title'.tr}',
                    'subscription_success_msg'.tr,
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                } else {
                  setDialogState(() => isLoading = false);
                  Get.snackbar(
                    'error'.tr,
                    'invalid_code'.tr,
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2332),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : Text(
                'activate_btn'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تفعيل التجربة المجانية
  void _startFreeTrial() {
    final settingsBox = Hive.box('settings');
    settingsBox.put(
      'trial_end_date',
      DateTime.now().add(const Duration(days: 14)).toIso8601String(),
    );
    settingsBox.put('store_subscribed', false);
    settingsBox.put('subscription_type', 'trial');

    // حفظ الحساب بالتجربة المجانية
    final rawAccounts =
    settingsBox.get('activated_accounts', defaultValue: <dynamic>[]);
    final activatedAccounts =
    List<Map<String, dynamic>>.from(rawAccounts is List ? rawAccounts : []);
    activatedAccounts.add({
      'store_name':
      settingsBox.get('store_name', defaultValue: 'my_store'.tr),
      'email': settingsBox.get('store_email', defaultValue: ''),
      'activation_code': 'TRIAL-14-DAYS',
      'activation_date':
      DateTime.now().toIso8601String().substring(0, 10),
      'type': 'trial',
    });
    settingsBox.put('activated_accounts', activatedAccounts);

    Get.offAll(() => const StoreServiceHome());
    Get.snackbar(
      '🎉 ${'trial_activated_title'.tr}',
      'trial_activated_msg'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ قراءة اللغة الحالية
    final isArabic = Get.locale?.languageCode == 'ar';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2332), Color(0xFF2D3A4E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // أيقونة الاشتراك
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: Colors.amber, size: 45),
                  ),
                  const SizedBox(height: 24),

                  // العنوان الرئيسي
                  Text(
                    'choose_plan'.tr,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // الوصف
                  Text(
                    'choose_plan_desc'.tr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // بطاقة التجربة المجانية
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.card_giftcard_rounded,
                            color: Colors.green, size: 50),
                        const SizedBox(height: 12),
                        Text(
                          'free_trial'.tr,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2332),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'free_trial_days'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'all_features_available'.tr,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _startFreeTrial,
                            icon: const Icon(Icons.rocket_launch_rounded,
                                color: Colors.white),
                            label: Text(
                              'start_free_trial'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // بطاقة الاشتراك المدفوع
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: const Color(0xFF1A2332), width: 2),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.diamond_rounded,
                            color: Color(0xFF1A2332), size: 50),
                        const SizedBox(height: 12),
                        Text(
                          'paid_plan'.tr,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2332),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'paid_plan_price'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF1A2332),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'paid_plan_features'.tr,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _showActivationDialog,
                            icon: const Icon(Icons.vpn_key_rounded,
                                color: Colors.white),
                            label: Text(
                              'subscribe_now'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A2332),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}