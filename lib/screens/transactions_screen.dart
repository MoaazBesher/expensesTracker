import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/native_pending_sync.dart';
import '../services/storage_service.dart';
import '../models/account_model.dart';
import '../utils/app_theme.dart';
import '../utils/app_localization.dart';
import '../utils/screen_utils.dart';
import '../utils/offline_transactions_merge.dart';
import '../utils/transaction_list_helpers.dart';
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
  List<Map<String, dynamic>> _lastRemoteTx = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _filterCategory;
  String? _filterAccountId;
  bool _filterPendingOnly = false;
  TransactionListSort _sort = TransactionListSort.dateNewest;
  bool _isLoading = true;
  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  StreamSubscription? _transactionsSubscription;
  final FirebaseService _firebaseService = FirebaseService();

  bool _txnSelectMode = false;
  final Set<String> _txnSelectedIds = {};

  /// Called after [StorageService.syncAllLocalData] from app shell (e.g. connectivity restored).
  Future<void> reloadAfterSync() async {
    final merged =
        await mergeFirebaseMonthWithPendingLocal(_lastRemoteTx, _currentMonth);
    if (!mounted) return;
    setState(() {
      _transactions = merged;
      _filteredTransactions = _computeProcessedList();
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTxnTabChanged);
    _loadTransactions();
    _loadAccounts();
  }

  void _onTxnTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_txnSelectMode) {
      setState(() => _txnSelectedIds.clear());
    }
  }

  String _transactionSelectionKey(Map<String, dynamic> t) => t['id']?.toString() ?? '';

  List<Map<String, dynamic>> _currentTabTransactions() {
    final type = _tabController.index == 0 ? 'income' : 'expense';
    return _filteredTransactions.where((t) => t['type'] == type).toList();
  }

  void _exitTxnSelectMode() {
    setState(() {
      _txnSelectMode = false;
      _txnSelectedIds.clear();
    });
  }

  /// System / predictive back: clear selection or inner tab before shell handles nav.
  bool tryHandleAndroidBack() {
    if (_txnSelectMode) {
      _exitTxnSelectMode();
      return true;
    }
    if (_tabController.index > 0) {
      _tabController.animateTo(_tabController.index - 1);
      return true;
    }
    return false;
  }

  Future<void> _deleteTransactionRow(Map<String, dynamic> t) async {
    final localId = _localSqliteId(t);
    if (localId != null) {
      await StorageService.deleteLocalTransaction(localId);
    } else {
      await _firebaseService.deleteTransaction(
        t['id'].toString(),
        t['accountId'] ?? '',
        t['type'],
        _safeConvertAmount(t['amount']),
      );
    }
  }

  void _confirmBulkDeleteTransactions() {
    final list = _currentTabTransactions().where((t) => _txnSelectedIds.contains(_transactionSelectionKey(t))).toList();
    if (list.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete ${list.length} transactions?', style: const TextStyle(fontSize: 16)),
        content: const Text('This cannot be undone.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final t in list) {
                try {
                  await _deleteTransactionRow(t);
                } catch (_) {}
              }
              if (mounted) {
                _exitTxnSelectMode();
                await reloadAfterSync();
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnSelectionBar() {
    final list = _currentTabTransactions();
    final n = _txnSelectedIds.length;
    return Material(
      elevation: 12,
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel',
                onPressed: _exitTxnSelectMode,
              ),
              Expanded(
                child: Text(
                  n == 0 ? 'Select items' : '$n selected',
                  style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: list.isEmpty
                    ? null
                    : () => setState(() {
                          _txnSelectedIds
                            ..clear()
                            ..addAll(list.map(_transactionSelectionKey).where((k) => k.isNotEmpty));
                        }),
                child: Text('All'.tr),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.accent,
                tooltip: 'Delete selected',
                onPressed: n == 0 ? null : _confirmBulkDeleteTransactions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTxnTabChanged);
    _tabController.dispose();
    _transactionsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var n = 0;
    if (_filterCategory != null) n++;
    if (_filterAccountId != null) n++;
    if (_filterPendingOnly) n++;
    return n;
  }

  void _loadAccounts() {
    _firebaseService.getAccounts().listen((accounts) {
      if (mounted) setState(() { _accounts = accounts; if (_accounts.isNotEmpty && _selectedAccount == null) _selectedAccount = _accounts.first; });
    });
  }

  void _loadTransactions() async {
    setState(() => _isLoading = true);
    await NativePendingSync.syncQuickAddQueue();
    _transactionsSubscription?.cancel();
    if (await _firebaseService.isConnected) {
      await StorageService.syncAllLocalData();
    }
    _transactionsSubscription =
        _firebaseService.getMonthlyTransactions(_currentMonth).listen(
      (txns) async {
        _lastRemoteTx = txns;
        final merged =
            await mergeFirebaseMonthWithPendingLocal(txns, _currentMonth);
        if (!mounted) return;
        setState(() {
          _transactions = merged;
          _filteredTransactions = _computeProcessedList();
          _isLoading = false;
        });
      },
    );
  }

  List<Map<String, dynamic>> _computeProcessedList() {
    final q = _searchQuery.trim().toLowerCase();
    final list = _transactions.where((t) {
      if (q.isNotEmpty) {
        final cat = t['category']?.toString().toLowerCase() ?? '';
        final note = t['note']?.toString().toLowerCase() ?? '';
        if (!cat.contains(q) && !note.contains(q)) return false;
      }
      if (_filterCategory != null &&
          (t['category']?.toString() ?? '') != _filterCategory) {
        return false;
      }
      if (_filterAccountId != null) {
        final aid = t['accountId']?.toString() ?? '';
        if (aid != _filterAccountId) return false;
      }
      if (_filterPendingOnly && t['pendingSync'] != true) return false;
      return true;
    }).toList();
    sortTransactions(list, _sort);
    return list;
  }

  String _accountNameForId(String? id) {
    if (id == null || id.isEmpty) return 'Default';
    for (final a in _accounts) {
      if (a.id == id) return a.name;
    }
    return id;
  }

  Widget _toolbarIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppTheme.primary.withValues(alpha: 0.55) : AppTheme.border,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Icon(icon, size: 20, color: active ? AppTheme.primary : AppTheme.textDim),
          ),
        ),
      ),
    );
  }

  Widget _sortMenuButton() {
    return Theme(
      data: Theme.of(context).copyWith(cardColor: AppTheme.surfaceLight),
      child: PopupMenuButton<TransactionListSort>(
        tooltip: 'Sort',
        padding: EdgeInsets.zero,
        color: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        offset: const Offset(0, 46),
        onSelected: (v) => setState(() {
          _sort = v;
          _filteredTransactions = _computeProcessedList();
        }),
        itemBuilder: (context) => TransactionListSort.values
            .map(
              (s) => PopupMenuItem<TransactionListSort>(
                value: s,
                child: Row(
                  children: [
                    Icon(s.icon, size: 18, color: _sort == s ? AppTheme.primary : AppTheme.textDim),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMain,
                          fontWeight: _sort == s ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_sort == s) const Icon(Icons.check_rounded, size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: AppTheme.cardDecoration(radius: 12),
          child: const Icon(Icons.sort_rounded, size: 22, color: AppTheme.primary),
        ),
      ),
    );
  }

  Widget _activeFilterChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_filterCategory != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text('Category · $_filterCategory', style: const TextStyle(fontSize: 11)),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => setState(() {
                  _filterCategory = null;
                  _filteredTransactions = _computeProcessedList();
                }),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: AppTheme.surfaceLight,
                side: const BorderSide(color: AppTheme.border),
              ),
            ),
          if (_filterAccountId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text('Account · ${_accountNameForId(_filterAccountId)}', style: const TextStyle(fontSize: 11)),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => setState(() {
                  _filterAccountId = null;
                  _filteredTransactions = _computeProcessedList();
                }),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: AppTheme.surfaceLight,
                side: const BorderSide(color: AppTheme.border),
              ),
            ),
          if (_filterPendingOnly)
            InputChip(
              label: const Text('Pending upload only', style: TextStyle(fontSize: 11)),
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              onDeleted: () => setState(() {
                _filterPendingOnly = false;
                _filteredTransactions = _computeProcessedList();
              }),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: AppTheme.surfaceLight,
              side: const BorderSide(color: AppTheme.border),
            ),
        ],
      ),
    );
  }

  void _showFiltersBottomSheet() {
    String? cat = _filterCategory;
    String? acc = _filterAccountId;
    var pend = _filterPendingOnly;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Filters'.tr, style: const TextStyle(color: AppTheme.textMain, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text('Category'.tr, style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: AppTheme.cardDecoration(radius: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: cat,
                        hint: Text('All categories'.tr, style: const TextStyle(color: AppTheme.textDim, fontSize: 13)),
                        dropdownColor: AppTheme.surfaceLight,
                        style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                        items: [
                          DropdownMenuItem<String?>(value: null, child: Text('All categories'.tr)),
                          ...distinctCategories(_transactions).map(
                            (c) => DropdownMenuItem<String?>(value: c, child: Text(c.tr)),
                          ),
                        ],
                        onChanged: (v) => setSheet(() => cat = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Account'.tr, style: const TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: AppTheme.cardDecoration(radius: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: acc,
                        hint: const Text('All accounts', style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
                        dropdownColor: AppTheme.surfaceLight,
                        style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All accounts')),
                          ..._accounts.map(
                            (a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)),
                          ),
                        ],
                        onChanged: (v) => setSheet(() => acc = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pending upload only', style: TextStyle(color: AppTheme.textMain, fontSize: 13)),
                    subtitle: const Text('Items not yet synced to the cloud', style: TextStyle(color: AppTheme.textDim, fontSize: 11)),
                    value: pend,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (v) => setSheet(() => pend = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setSheet(() {
                          cat = null;
                          acc = null;
                          pend = false;
                        }),
                        child: Text('Reset'.tr, style: const TextStyle(color: AppTheme.textDim)),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _filterCategory = cat;
                            _filterAccountId = acc;
                            _filterPendingOnly = pend;
                            _filteredTransactions = _computeProcessedList();
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Apply Filters'.tr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int? _localSqliteId(Map<String, dynamic> t) {
    final id = t['id'];
    if (id is String && id.startsWith('local_')) {
      return int.tryParse(id.replaceFirst('local_', ''));
    }
    return null;
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
        onSave: (amount, category, accountId, note) =>
            _saveTransaction(isIncome, amount, category, accountId, note),
      ),
    );
  }

  void _saveTransaction(bool isIncome, double amount, String category, String accountId, String note) async {
    if (mounted) Navigator.pop(context);
    final type = isIncome ? 'income' : 'expense';
    final at = DateTime.now();
    final payload = {
      'type': type,
      'amount': amount.toString(),
      'category': category,
      'date': at.toIso8601String(),
      'accountId': accountId,
      'note': note,
      'createdAt': at.toIso8601String(),
    };

    try {
      if (await _firebaseService.isConnected) {
        await _firebaseService.addTransaction(
          type: type,
          amount: amount,
          category: category,
          date: at,
          accountId: accountId,
          note: note,
          clientCreatedAt: at,
        );
      } else {
        await StorageService.saveLocalTransaction(payload);
      }
      if (mounted) {
        _showSuccess('${isIncome ? 'Income' : 'Expense'} added');
        await reloadAfterSync();
      }
    } catch (e) {
      try {
        await StorageService.saveLocalTransaction(payload);
        if (mounted) {
          _showSuccess('Saved offline — will sync when online');
          await reloadAfterSync();
        }
      } catch (_) {
        if (mounted) _showError('Failed: $e');
      }
    }
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
              tabs: [
                Tab(text: 'Income'.tr),
                Tab(text: 'Expenses'.tr),
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
      floatingActionButton: _txnSelectMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddMenu,
              backgroundColor: AppTheme.primary,
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
      bottomNavigationBar: _txnSelectMode ? _buildTxnSelectionBar() : null,
    );
  }

  Widget _buildTransactionsContent(String type) {
    final filtered = _filteredTransactions.where((t) => t['type'] == type).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: AppTheme.cardDecoration(radius: 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          setState(() {
                            _searchQuery = v;
                            _filteredTransactions = _computeProcessedList();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search category or note…',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textDim, size: 18),
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_txnSelectMode)
                    _toolbarIconButton(
                      icon: Icons.checklist_rtl_rounded,
                      tooltip: 'Select multiple',
                      active: false,
                      onTap: () => setState(() => _txnSelectMode = true),
                    ),
                  if (!_txnSelectMode) const SizedBox(width: 6),
                  _toolbarIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Filters',
                    active: _activeFilterCount > 0,
                    onTap: _showFiltersBottomSheet,
                  ),
                  const SizedBox(width: 6),
                  _sortMenuButton(),
                ],
              ),
              if (_activeFilterCount > 0) ...[
                const SizedBox(height: 10),
                _activeFilterChipsRow(),
              ],
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
    final noteText = (t['note'] ?? '').toString().trim();
    final key = _transactionSelectionKey(t);
    final selected = _txnSelectMode && key.isNotEmpty && _txnSelectedIds.contains(key);

    return GestureDetector(
      onTap: () {
        if (_txnSelectMode) {
          if (key.isEmpty) return;
          setState(() {
            if (selected) {
              _txnSelectedIds.remove(key);
            } else {
              _txnSelectedIds.add(key);
            }
          });
        } else {
          _showTransactionDetails(t);
        }
      },
      onLongPress: _txnSelectMode
          ? null
          : () {
              if (key.isEmpty) return;
              setState(() {
                _txnSelectMode = true;
                _txnSelectedIds.add(key);
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: AppTheme.cardDecoration(radius: 12).copyWith(
          border: selected ? Border.all(color: AppTheme.primary, width: 2) : null,
        ),
        child: Row(
          children: [
            if (_txnSelectMode) ...[
              SizedBox(
                width: 28,
                child: Checkbox(
                  value: selected,
                  onChanged: key.isEmpty
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _txnSelectedIds.add(key);
                            } else {
                              _txnSelectedIds.remove(key);
                            }
                          });
                        },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 4),
            ],
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
                  Text((t['category'] ?? 'General').toString().tr, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  if (t['date'] != null)
                    Text(DateFormat('MMM dd, yyyy  •  hh:mm a').format(DateTime.parse(t['date'])), style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                  if (noteText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1, right: 4),
                          child: Icon(Icons.notes_rounded, size: 11, color: AppTheme.textDim.withValues(alpha: 0.65)),
                        ),
                        Expanded(
                          child: Text(
                            noteText,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textDim.withValues(alpha: 0.88),
                              fontSize: 10,
                              height: 1.2,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (t['pendingSync'] == true) ...[
                  Tooltip(
                    message: 'Pending upload',
                    child: Icon(Icons.cloud_queue_rounded, size: 16, color: AppTheme.textDim.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(width: 6),
                ],
                Text('${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
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
    final noteTrim = (t['note'] ?? '').toString().trim();
    final accountName = _accountNameForId(t['accountId']?.toString());
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
        return Container(
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
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
                _detailRow(Icons.account_balance_wallet_rounded, 'Account', accountName),
                if (noteTrim.isNotEmpty) _detailRow(Icons.notes_rounded, 'Note', noteTrim),
                if (t['pendingSync'] == true)
                  _detailRow(Icons.cloud_queue_rounded, 'Sync', 'Waiting for upload'),
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
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textDim),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 13)),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ],
            ),
          ),
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
                  decoration: InputDecoration(labelText: 'Amount'.tr, prefixText: '\$ ', focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 1.5))),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(labelText: 'Category'.tr),
                  dropdownColor: AppTheme.surfaceLight,
                  style: const TextStyle(color: AppTheme.textMain),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.tr))).toList(),
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
                  decoration: InputDecoration(labelText: 'Note (optional)'.tr),
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
                      final localId = _localSqliteId(t);
                      if (localId != null) {
                        await StorageService.updateLocalTransaction(
                          localId,
                          amount: amt,
                          category: selectedCategory,
                          dateIso: pickedDate.toIso8601String(),
                          note: noteCtrl.text,
                        );
                      } else {
                        await _firebaseService.updateTransaction(
                          transactionId: t['id'].toString(),
                          accountId: t['accountId'] ?? '',
                          oldType: t['type'],
                          oldAmount: _safeConvertAmount(t['amount']),
                          newType: t['type'],
                          newAmount: amt,
                          category: selectedCategory,
                          date: pickedDate,
                          note: noteCtrl.text,
                        );
                      }
                      if (mounted) {
                        _showSuccess('Transaction updated');
                        await reloadAfterSync();
                      }
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
            Text('New Entry'.tr, style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddOption('Income'.tr, Icons.add_chart_rounded, AppTheme.income, true),
                _buildAddOption('Expense'.tr, Icons.bar_chart_rounded, AppTheme.expense, false),
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
              await _deleteTransactionRow(t);
              if (mounted) await reloadAfterSync();
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
              decoration: InputDecoration(labelText: 'Amount'.tr, prefixText: '\$ '),
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
              decoration: InputDecoration(labelText: 'Account'.tr),
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
