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

  bool _debtSelectMode = false;
  final Set<String> _debtSelectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onDebtTabChanged);
    _loadDebts();
  }

  void _onDebtTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      if (_debtSelectMode) setState(() { _debtSelectMode = false; _debtSelectedIds.clear(); });
      return;
    }
    if (_debtSelectMode) setState(() => _debtSelectedIds.clear());
  }

  String _debtSelectionKey(Map<String, dynamic> d) => d['id']?.toString() ?? '';

  List<Map<String, dynamic>> _currentDebtList() {
    if (_tabController.index == 1) return _filteredIOweList;
    if (_tabController.index == 2) return _filteredOwedToMeList;
    return [];
  }

  void _exitDebtSelectMode() {
    setState(() {
      _debtSelectMode = false;
      _debtSelectedIds.clear();
    });
  }

  bool tryHandleAndroidBack() {
    if (_debtSelectMode) {
      _exitDebtSelectMode();
      return true;
    }
    if (_tabController.index > 0) {
      _tabController.animateTo(_tabController.index - 1);
      return true;
    }
    return false;
  }

  Future<void> _deleteDebtOne(Map<String, dynamic> d) async {
    final localId = _localSqliteId(d);
    if (localId != null) {
      await StorageService.deleteLocalDebt(localId);
    } else {
      await _firebaseService.deleteDebt(d['id'].toString());
    }
  }

  void _confirmBulkDeleteDebts() {
    final list = _currentDebtList().where((d) => _debtSelectedIds.contains(_debtSelectionKey(d))).toList();
    if (list.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete ${list.length} entries?', style: const TextStyle(fontSize: 16)),
        content: const Text('This cannot be undone.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              for (final d in list) {
                try {
                  await _deleteDebtOne(d);
                } catch (_) {}
              }
              if (mounted) {
                _exitDebtSelectMode();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Deleted ${list.length} ${list.length == 1 ? 'entry' : 'entries'}', style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppTheme.secondary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
                _loadDebts();
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtSelectionBar() {
    final list = _currentDebtList();
    final n = _debtSelectedIds.length;
    return Material(
      elevation: 12,
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Cancel', onPressed: _exitDebtSelectMode),
              Expanded(
                child: Text(
                  n == 0 ? 'Select entries' : '$n selected',
                  style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: list.isEmpty
                    ? null
                    : () => setState(() {
                          _debtSelectedIds
                            ..clear()
                            ..addAll(list.map(_debtSelectionKey).where((k) => k.isNotEmpty));
                        }),
                child: const Text('All'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.accent,
                tooltip: 'Delete selected',
                onPressed: n == 0 ? null : _confirmBulkDeleteDebts,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadDebts() async {
    _debtsSubscription?.cancel();
    _debtsSubscription = _firebaseService.getDebts().listen((debts) async {
      // Merge unsynced local debts so offline-saved items appear immediately
      try {
        final localDebts = await StorageService.getLocalDebts();
        // Only add local debts that haven't been synced yet (no firebase_id)
        for (final entry in localDebts.entries) {
          final list = entry.value;
          for (final localDebt in list) {
            if (localDebt['isLocal'] == true) {
              // Avoid duplicates: check if a firebase debt with same person/amount/time exists
              final targetList = debts[entry.key] as List;
              final isDuplicate = targetList.any((fd) =>
                fd['person'] == localDebt['person'] &&
                _safeConvertAmount(fd['amount']).toStringAsFixed(2) == _safeConvertAmount(localDebt['amount']).toStringAsFixed(2) &&
                _safeParseDate(fd['createdAt']).difference(_safeParseDate(localDebt['createdAt'])).inSeconds.abs() < 5);
              if (!isDuplicate) {
                targetList.add(localDebt);
              }
            }
          }
        }
      } catch (_) {}
      if (mounted) { setState(() { _processDebtsData(debts); _filterDebts(); }); }
    });
  }

  /// Safely parse a createdAt value that may be a Timestamp, String, or null.
  DateTime _safeParseDate(dynamic value) {
    if (value == null) return DateTime(2000);
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2000);
    // Handle Firestore Timestamp objects that might slip through
    try { return (value as dynamic).toDate(); } catch (_) {}
    return DateTime(2000);
  }

  void _processDebtsData(Map<String, dynamic> debts) {
    if (debts['iOwe'] is List) {
      _ioweList = List<Map<String, dynamic>>.from(debts['iOwe']);
      _ioweList.sort((a, b) => _safeParseDate(b['createdAt']).compareTo(_safeParseDate(a['createdAt'])));
    }
    if (debts['owedToMe'] is List) {
      _owedToMeList = List<Map<String, dynamic>>.from(debts['owedToMe']);
      _owedToMeList.sort((a, b) => _safeParseDate(b['createdAt']).compareTo(_safeParseDate(a['createdAt'])));
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
      floatingActionButton: (_debtSelectMode && _tabController.index != 0)
          ? null
          : FloatingActionButton(
              onPressed: _showDebtMenu,
              backgroundColor: AppTheme.primary,
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
      bottomNavigationBar: (_debtSelectMode && _tabController.index != 0) ? _buildDebtSelectionBar() : null,
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
          child: Row(
            children: [
              Expanded(
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
              if (!_debtSelectMode) ...[
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLight.withValues(alpha: 0.35),
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.checklist_rtl_rounded, size: 20, color: AppTheme.primary),
                  tooltip: 'Select multiple',
                  onPressed: () => setState(() => _debtSelectMode = true),
                ),
              ],
            ],
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
    final key = _debtSelectionKey(d);
    final selected = _debtSelectMode && key.isNotEmpty && _debtSelectedIds.contains(key);

    return GestureDetector(
      onTap: () {
        if (_debtSelectMode) {
          if (key.isEmpty) return;
          setState(() {
            if (selected) {
              _debtSelectedIds.remove(key);
            } else {
              _debtSelectedIds.add(key);
            }
          });
        } else {
          _showDebtDetails(d, isIOwe);
        }
      },
      onLongPress: _debtSelectMode
          ? null
          : () {
              if (key.isEmpty) return;
              setState(() {
                _debtSelectMode = true;
                _debtSelectedIds.add(key);
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
            if (_debtSelectMode) ...[
              SizedBox(
                width: 28,
                child: Checkbox(
                  value: selected,
                  onChanged: key.isEmpty
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _debtSelectedIds.add(key);
                            } else {
                              _debtSelectedIds.remove(key);
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (d['pendingSync'] == true) ...[
                  Tooltip(message: 'Pending upload', child: Icon(Icons.cloud_queue_rounded, size: 16, color: AppTheme.textDim.withValues(alpha: 0.85))),
                  const SizedBox(width: 6),
                ],
                Text('\$${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
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
    final isIOwe = d['debtType'] == 'iOwe';
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
              tileColor: AppTheme.surfaceLight,
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primary),
              title: const Text('Edit Entry', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _showEditDebtSheet(d, isIOwe); },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: AppTheme.accent.withValues(alpha: 0.08),
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accent),
              title: const Text('Delete Entry', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _confirmDelete(d); },
            ),
          ],
        ),
      ),
    );
  }

  int? _localSqliteId(Map<String, dynamic> d) {
    final id = d['id'];
    if (id is String && id.startsWith('local_')) {
      return int.tryParse(id.replaceFirst('local_', ''));
    }
    return null;
  }

  void _showEditDebtSheet(Map<String, dynamic> d, bool isIOwe) {
    final personCtrl = TextEditingController(text: d['person'] ?? '');
    final amountCtrl = TextEditingController(text: _safeConvertAmount(d['amount']).toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: d['notes']?.toString() ?? '');
    final color = isIOwe ? AppTheme.expense : AppTheme.income;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Center(child: Text('Edit ${isIOwe ? 'I Owe' : 'Owed to Me'}', style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w700))),
              const SizedBox(height: 20),
              TextField(
                controller: personCtrl,
                decoration: InputDecoration(labelText: 'Person', focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 1.5))),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount', prefixText: '\$ ', focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 1.5))),
              ),
              const SizedBox(height: 14),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final p = personCtrl.text.trim();
                    final a = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (p.isEmpty || a <= 0) return;

                    final messenger = ScaffoldMessenger.of(ctx);
                    Navigator.pop(ctx);

                    final localId = _localSqliteId(d);
                    try {
                      if (localId != null) {
                        await StorageService.updateLocalDebt(localId, person: p, amount: a, notes: noteCtrl.text);
                      } else if (await _firebaseService.isConnected) {
                        await _firebaseService.updateDebt(debtId: d['id'], person: p, amount: a, notes: noteCtrl.text);
                      }
                      if (mounted) {
                        messenger.showSnackBar(SnackBar(
                          content: const Text('Debt updated', style: TextStyle(fontSize: 12)),
                          backgroundColor: color, behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        _loadDebts();
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(SnackBar(
                          content: Text('Update failed: $e', style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppTheme.accent, behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> d) {
    final id = d['id'];
    if (id == null) return;
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Entry?', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              try {
                await _deleteDebtOne(d);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Debt deleted', style: TextStyle(fontSize: 12)),
                    backgroundColor: AppTheme.secondary, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                  _loadDebts();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Delete failed: $e', style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppTheme.accent, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
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
                    if (p.isEmpty || a <= 0) return;

                    final debtType = isIOwe ? 'iOwe' : 'owedToMe';
                    final now = DateTime.now();
                    final localPayload = {
                      'amount': a.toString(),
                      'person': p,
                      'notes': noteController.text,
                      'dueDate': null,
                      'createdAt': now.toIso8601String(),
                    };

                    // Capture messenger BEFORE popping (context dies after pop)
                    final messenger = ScaffoldMessenger.of(context);
                    if (context.mounted) Navigator.pop(context);

                    try {
                      if (await _firebaseService.isConnected) {
                        final localId = await StorageService.saveLocalDebt(debtType, localPayload);
                        await _firebaseService.addDebt(
                          type: debtType,
                          person: p,
                          amount: a,
                          notes: noteController.text,
                          localId: localId,
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Debt added', style: TextStyle(fontSize: 12)),
                              backgroundColor: isIOwe ? AppTheme.expense : AppTheme.income,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          _loadDebts();
                        }
                      } else {
                        await StorageService.saveLocalDebt(debtType, localPayload);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Saved offline — will sync when online', style: TextStyle(fontSize: 12)),
                              backgroundColor: AppTheme.secondary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          _loadDebts();
                        }
                      }
                    } catch (e) {
                      try {
                        await StorageService.saveLocalDebt(debtType, localPayload);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Saved offline — will sync when online', style: TextStyle(fontSize: 12)),
                              backgroundColor: AppTheme.secondary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          _loadDebts();
                        }
                      } catch (_) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to save: $e', style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppTheme.accent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
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




  @override
  void dispose() {
    _tabController.removeListener(_onDebtTabChanged);
    _tabController.dispose();
    _debtsSubscription?.cancel();
    super.dispose();
  }
}
