import 'package:flutter/material.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});
  @override
  State<DebtsScreen> createState() => DebtsScreenState();
}

class DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
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
    _debtsSubscription = _firebaseService.getDebts().listen((debts) {
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
    // Use lowercase key for grouping (case-insensitive), display original capitalized name
    Map<String, double> personBalances = {};
    Map<String, String> personDisplayName = {}; // lowercase -> display name

    for (var d in _ioweList) {
      final raw = (d['person'] ?? 'Unknown') as String;
      final key = raw.trim().toLowerCase();
      personBalances[key] = (personBalances[key] ?? 0.0) - _safeConvertAmount(d['amount']);
      // Keep the most recent display name
      personDisplayName[key] ??= raw.trim();
    }
    for (var d in _owedToMeList) {
      final raw = (d['person'] ?? 'Unknown') as String;
      final key = raw.trim().toLowerCase();
      personBalances[key] = (personBalances[key] ?? 0.0) + _safeConvertAmount(d['amount']);
      personDisplayName[key] ??= raw.trim();
    }

    _consolidatedDebts = {};
    personBalances.forEach((key, b) {
      final displayName = personDisplayName[key] ?? key;
      if (b.abs() > 0.001) {
        _consolidatedDebts[displayName] = {
          'balance': b,
          'status': b > 0 ? 'owed_to_me' : 'i_owe',
          'absAmount': b.abs(),
        };
      }
    });
  }

  void _filterDebts() {
    bool matches(Map<String, dynamic> d) {
      final q = _searchQuery.trim().toLowerCase();
      return q.isEmpty
          || (d['person'] ?? '').toString().toLowerCase().contains(q)
          || (d['notes'] ?? '').toString().toLowerCase().contains(q);
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
      body: Column(
        children: [
          // ── Tab Bar ───────────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textDim,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              tabs: const [
                Tab(text: 'Summary'),
                Tab(text: 'I Owe'),
                Tab(text: 'Owed To Me'),
              ],
            ),
          ),
          // ── Tab Content ───────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildDebtListTab(_filteredIOweList, true),
                _buildDebtListTab(_filteredOwedToMeList, false),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDebtMenu,
        backgroundColor: AppTheme.primary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Container(
            height: 44,
            decoration: AppTheme.cardDecoration(radius: 12),
            child: TextField(
              onChanged: (v) => setState(() { _searchQuery = v; _filterDebts(); }),
              decoration: const InputDecoration(
                hintText: 'Search people...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textDim, size: 18),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('No entries', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontBody)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _buildDebtItem(list[index], isIOwe),
                ),
        ),
      ],
    );
  }

  Widget _buildDebtItem(Map<String, dynamic> d, bool isIOwe) {
    final amount = _safeConvertAmount(d['amount']);
    final color = isIOwe ? AppTheme.expense : AppTheme.income;
    return GestureDetector(
      onTap: () => _showDebtDetails(d, isIOwe),
      onLongPress: () => _showDebtActions(d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppTheme.cardDecoration(radius: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text((d['person'] ?? '?')[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['person'] ?? 'Unknown', style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(d['notes'] ?? 'No notes', style: const TextStyle(color: AppTheme.textDim, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('\$${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showDebtDetails(Map<String, dynamic> d, bool isIOwe) {
    final amount = _safeConvertAmount(d['amount']);
    final color = isIOwe ? AppTheme.expense : AppTheme.income;
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
            CircleAvatar(radius: 28, backgroundColor: color.withValues(alpha: 0.15),
              child: Text((d['person'] ?? '?')[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 22))),
            const SizedBox(height: 10),
            Text(d['person'] ?? 'Unknown', style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(isIOwe ? 'You owe them' : 'They owe you', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            if ((d['notes'] ?? '').toString().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.cardDecoration(radius: 12),
                child: Row(children: [
                  const Icon(Icons.notes_rounded, size: 16, color: AppTheme.textDim),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d['notes'].toString(), style: const TextStyle(color: AppTheme.textMain, fontSize: 13))),
                ]),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(ctx); _showDebtActions(d); },
                icon: const Icon(Icons.more_horiz_rounded, size: 18),
                label: const Text('Actions'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMain, side: const BorderSide(color: AppTheme.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDebtActions(Map<String, dynamic> d) {
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
            Text(d['person'] ?? 'Entry', style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: AppTheme.accent.withValues(alpha: 0.08),
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accent),
              title: const Text('Delete Entry', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _confirmDelete(d['id']); },
            ),
          ],
        ),
      ),
    );
  }

  void _showDebtMenu() {
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

  void showAddSheet() {
    _showAddDebtSheet(true);
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
