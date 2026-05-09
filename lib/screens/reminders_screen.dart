import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';
import 'package:intl/intl.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => RemindersScreenState();
}

class RemindersScreenState extends State<RemindersScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _filteredReminders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      _firebaseService.getReminders().listen((reminders) {
        if (mounted) setState(() { _reminders = reminders; _filterReminders(); _isLoading = false; });
      });
    } catch (e) {
      final local = await StorageService.getLocalReminders();
      if (mounted) setState(() { _reminders = local; _filterReminders(); _isLoading = false; });
    }
  }

  void _filterReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _filteredReminders = _reminders.where((r) {
        final d = DateTime.parse(r['date']);
        final rd = DateTime(d.year, d.month, d.day);
        switch (_selectedFilter) {
          case 'today': return rd == today;
          case 'upcoming': return rd.isAfter(today);
          case 'overdue': return rd.isBefore(today);
          default: return true;
        }
      }).toList()..sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    });
  }

  @override
  Widget build(BuildContext context) {
    S.init(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                : _filteredReminders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _loadReminders(),
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.surface,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _filteredReminders.length,
                          itemBuilder: (context, index) => _buildReminderItem(_filteredReminders[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderSheet,
        backgroundColor: AppTheme.primary,
        elevation: 4,
        child: const Icon(Icons.alarm_add_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: ['All', 'Today', 'Upcoming', 'Overdue'].map((label) {
            final value = label.toLowerCase();
            final isSelected = _selectedFilter == value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () { setState(() { _selectedFilter = value; _filterReminders(); }); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.textDim,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> r) {
    final date = DateTime.parse(r['date']);
    final isOverdue = date.isBefore(DateTime.now());
    final color = isOverdue ? AppTheme.accent : AppTheme.primary;
    return GestureDetector(
      onTap: () => _showReminderDetails(r),
      onLongPress: () => _showReminderActions(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppTheme.cardDecoration(radius: 12),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(isOverdue ? Icons.priority_high_rounded : Icons.notifications_active_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['title'] ?? 'Untitled', style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(DateFormat('MMM dd, yyyy  •  hh:mm a').format(date), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
                  if (r['notes']?.isNotEmpty == true) ...[  
                    const SizedBox(height: 2),
                    Text(r['notes'], style: const TextStyle(color: AppTheme.textDim, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textDark, size: 18),
          ],
        ),
      ),
    );
  }

  void _showReminderDetails(Map<String, dynamic> r) {
    final date = DateTime.parse(r['date']);
    final isOverdue = date.isBefore(DateTime.now());
    final color = isOverdue ? AppTheme.accent : AppTheme.primary;
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
              child: Icon(isOverdue ? Icons.priority_high_rounded : Icons.notifications_active_rounded, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(r['title'] ?? 'Untitled', style: const TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(isOverdue ? 'Overdue' : 'Upcoming', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.calendar_today_rounded, 'Date & Time', DateFormat('EEE, MMM dd yyyy  •  hh:mm a').format(date)),
            if ((r['notes'] ?? '').toString().isNotEmpty)
              _detailRow(Icons.notes_rounded, 'Notes', r['notes'].toString()),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(ctx); _showReminderActions(r); },
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.textDim),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          const Spacer(),
          Flexible(child: Text(value, style: const TextStyle(color: AppTheme.textMain, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  void _showReminderActions(Map<String, dynamic> r) {
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
            Text(r['title'] ?? 'Alert', style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: AppTheme.surfaceLight,
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primary),
              title: const Text('Edit Alert', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _showEditReminderSheet(r); },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: AppTheme.accent.withValues(alpha: 0.08),
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accent),
              title: const Text('Delete Alert', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(ctx); _confirmDelete(r['id']); },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditReminderSheet(Map<String, dynamic> r) {
    final titleCtrl = TextEditingController(text: r['title']?.toString() ?? '');
    final noteCtrl = TextEditingController(text: r['notes']?.toString() ?? '');
    DateTime pickedDate = DateTime.parse(r['date']);
    TimeOfDay pickedTime = TimeOfDay(hour: pickedDate.hour, minute: pickedDate.minute);

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
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Edit Alert', style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded, size: 16),
                        label: Text(DateFormat('MMM dd, yyyy').format(pickedDate), style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final d = await showDatePicker(context: ctx, initialDate: pickedDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime(2100));
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
                          final t = await showTimePicker(context: ctx, initialTime: pickedTime);
                          if (t != null) setSheet(() { pickedTime = t; pickedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, t.hour, t.minute); });
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMain, side: const BorderSide(color: AppTheme.border), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      await FirebaseService().updateReminder(
                        reminderId: r['id'],
                        title: titleCtrl.text.trim(),
                        date: pickedDate,
                        notes: noteCtrl.text,
                      );
                      if (mounted) _loadReminders();
                    },
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
          Icon(Icons.notifications_none_rounded, size: 48, color: AppTheme.textDim.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('No alerts', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontBody)),
        ],
      ),
    );
  }

  void showAddSheet() {
    _showAddReminderSheet();
  }

  void _showAddReminderSheet() {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
                const Text('New Alert', style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate), style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                          if (d != null) setSheetState(() => _selectedDate = d);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textMain,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(_selectedTime.format(context), style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: _selectedTime);
                          if (t != null) setSheetState(() => _selectedTime = t);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textMain,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
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
                      if (titleController.text.isNotEmpty) {
                        final dt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
                        await FirebaseService().addReminder(title: titleController.text, date: dt, notes: noteController.text);
                        await StorageService.saveLocalReminder({
                          'title': titleController.text, 'date': dt.toIso8601String(), 'notes': noteController.text,
                          'createdAt': DateTime.now().toIso8601String(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text('Create Alert'),
                  ),
                ),
              ],
            ),
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
        title: const Text('Delete Alert?', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () async { Navigator.pop(context); await _firebaseService.deleteReminder(id); },
            child: const Text('Delete', style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
  }
}
