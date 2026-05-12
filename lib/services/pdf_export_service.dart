import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<Uint8List> generateMonthlyReport({
    required DateTime month,
    required double totalIncome,
    required double totalExpenses,
    required double netSavings,
    required Map<String, double> expenseByCategory,
    required Map<String, double> incomeByCategory,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdf = pw.Document();
    final monthLabel = DateFormat('MMMM yyyy').format(month);

    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            _buildHeader(monthLabel),
            pw.SizedBox(height: 20),
            _buildSummary(totalIncome, totalExpenses, netSavings),
            pw.SizedBox(height: 30),
            if (expenseByCategory.isNotEmpty) ...[
              _buildCategorySection('المصروفات حسب القسم', expenseByCategory, PdfColors.red800),
              pw.SizedBox(height: 20),
            ],
            if (incomeByCategory.isNotEmpty) ...[
              _buildCategorySection('الدخل حسب القسم', incomeByCategory, PdfColors.green800),
              pw.SizedBox(height: 20),
            ],
            pw.SizedBox(height: 10),
            pw.Text('تفاصيل الحركات', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 10),
            _buildTransactionsTable(transactions),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(String monthLabel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('التقرير المالي الشهري', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 4),
        pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Text(monthLabel, style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildSummary(double income, double expenses, double savings) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryItem('إجمالي الدخل', income, PdfColors.green800),
          _buildSummaryItem('إجمالي المصروفات', expenses, PdfColors.red800),
          _buildSummaryItem('صافي التوفير', savings, savings >= 0 ? PdfColors.blue800 : PdfColors.orange800),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String title, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Text(
            '\$${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCategorySection(String title, Map<String, double> categories, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
        pw.SizedBox(height: 10),
        pw.ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories.keys.elementAt(index);
            final amount = categories[cat]!;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(cat, style: const pw.TextStyle(fontSize: 14)),
                  pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text('\$${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static pw.Widget _buildTransactionsTable(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return pw.Text('لا توجد حركات مسجلة في هذا الشهر.', style: const pw.TextStyle(color: PdfColors.grey600));
    }

    final headers = ['التاريخ', 'القسم', 'الملاحظات', 'المبلغ'];
    
    // Sort transactions by date descending
    final sortedTxs = List<Map<String, dynamic>>.from(transactions);
    sortedTxs.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

    final data = sortedTxs.map((t) {
      final isIncome = t['type'] == 'income';
      final amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
      final date = t['date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(t['date'])) : '';
      final note = t['note']?.toString() ?? '';
      final amountStr = '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}';
      
      return [date, t['category'] ?? 'عام', note, amountStr];
    }).toList();

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.TableHelper.fromTextArray(
        headers: headers,
        data: data,
        border: pw.TableBorder.all(color: PdfColors.grey300),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        cellStyle: const pw.TextStyle(fontSize: 12),
        cellPadding: const pw.EdgeInsets.all(8),
        cellAlignments: {
          0: pw.Alignment.centerRight,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerLeft, // amount is better aligned LTR
        },
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      ),
    );
  }
}
