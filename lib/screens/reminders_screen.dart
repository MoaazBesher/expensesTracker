import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../utils/screen_utils.dart';
import 'package:intl/intl.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
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
      FirebaseService().getReminders().listen((reminders) {
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
      appBar: AppBar(toolbarHeight: 0),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _filteredReminders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _loadReminders(),
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: S.sectionPadding),
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
        child: const Icon(Icons.alarm_add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(S.sectionPadding, 12, S.sectionPadding, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: ['All', 'Today', 'Upcoming', 'Overdue'].map((label) {
          final value = label.toLowerCase();
          final isSelected = _selectedFilter == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { setState(() { _selectedFilter = value; _filterReminders(); }); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border),
                ),
                child: Text(label, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textDim, fontWeight: FontWeight.w600, fontSize: 12)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isOverdue ? AppTheme.accent : AppTheme.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isOverdue ? Icons.priority_high_rounded : Icons.notifications_active_rounded,
                    color: isOverdue ? AppTheme.accent : AppTheme.primary, size: 20),
        ),
        title: Text(r['title'] ?? 'Untitled', style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(DateFormat('MMM dd, yyyy • hh:mm a').format(date), style: TextStyle(color: isOverdue ? AppTheme.accent : AppTheme.textDim, fontSize: 11)),
            if (r['notes']?.isNotEmpty == true) Text(r['notes'], style: TextStyle(color: AppTheme.textDark, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.textDark, size: 20),
          onPressed: () => _confirmDelete(r['id']),
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
          TextButton(onPressed: () async { Navigator.pop(context); await FirebaseService().deleteReminder(id); },
            child: const Text('Delete', style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
  }
}
