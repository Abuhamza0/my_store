import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _isHandlingScan = false; // لمنع معالجة أكثر من قراءة في نفس الوقت

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح رمز QR')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) async {
          if (_isHandlingScan) return;

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final String? rawCode = barcode.rawValue;
            if (rawCode != null && rawCode.trim().isNotEmpty) {
              _isHandlingScan = true;

              // إيقاف التقاط الكاميرا
              await controller.stop();

              if (mounted) {
                Navigator.pop(context, rawCode.trim());
              }
              break;
            }
          }
        },
      ),
    );
  }
}