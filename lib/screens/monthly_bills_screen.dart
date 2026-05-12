import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/native_pending_sync.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/offline_transactions_merge.dart';
import '../utils/screen_utils.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../services/pdf_export_service.dart';
import '../utils/app_localization.dart';

class MonthlyBillsScreen extends StatefulWidget {
  const MonthlyBillsScreen({super.key});

  @override
  State<MonthlyBillsScreen> createState() => _MonthlyBillsScreenState();
}

class _MonthlyBillsScreenState extends State<MonthlyBillsScreen> with SingleTickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _netSavings = 0.0;

  Map<String, double> _expenseByCategory = {};
  Map<String, double> _incomeByCategory = {};

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMonthlyData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _loadMonthlyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await NativePendingSync.syncQuickAddQueue();
    if (await _firebaseService.isConnected) {
      await StorageService.syncAllLocalData();
    }
    _firebaseService.getMonthlyTransactions(_selectedMonth).listen((transactions) async {
      final merged = await mergeFirebaseMonthWithPendingLocal(transactions, _selectedMonth);
      if (!mounted) return;
      setState(() {
        _transactions = merged;
        _calculateSummary();
        _isLoading = false;
      });
    });
  }

  void _calculateSummary() {
    double income = 0.0;
    double expenses = 0.0;
    Map<String, double> expCat = {};
    Map<String, double> incCat = {};

    for (final t in _transactions) {
      final amount = _safeAmount(t['amount']);
      final cat = t['category']?.toString() ?? 'General';
      if (t['type'] == 'income') {
        income += amount;
        incCat[cat] = (incCat[cat] ?? 0) + amount;
      } else {
        expenses += amount;
        expCat[cat] = (expCat[cat] ?? 0) + amount;
      }
    }
    _totalIncome = income;
    _totalExpenses = expenses;
    _netSavings = income - expenses;

    _expenseByCategory = Map.fromEntries(expCat.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value)));
    _incomeByCategory = Map.fromEntries(incCat.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value)));
  }

  double _safeAmount(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Future<void> _pickMonth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              surface: AppTheme.surface,
              onSurface: AppTheme.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) {
      setState(() {
        _selectedMonth = DateTime(d.year, d.month, 1);
      });
      _loadMonthlyData();
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
    });
    _loadMonthlyData();
  }

  String _getInsights() {
    if (_totalExpenses == 0 && _totalIncome == 0) return "No transactions for this month.".tr;
    String note = "";
    if (_expenseByCategory.isNotEmpty) {
      final topExp = _expenseByCategory.entries.first;
      note += "💡 " + "Top expense".tr + ": ${topExp.key.tr} (\$${topExp.value.toStringAsFixed(0)})\n";
    }
    if (_netSavings > 0) {
      note += "✨ " + "Great job! You saved".tr + " \$${_netSavings.toStringAsFixed(0)}.";
    } else if (_netSavings < 0) {
      note += "⚠️ " + "Careful, you spent".tr + " \$${_netSavings.abs().toStringAsFixed(0)} " + "more than you earned".tr + ".";
    } else {
      note += "⚖️ " + "You broke even this month".tr + ".";
    }
    return note.trim();
  }

  Future<void> _exportToPdf() async {
    setState(() => _isLoading = true);
    try {
      final pdfBytes = await PdfExportService.generateMonthlyReport(
        month: _selectedMonth,
        totalIncome: _totalIncome,
        totalExpenses: _totalExpenses,
        netSavings: _netSavings,
        expenseByCategory: _expenseByCategory,
        incomeByCategory: _incomeByCategory,
        transactions: _transactions,
      );

      final monthLabel = DateFormat('MMMM_yyyy').format(_selectedMonth);
      await Printing.sharePdf(bytes: pdfBytes, filename: 'financial_report_$monthLabel.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCategoryDetails(String category, bool isIncome) {
    final typeStr = isIncome ? 'income' : 'expense';
    final txs = _transactions.where((t) => t['category'] == category && t['type'] == typeStr).toList();
    txs.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isIncome ? AppTheme.income.withValues(alpha: 0.15) : AppTheme.expense.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: isIncome ? AppTheme.income : AppTheme.expense, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category, style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('${txs.length} ' + 'transactions'.tr, style: const TextStyle(color: AppTheme.textDim, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textDim),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: txs.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, i) => _buildTransactionItem(txs[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    S.init(context);
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    _tabController ??= TabController(length: 2, vsync: this);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // ── Header (Month Selector + Export) ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _pickMonth,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overview'.tr,
                          style: TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              monthLabel,
                              style: const TextStyle(color: AppTheme.textMain, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textDim, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.chevron_left_rounded, size: 20, color: AppTheme.textMain),
                          onPressed: () => _changeMonth(-1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textMain),
                          onPressed: () => _changeMonth(1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 20, color: AppTheme.border),
                      const SizedBox(width: 10),
                      _isLoading 
                          ? const SizedBox(width: 36, height: 36, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)))
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.ios_share_rounded, size: 18, color: AppTheme.primary),
                                onPressed: _exportToPdf,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Premium Insights Note ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.12),
                      AppTheme.surfaceLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25), width: 1),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primary.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 20, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text('Month Insights'.tr, style: TextStyle(color: AppTheme.textMain, fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            _getInsights(),
                            style: TextStyle(color: AppTheme.textMain.withValues(alpha: 0.8), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Premium Segmented Tabs ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 52,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textDim,
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: 'Expenses'.tr),
                    Tab(text: 'Income'.tr),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Categories List ─────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCategoryList(_expenseByCategory, _totalExpenses, false),
                        _buildCategoryList(_incomeByCategory, _totalIncome, true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(Map<String, double> categories, double total, bool isIncome) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 56, color: AppTheme.textDim.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(isIncome ? 'No income this month'.tr : 'No expenses this month'.tr, style: const TextStyle(color: AppTheme.textDim, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final keys = categories.keys.toList();
    final color = isIncome ? AppTheme.income : AppTheme.expense;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final cat = keys[index];
        final amount = categories[cat]!;
        final percentage = total > 0 ? (amount / total) : 0.0;

        return GestureDetector(
          onTap: () => _showCategoryDetails(cat, isIncome),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(isIncome ? Icons.keyboard_double_arrow_up_rounded : Icons.keyboard_double_arrow_down_rounded, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cat.tr,
                            style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '\$${amount.toStringAsFixed(0)}',
                            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: color.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 42,
                            child: Text(
                              '${(percentage * 100).toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.w700),
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
        );
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final amount = _safeAmount(t['amount']);
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    final date = t['date'] != null ? DateFormat('MMM dd').format(DateTime.parse(t['date'])) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (t['category'] ?? 'General').toString().tr,
                  style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (t['note'] != null && t['note'].toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    t['note'].toString(),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t['pendingSync'] == true) ...[
                    Icon(Icons.cloud_queue_rounded, size: 14, color: AppTheme.textDim.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(date, style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}