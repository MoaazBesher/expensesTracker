import 'dart:async';
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
  State<TransactionsScreen> createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateTime _currentMonth = DateTime.now();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  String _searchQuery = '';
  final String _selectedType = 'all';
  bool _isLoading = true;
  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  StreamSubscription? _transactionsSubscription;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
    _loadAccounts();
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  void _loadAccounts() {
    _firebaseService.getAccounts().listen((accounts) {
      if (mounted) setState(() { _accounts = accounts; if (_accounts.isNotEmpty && _selectedAccount == null) _selectedAccount = _accounts.first; });
    });
  }

  void _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      _transactionsSubscription?.cancel();
      _transactionsSubscription = _firebaseService.getMonthlyTransactions(_currentMonth).listen((txns) {
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

  void showAddSheet(bool isIncome) {
    _showAddTransactionSheet(isIncome);
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
    if (mounted) Navigator.pop(context);
    try {
      await _firebaseService.addTransaction(
        type: isIncome ? 'income' : 'expense', amount: amount, category: category,
        date: DateTime.now(), accountId: accountId, note: note,
      );
      await StorageService.saveLocalTransaction({
        'type': isIncome ? 'income' : 'expense', 'amount': amount.toString(), 'category': category,
        'date': DateTime.now().toIso8601String(), 'accountId': accountId, 'note': note,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (mounted) { _showSuccess('${isIncome ? 'Income' : 'Expense'} added'); _loadTransactions(); }
    } catch (e) { if (mounted) _showError('Failed: $e'); }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12)), backgroundColor: AppTheme.accent));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12)), backgroundColor: AppTheme.secondary));

  @override
  Widget build(BuildContext context) {
    S.init(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textDim,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              tabs: const [
                Tab(text: 'Income'),
                Tab(text: 'Expenses'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsContent('income'),
                _buildTransactionsContent('expense'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        backgroundColor: AppTheme.primary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildTransactionsContent(String type) {
    final filtered = _filteredTransactions.where((t) => t['type'] == type).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: AppTheme.cardDecoration(radius: 12),
                  child: TextField(
                    onChanged: (v) { setState(() { _searchQuery = v; _filterTransactions(); }); },
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
              : filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async => _loadTransactions(),
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    return GestureDetector(
      onTap: () => _showTransactionDetails(t),
      onLongPress: () => _showTransactionActions(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppTheme.cardDecoration(radius: 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['category'] ?? 'General', style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  if (t['date'] != null)
                    Text(DateFormat('MMM dd, yyyy  •  hh:mm a').format(DateTime.parse(t['date'])), style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                ],
              ),
            ),
            Text('${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final amount = _safeConvertAmount(t['amount']);
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    final date = t['date'] != null ? DateFormat('EEEE, MMM dd yyyy  •  hh:mm a').format(DateTime.parse(t['date'])) : 'N/A';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text('${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t['category'] ?? 'General', style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            _detailRow(Icons.calendar_today_rounded, 'Date', date),
            _detailRow(Icons.category_rounded, 'Type', isIncome ? 'Income' : 'Expense'),
            if ((t['note'] ?? '').toString().isNotEmpty)
              _detailRow(Icons.notes_rounded, 'Note', t['note'].toString()),
            if ((t['accountId'] ?? '').toString().isNotEmpty)
              _detailRow(Icons.account_balance_wallet_rounded, 'Account ID', t['accountId'].toString()),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _showTransactionActions(t); },
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                    label: const Text('Actions'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMain, side: const BorderSide(color: AppTheme.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textDim),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showTransactionActions(Map<String, dynamic> t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(t['category'] ?? 'Transaction', style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: AppTheme.surfaceLight,
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primary),
              title: const Text('Edit Transaction', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _showEditTransactionSheet(t); },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: AppTheme.accent.withValues(alpha: 0.08),
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accent),
              title: const Text('Delete Transaction', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _confirmDelete(t); },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionSheet(Map<String, dynamic> t) {
    final isIncome = t['type'] == 'income';
    final categories = isIncome
        ? ['Salary', 'Freelance', 'Investment', 'Business', 'Gift', 'Other']
        : ['Food', 'Transportation', 'Entertainment', 'Utilities', 'Shopping', 'Healthcare', 'Other'];

    final amountCtrl = TextEditingController(text: _safeConvertAmount(t['amount']).toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: t['note']?.toString() ?? '');
    String selectedCategory = categories.contains(t['category']) ? t['category'] : categories.first;

    DateTime pickedDate = t['date'] != null ? DateTime.parse(t['date']) : DateTime.now();
    TimeOfDay pickedTime = TimeOfDay(hour: pickedDate.hour, minute: pickedDate.minute);

    final color = isIncome ? AppTheme.income : AppTheme.expense;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Center(child: Text('Edit ${isIncome ? 'Income' : 'Expense'}', style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w700))),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Amount', prefixText: '\$ ', focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 1.5))),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  dropdownColor: AppTheme.surfaceLight,
                  style: const TextStyle(color: AppTheme.textMain),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setSheet(() => selectedCategory = v!),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded, size: 16),
                        label: Text(DateFormat('MMM dd, yyyy').format(pickedDate), style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final d = await showDatePicker(context: ctx, initialDate: pickedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (d != null) setSheet(() => pickedDate = DateTime(d.year, d.month, d.day, pickedTime.hour, pickedTime.minute));
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMain, side: const BorderSide(color: AppTheme.border), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(pickedTime.format(ctx), style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final t2 = await showTimePicker(context: ctx, initialTime: pickedTime);
                          if (t2 != null) setSheet(() { pickedTime = t2; pickedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, t2.hour, t2.minute); });
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMain, side: const BorderSide(color: AppTheme.border), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Note (Optional)'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                      if (amt <= 0) return;
                      Navigator.pop(ctx);
                      await _firebaseService.updateTransaction(
                        transactionId: t['id'],
                        accountId: t['accountId'] ?? '',
                        oldType: t['type'],
                        oldAmount: _safeConvertAmount(t['amount']),
                        newType: t['type'],
                        newAmount: amt,
                        category: selectedCategory,
                        date: pickedDate,
                        note: noteCtrl.text,
                      );
                      if (mounted) { _showSuccess('Transaction updated'); _loadTransactions(); }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              await _firebaseService.deleteTransaction(t['id'], t['accountId'] ?? '', t['type'], _safeConvertAmount(t['amount']));
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
