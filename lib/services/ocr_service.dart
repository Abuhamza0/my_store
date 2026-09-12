import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  /// تحليل صورة واستخراج النص
  static Future<Map<String, String?>> analyzeImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String fullText = recognizedText.text;

      return _extractInvoiceData(fullText);
    } catch (e) {
      print('خطأ في تحليل الصورة: $e');
      return {};
    } finally {
      textRecognizer.close();
    }
  }

  /// استخراج بيانات الفاتورة من النص
  static Map<String, String?> _extractInvoiceData(String text) {
    String? invoiceNumber;
    String? date;
    String? totalAmount;
    String? supplierName;
    String? taxNumber;

    // البحث عن رقم الفاتورة - بالعربية
    final arabicInvoicePattern = RegExp(r'فاتورة\s*(?:رقم)?[:\s]*([\d\-]+)');
    final match1 = arabicInvoicePattern.firstMatch(text);
    if (match1 != null) {
      invoiceNumber = match1.group(1)?.trim();
    }

    // البحث عن رقم الفاتورة - بالإنجليزية
    if (invoiceNumber == null) {
      final englishInvoicePattern = RegExp(r'Invoice\s*(?:No|Number)?[:\s]*([A-Za-z0-9\-]+)', caseSensitive: false);
      final match2 = englishInvoicePattern.firstMatch(text);
      if (match2 != null) {
        invoiceNumber = match2.group(1)?.trim();
      }
    }

    // البحث عن رقم الفاتورة - مختصر
    if (invoiceNumber == null) {
      final shortInvoicePattern = RegExp(r'Inv\s*(?:No)?[:\s]*([A-Za-z0-9\-]+)', caseSensitive: false);
      final match3 = shortInvoicePattern.firstMatch(text);
      if (match3 != null) {
        invoiceNumber = match3.group(1)?.trim();
      }
    }

    // البحث عن التاريخ - صيغ مختلفة
    final datePattern1 = RegExp(r'Date[:\s]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})', caseSensitive: false);
    final match4 = datePattern1.firstMatch(text);
    if (match4 != null) {
      date = match4.group(1)?.trim();
    }

    if (date == null) {
      final datePattern2 = RegExp(r'التاريخ[:\s]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})');
      final match5 = datePattern2.firstMatch(text);
      if (match5 != null) {
        date = match5.group(1)?.trim();
      }
    }

    if (date == null) {
      final datePattern3 = RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})');
      final match6 = datePattern3.firstMatch(text);
      if (match6 != null) {
        date = match6.group(1)?.trim();
      }
    }

    // البحث عن المبلغ الإجمالي
    final amountPattern1 = RegExp(r'Total[:\s]*([\d,]+\.?\d*)', caseSensitive: false);
    final match7 = amountPattern1.firstMatch(text);
    if (match7 != null) {
      totalAmount = match7.group(1)?.trim().replaceAll(',', '');
    }

    if (totalAmount == null) {
      final amountPattern2 = RegExp(r'Grand\s*Total[:\s]*([\d,]+\.?\d*)', caseSensitive: false);
      final match8 = amountPattern2.firstMatch(text);
      if (match8 != null) {
        totalAmount = match8.group(1)?.trim().replaceAll(',', '');
      }
    }

    if (totalAmount == null) {
      final amountPattern3 = RegExp(r'الإجمالي[:\s]*([\d,]+\.?\d*)');
      final match9 = amountPattern3.firstMatch(text);
      if (match9 != null) {
        totalAmount = match9.group(1)?.trim().replaceAll(',', '');
      }
    }

    if (totalAmount == null) {
      final amountPattern4 = RegExp(r'Amount\s*Due[:\s]*([\d,]+\.?\d*)', caseSensitive: false);
      final match10 = amountPattern4.firstMatch(text);
      if (match10 != null) {
        totalAmount = match10.group(1)?.trim().replaceAll(',', '');
      }
    }

    if (totalAmount == null) {
      final amountPattern5 = RegExp(r'([\d,]+\.?\d*)\s*(?:SAR|ريال|USD)', caseSensitive: false);
      final match11 = amountPattern5.firstMatch(text);
      if (match11 != null) {
        totalAmount = match11.group(1)?.trim().replaceAll(',', '');
      }
    }

    // البحث عن اسم المورد
    final supplierPattern1 = RegExp(r'From[:\s]*([A-Za-z\s]+(?:LLC|Inc|Co|Ltd)?)', caseSensitive: false);
    final match12 = supplierPattern1.firstMatch(text);
    if (match12 != null) {
      supplierName = match12.group(1)?.trim();
    }

    if (supplierName == null) {
      final supplierPattern2 = RegExp(r'Supplier[:\s]*([A-Za-z\s]+(?:LLC|Inc|Co|Ltd)?)', caseSensitive: false);
      final match13 = supplierPattern2.firstMatch(text);
      if (match13 != null) {
        supplierName = match13.group(1)?.trim();
      }
    }

    // البحث عن الرقم الضريبي
    final taxPattern1 = RegExp(r'Tax\s*(?:ID|Number)?[:\s]*([A-Za-z0-9\-]+)', caseSensitive: false);
    final match14 = taxPattern1.firstMatch(text);
    if (match14 != null) {
      taxNumber = match14.group(1)?.trim();
    }

    if (taxNumber == null) {
      final taxPattern2 = RegExp(r'الرقم\s*الضريبي[:\s]*([A-Za-z0-9\-]+)');
      final match15 = taxPattern2.firstMatch(text);
      if (match15 != null) {
        taxNumber = match15.group(1)?.trim();
      }
    }

    if (taxNumber == null) {
      final taxPattern3 = RegExp(r'VAT[:\s]*([A-Za-z0-9\-]+)', caseSensitive: false);
      final match16 = taxPattern3.firstMatch(text);
      if (match16 != null) {
        taxNumber = match16.group(1)?.trim();
      }
    }

    return {
      'invoiceNumber': invoiceNumber,
      'date': date,
      'totalAmount': totalAmount,
      'supplierName': supplierName,
      'taxNumber': taxNumber,
      'fullText': text,
    };
  }
}