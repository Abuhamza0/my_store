import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// ✅ اختيار صورة من الكاميرا أو المعرض وإرجاعها دائمًا كـ Base64
  static Future<String?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        // ✅ قراءة البايتات وتحويلها إلى Base64 Data URL
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64';
      }
      return null;
    } catch (e) {
      print('❌ خطأ في اختيار الصورة: $e');
      return null;
    }
  }

  /// ✅ قراءة blob URL
  static Future<Uint8List?> _readBlobUrl(String blobUrl) async {
    try {
      final response = await http.get(Uri.parse(blobUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('❌ خطأ في قراءة blob: $e');
      return null;
    }
  }

  /// ✅ عرض الصورة
  static Widget displayImage({
    required String? imagePath,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imagePath == null || imagePath.isEmpty) {
      return placeholder ?? const Icon(Icons.image);
    }

    // ✅ 1. Base64
    if (imagePath.startsWith('data:image')) {
      final base64 = imagePath.split(',').last;
      return Image.memory(
        base64Decode(base64),
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder ?? const Icon(Icons.broken_image),
      );
    }

    // ✅ 2. من السحابة
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder ?? const Icon(Icons.broken_image),
      );
    }

    // ✅ 3. assets
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder ?? const Icon(Icons.broken_image),
      );
    }

    // ✅ 4. blob (لأي استخدام قديم)
    if (imagePath.startsWith('blob:')) {
      return FutureBuilder<Uint8List?>(
        future: _readBlobUrl(imagePath),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: fit ?? BoxFit.cover);
          }
          return placeholder ?? const Icon(Icons.image);
        },
      );
    }

    // ✅ 5. ملف محلي
    if (!kIsWeb) {
      return Image.file(File(imagePath), fit: fit ?? BoxFit.cover);
    }

    return placeholder ?? const Icon(Icons.image);
  }
}