// lib/core/services/image_upload_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _getStoreId() {
    try {
      final email = Hive.box('settings').get('store_email', defaultValue: '')?.toString() ?? '';
      if (email.isNotEmpty) {
        return email.trim().replaceAll('@', '_').replaceAll('.', '_');
      }
      return 'default_store';
    } catch (e) {
      return 'default_store';
    }
  }

  String _getExtension(String path) {
    try {
      final fileName = path.split('/').last;
      if (fileName.contains('.')) {
        return fileName.split('.').last.toLowerCase();
      }
      return 'jpg';
    } catch (e) {
      return 'jpg';
    }
  }

  Future<String?> uploadImage({
    required String imagePath,
    required String folder,
  }) async {
    try {
      if (imagePath.startsWith('http') || imagePath.startsWith('https')) {
        return imagePath;
      }
      if (imagePath == 'assets/images/product_placeholder.png') {
        return imagePath;
      }
      if (imagePath.startsWith('assets/')) {
        return imagePath;
      }

      final extension = _getExtension(imagePath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storeId = _getStoreId();
      final ref = _storage.ref('stores/$storeId/$folder/$fileName');

      if (kIsWeb) {
        return imagePath;
      }

      final file = File(imagePath);
      if (!await file.exists()) {
        return imagePath;
      }
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('❌ خطأ: $e');
      return null;
    }
  }

  // ✅ أضف هذه هنا - داخل الكلاس
  Future<String?> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    try {
      final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
      final storeId = _getStoreId();
      final ref = _storage.ref('stores/$storeId/$folder/${DateTime.now().millisecondsSinceEpoch}.$extension');

      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      print('✅ تم رفع الصورة: $url');
      return url;
    } catch (e) {
      print('❌ خطأ: $e');
      return null;
    }
  }

  Future<void> uploadAllProductImages() async {
    try {
      if (kIsWeb) {
        print('⚠️ تخطي');
        return;
      }

      final productsBox = Hive.box('products');
      for (var key in productsBox.keys) {
        final data = productsBox.get(key);
        if (data != null && data is Map) {
          final imagePath = data['imagePath']?.toString() ?? '';
          if (imagePath.isNotEmpty && !imagePath.startsWith('http') && imagePath != 'assets/images/product_placeholder.png') {
            final uploadedUrl = await uploadProductImage(imagePath);
            if (uploadedUrl != null && uploadedUrl.startsWith('http')) {
              data['imagePath'] = uploadedUrl;
              await productsBox.put(key, data);
            }
          }
        }
      }
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  Future<String?> uploadProductImage(String imagePath) async {
    return uploadImage(imagePath: imagePath, folder: 'products');
  }

  Future<String?> uploadStoreLogo(String imagePath) async {
    return uploadImage(imagePath: imagePath, folder: 'logo');
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      if (!imageUrl.startsWith('http')) return;
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }
}