import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class PdfExportService {
  static pw.TextDirection _getDirection(String text) {
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
      return pw.TextDirection.rtl;
    }
    return pw.TextDirection.ltr;
  }

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
        textDirection: pw.TextDirection.ltr,
        build: (pw.Context context) {
          return [
            _buildHeader(monthLabel),
            pw.SizedBox(height: 20),
            _buildSummary(totalIncome, totalExpenses, netSavings),
            pw.SizedBox(height: 30),
            if (expenseByCategory.isNotEmpty) ...[
              _buildCategorySection('Expenses by Category', expenseByCategory, PdfColors.red800),
              pw.SizedBox(height: 20),
            ],
            if (incomeByCategory.isNotEmpty) ...[
              _buildCategorySection('Income by Category', incomeByCategory, PdfColors.green800),
              pw.SizedBox(height: 20),
            ],
            pw.SizedBox(height: 10),
            pw.Text('Detailed Transactions', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
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
        pw.Text('Monthly Financial Report', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 4),
        pw.Text(monthLabel, style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
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
          _buildSummaryItem('Total Income', income, PdfColors.green800),
          _buildSummaryItem('Total Expenses', expenses, PdfColors.red800),
          _buildSummaryItem('Net Savings', savings, savings >= 0 ? PdfColors.blue800 : PdfColors.orange800),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String title, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(
          '\$${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color),
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
                  pw.Text(cat, style: const pw.TextStyle(fontSize: 14), textDirection: _getDirection(cat)),
                  pw.Text('\$${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
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
      return pw.Text('No transactions found for this month.', style: const pw.TextStyle(color: PdfColors.grey600));
    }

    final headers = ['Date', 'Category', 'Note', 'Amount'];
    
    // Sort transactions by date descending
    final sortedTxs = List<Map<String, dynamic>>.from(transactions);
    sortedTxs.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // Headers
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          )).toList(),
        ),
        // Data
        ...sortedTxs.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final isIncome = t['type'] == 'income';
          final amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
          final date = t['date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(t['date'])) : '';
          final note = t['note']?.toString() ?? '';
          final cat = t['category'] ?? 'General';
          final amountStr = '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50),
            children: [
              _buildCell(date),
              _buildCell(cat, isDynamic: true),
              _buildCell(note, isDynamic: true),
              _buildCell(amountStr, align: pw.Alignment.centerRight),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildCell(String text, {pw.Alignment align = pw.Alignment.centerLeft, bool isDynamic = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: align,
      child: pw.Text(
        text, 
        style: const pw.TextStyle(fontSize: 12),
        textDirection: isDynamic ? _getDirection(text) : pw.TextDirection.ltr,
      ),
    );
  }
}
