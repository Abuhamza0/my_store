import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';

class PdfService {
  static pw.Font? _arabicFont;
  static pw.MemoryImage? _watermarkLogo;  // شعار دلتا سوفت للعلامة المائية
  static pw.MemoryImage? _userLogo;       // شعار المستخدم (في أعلى الصفحة)

  // ==================== دوال التحميل ====================

  static Future<pw.Font> _loadArabicFont() async {
    if (_arabicFont != null) return _arabicFont!;
    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
      return _arabicFont!;
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  // ✅ تحميل شعار دلتا سوفت (للعلامة المائية فقط)
  static Future<pw.MemoryImage?> _loadWatermarkLogo() async {
    if (_watermarkLogo != null) return _watermarkLogo;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      _watermarkLogo = pw.MemoryImage(data.buffer.asUint8List());
      return _watermarkLogo;
    } catch (e) {
      return null;
    }
  }

  // ✅ تحميل شعار المستخدم من قاعدة البيانات (تم إصلاح الخطأ)
  static Future<pw.MemoryImage?> _loadUserLogo() async {
    if (_userLogo != null) return _userLogo;

    try {
      final settingsBox = Hive.box('settings');
      final logoPath = settingsBox.get('logo_path');

      if (logoPath != null && logoPath is String && logoPath.isNotEmpty) {
        final File logoFile = File(logoPath);
        if (await logoFile.exists()) {
          final List<int> bytes = await logoFile.readAsBytes();
          // ✅ تحويل List<int> إلى Uint8List
          _userLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          return _userLogo;
        }
      }
      return null;
    } catch (e) {
      print('Error loading user logo: $e');
      return null;
    }
  }

  // ✅ دالة للحصول على اسم الشركة من الإعدادات
  static Future<String> _getCompanyName() async {
    try {
      final settingsBox = Hive.box('settings');
      final companyName = settingsBox.get('business_name', defaultValue: 'دلتا سوفت');
      return companyName.toString();
    } catch (e) {
      return 'دلتا سوفت';
    }
  }

  // ✅ دالة للحصول على العملة من الإعدادات
  static Future<String> _getCurrency() async {
    try {
      final settingsBox = Hive.box('settings');
      final currency = settingsBox.get('currency', defaultValue: 'YER');
      return currency.toString();
    } catch (e) {
      return 'YER';
    }
  }

  // ==================== العلامة المائية المشتركة ====================

  /// علامة مائية كبيرة في منتصف الصفحة (شعار دلتا سوفت فقط)
  static pw.Widget _buildWatermark(pw.Font font, pw.MemoryImage? watermarkLogo) {
    return pw.Center(
      child: pw.Opacity(
        opacity: 0.04, // شفافية 4%
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (watermarkLogo != null)
              pw.Image(watermarkLogo, width: 300, height: 300),
            pw.SizedBox(height: 16),
            pw.Text(
              'دلتا سوفت',
              style: pw.TextStyle(
                font: font,
                fontSize: 42,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'DELTA Soft',
              style: pw.TextStyle(
                font: font,
                fontSize: 20,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// إنشاء صفحة مع علامة مائية
  static pw.Page _buildPageWithWatermark({
    required pw.Font font,
    pw.MemoryImage? watermarkLogo,
    required pw.Widget Function() content,
    pw.TextDirection textDirection = pw.TextDirection.rtl,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: textDirection,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Stack(
          children: [
            _buildWatermark(font, watermarkLogo),
            content(),
          ],
        );
      },
    );
  }

  // ==================== 1. تقرير المبيعات العام ====================

  static Future<void> generateSalesReport() async {
    try {
      final font = await _loadArabicFont();
      final watermarkLogo = await _loadWatermarkLogo();
      final userLogo = await _loadUserLogo();
      final companyName = await _getCompanyName();
      final currency = await _getCurrency();

      final invoicesBox = Hive.box('invoices');
      final invoices = invoicesBox.values.toList();
      final dateNow = DateTime.now();

      final pdf = pw.Document();
      pdf.addPage(
        _buildPageWithWatermark(
          font: font,
          watermarkLogo: watermarkLogo,
          content: () => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(font, userLogo, companyName, dateNow, "تقرير المبيعات العام", currency),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell("الإجمالي ($currency)", font, isHeader: true),
                      _cell("الضريبة ($currency)", font, isHeader: true),
                      _cell("التاريخ", font, isHeader: true),
                      _cell("رقم الفاتورة", font, isHeader: true),
                    ],
                  ),
                  ...invoices.map((invoice) {
                    return pw.TableRow(
                      children: [
                        _cell(invoice['total'].toString(), font),
                        _cell((invoice['taxAmount'] ?? 0).toString(), font),
                        _cell(invoice['date'].toString().substring(0, 10), font),
                        _cell(invoice['id'].toString().substring(0, 8), font),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 30),
              _buildFooter(font, dateNow, companyName),
            ],
          ),
        ),
      );
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'sales_report.pdf');
    } catch (e) {
      print('Error: $e');
    }
  }

  // ==================== 2. تقرير مبيعات اليوم ====================

  static Future<void> generateTodayInvoicesReport(List<Map<String, dynamic>> allInvoices) async {
    try {
      final font = await _loadArabicFont();
      final watermarkLogo = await _loadWatermarkLogo();
      final userLogo = await _loadUserLogo();
      final companyName = await _getCompanyName();
      final currency = await _getCurrency();

      final today = DateTime.now();

      final todayInvoices = allInvoices.where((invoice) {
        final invoiceDate = DateTime.parse(invoice['date'].toString());
        return invoiceDate.year == today.year &&
            invoiceDate.month == today.month &&
            invoiceDate.day == today.day;
      }).toList();

      final pdf = pw.Document();
      pdf.addPage(
        _buildPageWithWatermark(
          font: font,
          watermarkLogo: watermarkLogo,
          content: () => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(font, userLogo, companyName, today, "تقرير مبيعات اليوم", currency),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell("الإجمالي ($currency)", font, isHeader: true),
                      _cell("الضريبة ($currency)", font, isHeader: true),
                      _cell("الوقت", font, isHeader: true),
                      _cell("رقم الفاتورة", font, isHeader: true),
                    ],
                  ),
                  ...todayInvoices.map((invoice) {
                    final date = DateTime.parse(invoice['date'].toString());
                    return pw.TableRow(
                      children: [
                        _cell(invoice['total'].toString(), font),
                        _cell((invoice['taxAmount'] ?? 0).toString(), font),
                        _cell("${date.hour}:${date.minute}", font),
                        _cell(invoice['id'].toString().substring(0, 8), font),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 30),
              _buildFooter(font, today, companyName),
            ],
          ),
        ),
      );
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'today_report.pdf');
    } catch (e) {
      print('Error: $e');
    }
  }

  // ==================== 3. فاتورة مفردة ====================

  static Future<void> generateInvoice(Map<String, dynamic> invoiceData) async {
    try {
      final font = await _loadArabicFont();
      final watermarkLogo = await _loadWatermarkLogo();
      final userLogo = await _loadUserLogo();
      final companyName = await _getCompanyName();
      final currency = await _getCurrency();

      final date = DateTime.parse(invoiceData['date'].toString());
      final items = invoiceData['items'] as List;

      final pdf = pw.Document();
      pdf.addPage(
        _buildPageWithWatermark(
          font: font,
          watermarkLogo: watermarkLogo,
          content: () => pw.Column(
            children: [
              _buildHeader(font, userLogo, companyName, date, "فاتورة ضريبية", currency),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "العميل : ${invoiceData['customerName'] ?? 'عميل عام'}",
                  style: pw.TextStyle(font: font, fontSize: 14),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell("القيمة المستحقة ($currency)", font, isHeader: true),
                      _cell("القيمة المضافة ($currency)", font, isHeader: true),
                      _cell("سعر الوحدة ($currency)", font, isHeader: true),
                      _cell("الكمية", font, isHeader: true),
                      _cell("المنتج", font, isHeader: true),
                    ],
                  ),
                  ...items.map((item) {
                    final price = (item['price'] as num).toDouble();
                    final quantity = (item['quantity'] as num).toInt();
                    final itemTotal = price * quantity;
                    final itemTax = invoiceData['taxEnabled'] == true
                        ? (itemTotal * (invoiceData['taxRate'] ?? 0) / 100)
                        : 0.0;
                    return pw.TableRow(
                      children: [
                        _cell(itemTotal.toStringAsFixed(2), font),
                        _cell(itemTax.toStringAsFixed(2), font),
                        _cell(price.toStringAsFixed(2), font),
                        _cell(quantity.toString(), font),
                        _cell(item['name'].toString(), font),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              // ملخص الفاتورة
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      _summaryRow("مجموع سعر المنتجات", (invoiceData['subtotal'] ?? invoiceData['total']).toString(), font, currency),
                      if (invoiceData['taxEnabled'] == true) ...[
                        _summaryRow("مجموع ضريبة المبيعات (${invoiceData['taxRate']}%)", (invoiceData['taxAmount'] ?? 0).toString(), font, currency),
                      ],
                      pw.Divider(),
                      _summaryRow("إجمالي قيمة الفاتورة", invoiceData['total'].toString(), font, currency, isBold: true),
                    ],
                  ),
                ),
              ),
              pw.Spacer(),
              _buildFooter(font, date, companyName),
            ],
          ),
        ),
      );
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'invoice.pdf');
    } catch (e) {
      print('Error: $e');
    }
  }

  // ==================== دوال مساعدة ====================

  static pw.Widget _buildHeader(
      pw.Font font,
      pw.MemoryImage? userLogo,
      String companyName,
      DateTime date,
      String title,
      String currency,
      ) {
    return pw.Column(
      children: [
        // شعار المستخدم (في أعلى الصفحة)
        if (userLogo != null)
          pw.Center(
            child: pw.Image(
              userLogo,
              width: 60,
              height: 60,
              fit: pw.BoxFit.contain,
            ),
          ),
        pw.SizedBox(height: 4),
        // اسم الشركة من الإعدادات
        pw.Center(
          child: pw.Text(
            companyName,
            style: pw.TextStyle(
              font: font,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            "${date.day}/${date.month}/${date.year}",
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            "العملة المستخدمة: $currency",
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Font font, DateTime date, String companyName) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "شكراً لتعاملكم معنا - $companyName",
              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              "${date.hour}:${date.minute}:${date.second} ${date.hour >= 12 ? 'PM' : 'AM'}",
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: isHeader ? 9 : 10),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, pw.Font font, String currency, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "$value $currency",
            style: pw.TextStyle(font: font, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }
  // ==================== 4. كشف حساب العميل ====================

  /// تصدير كشف حساب العميل إلى PDF
  // ✅ في دالة generateCustomerStatement
  static Future<void> generateCustomerStatement(Map<String, dynamic> statementData) async {
    try {
      final font = await _loadArabicFont();
      final watermarkLogo = await _loadWatermarkLogo();
      final userLogo = await _loadUserLogo();
      final companyName = await _getCompanyName();
      final currency = await _getCurrency();

      final customerName = statementData['customerName'] ?? 'عميل غير معروف';
      final totalDebt = (statementData['totalDebt'] as num?)?.toDouble() ?? 0.0;
      final totalPaid = (statementData['totalPaid'] as num?)?.toDouble() ?? 0.0;
      final remainingDebt = (statementData['remainingDebt'] as num?)?.toDouble() ?? 0.0;
      final creditBalance = (statementData['creditBalance'] as num?)?.toDouble() ?? 0.0; // ✅ إضافة الرصيد الدائن

      final invoicesRaw = statementData['invoices'] as List? ?? [];
      final List<Map<String, dynamic>> invoices = invoicesRaw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final paymentsRaw = statementData['payments'] as List? ?? [];
      final List<Map<String, dynamic>> payments = paymentsRaw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final pdf = pw.Document();
      pdf.addPage(
        _buildPageWithWatermark(
          font: font,
          watermarkLogo: watermarkLogo,
          content: () => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildCustomerStatementHeader(font, userLogo, companyName, customerName, currency),
              pw.SizedBox(height: 16),

              // ✅ ملخص الحساب مع الرصيد الدائن
              _buildCustomerSummary(font, totalDebt, totalPaid, remainingDebt, creditBalance, currency),
              pw.SizedBox(height: 20),

              _buildCustomerInvoicesTable(font, invoices, currency),
              pw.SizedBox(height: 16),

              _buildCustomerPaymentsTable(font, payments, currency),
              pw.Spacer(),

              _buildFooter(font, DateTime.now(), companyName),
            ],
          ),
        ),
      );

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'كشف_حساب_${customerName.replaceAll(' ', '_')}_$timestamp.pdf';

      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);

    } catch (e) {
      print('❌ Error generating customer statement: $e');
      rethrow;
    }
  }

// ✅ دالة ملخص الحساب مع الرصيد الدائن
  static pw.Widget _buildCustomerSummary(
      pw.Font font,
      double totalDebt,
      double totalPaid,
      double remainingDebt,
      double creditBalance,
      String currency,
      ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildCustomerSummaryItem(font, 'إجمالي المشتريات', totalDebt, currency, PdfColors.blue700),
              _buildCustomerSummaryItem(font, 'المدفوع', totalPaid, currency, PdfColors.green700),
              _buildCustomerSummaryItem(font, 'المتبقي', remainingDebt, currency,
                  remainingDebt > 0 ? PdfColors.red700 : PdfColors.green700),
            ],
          ),
          // ✅ إضافة الرصيد الدائن إذا كان موجوداً
          if (creditBalance > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Icon(const pw.IconData(0xe8c6), color: PdfColors.blue700, size: 16),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'الرصيد الدائن: ${creditBalance.toStringAsFixed(2)} $currency',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== دوال مساعدة لكشف الحساب ====================

  /// رأس صفحة كشف الحساب
  static pw.Widget _buildCustomerStatementHeader(
      pw.Font font,
      pw.MemoryImage? userLogo,
      String companyName,
      String customerName,
      String currency,
      ) {
    return pw.Column(
      children: [
        if (userLogo != null)
          pw.Center(
            child: pw.Image(
              userLogo,
              width: 60,
              height: 60,
              fit: pw.BoxFit.contain,
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            companyName,
            style: pw.TextStyle(
              font: font,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'كشف حساب العميل',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'العميل: $customerName',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'العملة: $currency',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: PdfColors.grey600,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(),
      ],
    );
  }


  /// عنصر في ملخص الحساب
  static pw.Widget _buildCustomerSummaryItem(
      pw.Font font,
      String label,
      double value,
      String currency,
      PdfColor color,
      ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.grey600,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${value.toStringAsFixed(2)} $currency',
          style: pw.TextStyle(
            font: font,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  /// جدول الفواتير الآجلة
  /// جدول الفواتير الآجلة
  static pw.Widget _buildCustomerInvoicesTable(
      pw.Font font,
      List<Map<String, dynamic>> invoices,
      String currency,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'الفواتير الآجلة (${invoices.length})',
          style: pw.TextStyle(
            font: font,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 8),
        if (invoices.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Text(
              'لا توجد فواتير آجلة',
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: PdfColors.grey500,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // رأس الجدول
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  _buildCustomerTableCell('المبلغ ($currency)', font, isHeader: true),
                  _buildCustomerTableCell('عدد المنتجات', font, isHeader: true),
                  _buildCustomerTableCell('التاريخ', font, isHeader: true),
                  _buildCustomerTableCell('رقم الفاتورة', font, isHeader: true),
                ],
              ),
              // صفوف البيانات
              ...invoices.map((invoice) {
                final date = invoice['date']?.toString().split(' ')[0] ?? 'غير محدد';
                var id = invoice['id']?.toString() ?? '---';
                if (id.length > 8) {
                  id = id.substring(0, 8);
                }
                final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;
                final items = invoice['items'] as List? ?? [];
                final itemCount = items.length;

                return pw.TableRow(
                  children: [
                    _buildCustomerTableCell(total.toStringAsFixed(2), font, isAmount: true),
                    _buildCustomerTableCell('$itemCount', font),
                    _buildCustomerTableCell(date, font),
                    _buildCustomerTableCell('#$id', font),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  /// جدول المدفوعات
  /// جدول المدفوعات
  static pw.Widget _buildCustomerPaymentsTable(
      pw.Font font,
      List<Map<String, dynamic>> payments,
      String currency,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'سجل المدفوعات (${payments.length})',
          style: pw.TextStyle(
            font: font,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 8),
        if (payments.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Text(
              'لا توجد مدفوعات مسجلة',
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: PdfColors.grey500,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // رأس الجدول
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green100),
                children: [
                  _buildCustomerTableCell('المبلغ ($currency)', font, isHeader: true),
                  _buildCustomerTableCell('الملاحظات', font, isHeader: true),
                  _buildCustomerTableCell('التاريخ', font, isHeader: true),
                ],
              ),
              // صفوف البيانات
              ...payments.map((payment) {
                final date = payment['date']?.toString().split(' ')[0] ?? 'غير محدد';
                final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
                final note = payment['note']?.toString() ?? '';

                return pw.TableRow(
                  children: [
                    _buildCustomerTableCell(amount.toStringAsFixed(2), font, isAmount: true),
                    _buildCustomerTableCell(note.isEmpty ? '---' : note, font),
                    _buildCustomerTableCell(date, font),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  /// خلية في جداول كشف الحساب
  static pw.Widget _buildCustomerTableCell(
      String text,
      pw.Font font, {
        bool isHeader = false,
        bool isAmount = false,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isAmount ? PdfColors.green700 : null,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: isAmount ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }
}