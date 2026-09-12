import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mystore/core/services/pairing_service.dart';
import 'package:mystore/core/services/store_id_service.dart';

import '../../core/services/session_service.dart';

class PairingCodePage extends StatefulWidget {
  const PairingCodePage({super.key});

  @override
  State<PairingCodePage> createState() => _PairingCodePageState();
}

class _PairingCodePageState extends State<PairingCodePage> {
  String? _pairingCode;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  Future<void> _generateCode() async {
    final storeId = StoreIdService.getStoreId();
    final deviceId = await SessionService.getDeviceId();
    if (storeId.isEmpty || deviceId.isEmpty) return;

    final code = await PairingService.createPairingCode(storeId, deviceId);
    setState(() {
      _pairingCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اقتران جهاز جديد'),
        backgroundColor: const Color(0xFF1D325E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _pairingCode == null
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('امسح هذا الرمز من الجهاز الرئيسي',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            QrImageView(
              data: _pairingCode!,
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 20),
            Text('الرمز: $_pairingCode',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('ينتهي خلال 5 دقائق', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}