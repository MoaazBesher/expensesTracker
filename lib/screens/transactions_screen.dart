import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../models/account_model.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateTime _currentMonth = DateTime.now();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  String _searchQuery = '';
  String _selectedType = 'all';
  bool _isLoading = true;
  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
    _loadAccounts();
  }

  void _loadAccounts() {
    FirebaseService().getAccounts().listen((accounts) {
      if (mounted) setState(() { _accounts = accounts; if (_accounts.isNotEmpty && _selectedAccount == null) _selectedAccount = _accounts.first; });
    });
  }

  void _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((txns) {
        if (mounted) setState(() { _transactions = txns; _filterTransactions(); _isLoading = false; });
      });
    } catch (e) {
      final txns = await StorageService.getLocalTransactions(_currentMonth);
      if (mounted) setState(() { _transactions = txns; _filterTransactions(); _isLoading = false; });
    }
  }

  void _filterTransactions() {
    setState(() {
      _filteredTransactions = _transactions.where((t) {
        final matchesSearch = _searchQuery.isEmpty ||
            t['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (t['note']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        final matchesType = _selectedType == 'all' || t['type'] == _selectedType;
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  void _showAddTransactionSheet(bool isIncome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddTransactionSheet(
        isIncome: isIncome,
        accounts: _accounts,
        defaultAccount: _selectedAccount,
        onSave: (amount, category, accountId, note) => _saveTransaction(amount, category, accountId, note),
      ),
    );
  }

  void _saveTransaction(double amount, String category, String accountId, String note) async {
    final bool isIncome = _tabController.index == 0;
    try {
      await FirebaseService().addTransaction(
        type: isIncome ? 'income' : 'expense', amount: amount, category: category,
        date: DateTime.now(), accountId: accountId, note: note,
      );
      await StorageService.saveLocalTransaction({
        'type': isIncome ? 'income' : 'expense', 'amount': amount.toString(), 'category': category,
        'date': DateTime.now().toIso8601String(), 'accountId': accountId, 'note': note,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (mounted) { Navigator.pop(context); _showSuccess('${isIncome ? 'Income' : 'Expense'} added'); _loadTransactions(); }
    } catch (e) { if (mounted) _showError('Failed: $e'); }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12)), backgroundColor: AppTheme.accent));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12)), backgroundColor: AppTheme.secondary));

  @override
  Widget build(BuildContext context) {
    S.init(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textDim,
          tabs: const [
            Tab(text: 'Income'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsContent('income'),
          _buildTransactionsContent('expense'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTransactionsContent(String type) {
    final filtered = _filteredTransactions.where((t) => t['type'] == type).toList();
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(S.sectionPadding),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: AppTheme.cardDecoration(radius: 10),
                  child: TextField(
                    onChanged: (v) { setState(() { _searchQuery = v; _filterTransactions(); }); },
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textDim, size: 18),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 42, width: 42,
                decoration: AppTheme.cardDecoration(radius: 10),
                child: PopupMenuButton<String>(
                  onSelected: (v) { setState(() { _selectedType = v; _filterTransactions(); }); },
                  icon: const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 18),
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'all', child: Text('All')),
                    const PopupMenuItem(value: 'income', child: Text('Income')),
                    const PopupMenuItem(value: 'expense', child: Text('Expense')),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async => _loadTransactions(),
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: S.sectionPadding),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _buildTransactionItem(filtered[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final amount = _safeConvertAmount(t['amount']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isIncome ? AppTheme.income : AppTheme.expense).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? AppTheme.income : AppTheme.expense, size: 18),
        ),
        title: Text(t['category'] ?? 'General', style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: t['date'] != null
            ? Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(t['date'])), style: TextStyle(color: AppTheme.textDim, fontSize: 11))
            : null,
        trailing: Text('${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}', style: TextStyle(color: isIncome ? AppTheme.income : AppTheme.expense, fontWeight: FontWeight.w600, fontSize: 15)),
        onLongPress: () => _confirmDelete(t),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textDim.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('No transactions yet', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontBody)),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New Entry', style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddOption('Income', Icons.add_chart_rounded, AppTheme.income, true),
                _buildAddOption('Expense', Icons.bar_chart_rounded, AppTheme.expense, false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(String label, IconData icon, Color color, bool isIncome) {
    return InkWell(
      onTap: () { Navigator.pop(context); _showAddTransactionSheet(isIncome); },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Transaction?', style: TextStyle(fontSize: 16)),
        content: const Text('This cannot be undone.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService().deleteTransaction(t['id'], t['accountId'] ?? '', t['type'], _safeConvertAmount(t['amount']));
              _loadTransactions();
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
  }

  double _safeConvertAmount(dynamic v) {
    if (v == null) return 0.0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

class _AddTransactionSheet extends StatefulWidget {
  final bool isIncome;
  final List<AccountModel> accounts;
  final AccountModel? defaultAccount;
  final Function(double, String, String, String) onSave;
  const _AddTransactionSheet({required this.isIncome, required this.accounts, this.defaultAccount, required this.onSave});
  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  late List<String> categories;
  late String selectedCategory;
  AccountModel? _selectedAccount;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    categories = widget.isIncome
        ? ['Salary', 'Freelance', 'Investment', 'Business', 'Gift', 'Other']
        : ['Food', 'Transportation', 'Entertainment', 'Utilities', 'Shopping', 'Healthcare', 'Other'];
    selectedCategory = categories.first;
    _selectedAccount = widget.defaultAccount;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add ${widget.isIncome ? 'Income' : 'Expense'}', style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              dropdownColor: AppTheme.surfaceLight,
              style: const TextStyle(color: AppTheme.textMain),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => selectedCategory = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<AccountModel>(
              initialValue: widget.accounts.contains(_selectedAccount) ? _selectedAccount : null,
              decoration: const InputDecoration(labelText: 'Account'),
              dropdownColor: AppTheme.surfaceLight,
              style: const TextStyle(color: AppTheme.textMain),
              items: widget.accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc.name))).toList(),
              onChanged: (v) => setState(() => _selectedAccount = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (Optional)'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(_amountController.text) ?? 0.0;
                  if (amt > 0 && _selectedAccount != null) {
                    widget.onSave(amt, selectedCategory, _selectedAccount!.id, _noteController.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isIncome ? AppTheme.income : AppTheme.expense,
                ),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
