import 'package:flutter/material.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});
  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _consolidatedDebts = {};
  List<Map<String, dynamic>> _ioweList = [];
  List<Map<String, dynamic>> _owedToMeList = [];
  List<Map<String, dynamic>> _filteredIOweList = [];
  List<Map<String, dynamic>> _filteredOwedToMeList = [];
  StreamSubscription? _debtsSubscription;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    _debtsSubscription?.cancel();
    _debtsSubscription = FirebaseService().getDebts().listen((debts) {
      if (mounted) { setState(() { _processDebtsData(debts); _filterDebts(); }); }
    });
  }

  void _processDebtsData(Map<String, dynamic> debts) {
    if (debts['iOwe'] is List) {
      _ioweList = List<Map<String, dynamic>>.from(debts['iOwe']);
      _ioweList.sort((a, b) => DateTime.parse(b['createdAt'] ?? '2000-01-01').compareTo(DateTime.parse(a['createdAt'] ?? '2000-01-01')));
    }
    if (debts['owedToMe'] is List) {
      _owedToMeList = List<Map<String, dynamic>>.from(debts['owedToMe']);
      _owedToMeList.sort((a, b) => DateTime.parse(b['createdAt'] ?? '2000-01-01').compareTo(DateTime.parse(a['createdAt'] ?? '2000-01-01')));
    }
    _calculateConsolidatedDebts();
  }

  void _calculateConsolidatedDebts() {
    Map<String, double> personBalances = {};
    for (var d in _ioweList) {
      final p = d['person'] ?? 'Unknown';
      personBalances[p] = (personBalances[p] ?? 0.0) - _safeConvertAmount(d['amount']);
    }
    for (var d in _owedToMeList) {
      final p = d['person'] ?? 'Unknown';
      personBalances[p] = (personBalances[p] ?? 0.0) + _safeConvertAmount(d['amount']);
    }
    _consolidatedDebts = {};
    personBalances.forEach((p, b) {
      if (b != 0) _consolidatedDebts[p] = {'balance': b, 'status': b > 0 ? 'owed_to_me' : 'i_owe', 'absAmount': b.abs()};
    });
  }

  void _filterDebts() {
    bool matches(Map<String, dynamic> d) {
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || (d['person'] ?? '').toString().toLowerCase().contains(q) || (d['notes'] ?? '').toString().toLowerCase().contains(q);
    }
    _filteredIOweList = _ioweList.where(matches).toList();
    _filteredOwedToMeList = _owedToMeList.where(matches).toList();
  }

  double _safeConvertAmount(dynamic a) {
    if (a == null) return 0.0;
    if (a is num) return a.toDouble();
    if (a is String) return double.tryParse(a) ?? 0.0;
    return 0.0;
  }

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
            Tab(text: 'Summary'),
            Tab(text: 'I Owe'),
            Tab(text: 'Owed To Me'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildDebtListTab(_filteredIOweList, true),
          _buildDebtListTab(_filteredOwedToMeList, false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDebtMenu,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_consolidatedDebts.isEmpty) return Center(child: Text('No active debts', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontBody)));
    return ListView.builder(
      padding: EdgeInsets.all(S.sectionPadding),
      itemCount: _consolidatedDebts.length,
      itemBuilder: (context, index) {
        String person = _consolidatedDebts.keys.elementAt(index);
        var data = _consolidatedDebts[person];
        bool isOwedToMe = data['status'] == 'owed_to_me';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(radius: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (isOwedToMe ? AppTheme.income : AppTheme.expense).withValues(alpha: 0.1),
                child: Text(person[0].toUpperCase(), style: TextStyle(color: isOwedToMe ? AppTheme.income : AppTheme.expense, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(isOwedToMe ? 'Owes you' : 'You owe them', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontSmall)),
                  ],
                ),
              ),
              Text('\$${data['absAmount'].toStringAsFixed(0)}', style: TextStyle(color: isOwedToMe ? AppTheme.income : AppTheme.expense, fontWeight: FontWeight.w600, fontSize: 17)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebtListTab(List<Map<String, dynamic>> list, bool isIOwe) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(S.sectionPadding),
          child: Container(
            height: 42,
            decoration: AppTheme.cardDecoration(radius: 10),
            child: TextField(
              onChanged: (v) => setState(() { _searchQuery = v; _filterDebts(); }),
              decoration: const InputDecoration(
                hintText: 'Search people...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: AppTheme.textDim, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('No entries', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontBody)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: S.sectionPadding),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _buildDebtItem(list[index], isIOwe),
                ),
        ),
      ],
    );
  }

  Widget _buildDebtItem(Map<String, dynamic> d, bool isIOwe) {
    final amount = _safeConvertAmount(d['amount']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(d['person'] ?? 'Unknown', style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(d['notes'] ?? 'No notes', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontSmall)),
        trailing: Text('\$${amount.toStringAsFixed(0)}', style: TextStyle(color: isIOwe ? AppTheme.expense : AppTheme.income, fontWeight: FontWeight.w600, fontSize: 15)),
        onLongPress: () => _confirmDelete(d['id']),
      ),
    );
  }

  void _showAddDebtMenu() {
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
            const Text('New Debt', style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddOption('I Owe', Icons.upload_rounded, AppTheme.expense, true),
                _buildAddOption('Owed to Me', Icons.download_rounded, AppTheme.income, false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(String label, IconData icon, Color color, bool isIOwe) {
    return InkWell(
      onTap: () { Navigator.pop(context); _showAddDebtSheet(isIOwe); },
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

  void _showAddDebtSheet(bool isIOwe) {
    final personController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              Text('Add ${isIOwe ? 'I Owe' : 'Owed to Me'}', style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              TextField(
                controller: personController,
                decoration: const InputDecoration(labelText: 'Person'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final p = personController.text.trim();
                    final a = double.tryParse(amountController.text) ?? 0.0;
                    if (p.isNotEmpty && a > 0) {
                      await FirebaseService().addDebt(type: isIOwe ? 'iOwe' : 'owedToMe', person: p, amount: a, notes: noteController.text);
                      await StorageService.saveLocalDebt(isIOwe ? 'iOwe' : 'owedToMe', {
                        'amount': a.toString(), 'person': p, 'notes': noteController.text, 'dueDate': null,
                        'createdAt': DateTime.now().toIso8601String(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: isIOwe ? AppTheme.expense : AppTheme.income),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String? id) {
    if (id == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Entry?', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () async { Navigator.pop(context); await FirebaseService().deleteDebt(id); },
            child: const Text('Delete', style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debtsSubscription?.cancel();
    super.dispose();
  }
}
