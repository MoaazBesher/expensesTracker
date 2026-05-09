import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';
import 'package:intl/intl.dart';

class MonthlyBillsScreen extends StatefulWidget {
  const MonthlyBillsScreen({super.key});

  @override
  State<MonthlyBillsScreen> createState() => _MonthlyBillsScreenState();
}

class _MonthlyBillsScreenState extends State<MonthlyBillsScreen> {
  final DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;

  // Filters
  String _searchQuery = '';
  String _selectedType = 'all';

  // Summary data
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _netSavings = 0.0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadMonthlyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      FirebaseService().getMonthlyTransactions(_selectedMonth).listen((transactions) {
        if (mounted) {
          setState(() {
            _transactions = transactions;
            _calculateSummary();
            _applyFilters();
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      final localTransactions = await StorageService.getLocalTransactions(_selectedMonth);
      if (mounted) {
        setState(() {
          _transactions = localTransactions;
          _calculateSummary();
          _applyFilters();
          _isLoading = false;
        });
      }
    }
  }

  void _calculateSummary() {
    double income = 0.0;
    double expenses = 0.0;
    for (final t in _transactions) {
      final amount = _safeAmount(t['amount']);
      if (t['type'] == 'income') { income += amount; } else { expenses += amount; }
    }
    _totalIncome = income;
    _totalExpenses = expenses;
    _netSavings = income - expenses;
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      _filteredTransactions = _transactions.where((t) {
        final matchesSearch = _searchQuery.isEmpty ||
            t['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (t['note']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        final matchesType = _selectedType == 'all' || t['type'] == _selectedType;
        return matchesSearch && matchesType;
      }).toList()
        ..sort((a, b) {
          final da = DateTime.parse(a['date'] ?? DateTime.now().toIso8601String());
          final db = DateTime.parse(b['date'] ?? DateTime.now().toIso8601String());
          return db.compareTo(da);
        });
    });
  }

  double _safeAmount(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    S.init(context);
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Month banner + summary cards ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month label
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.textDim),
                    const SizedBox(width: 6),
                    Text(monthLabel, style: const TextStyle(color: AppTheme.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 14),
                // Summary row
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Income', _totalIncome, AppTheme.income, Icons.trending_up_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSummaryCard('Expenses', _totalExpenses, AppTheme.expense, Icons.trending_down_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSummaryCard('Saved', _netSavings, AppTheme.primary, Icons.savings_rounded)),
                  ],
                ),
              ],
            ),
          ),

          // ── Search + Type Filter ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: AppTheme.cardDecoration(radius: 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) { setState(() => _searchQuery = v); _applyFilters(); },
                      decoration: const InputDecoration(
                        hintText: 'Search transactions...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textDim, size: 18),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Type filter pill
                Container(
                  height: 44,
                  decoration: AppTheme.cardDecoration(radius: 12),
                  child: PopupMenuButton<String>(
                    onSelected: (v) { setState(() => _selectedType = v); _applyFilters(); },
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 8),
                        Icon(Icons.tune_rounded, color: _selectedType != 'all' ? AppTheme.primary : AppTheme.textDim, size: 18),
                        const SizedBox(width: 4),
                      ],
                    ),
                    padding: EdgeInsets.zero,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'all',     child: Text('All')),
                      const PopupMenuItem(value: 'income',  child: Text('Income')),
                      const PopupMenuItem(value: 'expense', child: Text('Expense')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Type filter pills row ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: ['All', 'Income', 'Expense'].map((label) {
                final value = label.toLowerCase();
                final isActive = _selectedType == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () { setState(() => _selectedType = value); _applyFilters(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isActive ? AppTheme.primary : AppTheme.textDim,
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Transactions list ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                : _filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _loadMonthlyData(),
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.surface,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) => _buildTransactionItem(_filteredTransactions[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    final isNegative = amount < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: AppTheme.textDim, fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            '\$${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              color: isNegative ? AppTheme.expense : color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
                  t['category'] ?? 'General',
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
              Text(
                '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(date, style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 44, color: AppTheme.textDim.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          const Text('No transactions found', style: TextStyle(color: AppTheme.textMain, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Try adjusting your filters', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
        ],
      ),
    );
  }
}