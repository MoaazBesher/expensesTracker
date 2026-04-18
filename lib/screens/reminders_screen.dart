import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
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
        if (mounted) {
          setState(() {
            _reminders = reminders;
            _filterReminders();
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      final localReminders = await StorageService.getLocalReminders();
      if (mounted) {
        setState(() {
          _reminders = localReminders;
          _filterReminders();
          _isLoading = false;
        });
      }
    }
  }

  void _filterReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    setState(() {
      _filteredReminders = _reminders.where((reminder) {
        final reminderDate = DateTime.parse(reminder['date']);
        final reminderDay = DateTime(reminderDate.year, reminderDate.month, reminderDate.day);
        
        switch (_selectedFilter) {
          case 'today': return reminderDay == today;
          case 'upcoming': return reminderDay.isAfter(today);
          case 'overdue': return reminderDay.isBefore(today);
          default: return true;
        }
      }).toList()..sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Smart Alerts')),
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
                          padding: const EdgeInsets.symmetric(horizontal: 24),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Today', 'today'),
          _buildFilterChip('Upcoming', 'upcoming'),
          _buildFilterChip('Overdue', 'overdue'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () { setState(() { _selectedFilter = value; _filterReminders(); }); },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: isSelected 
            ? BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20))
            : AppTheme.glassDecoration(opacity: 0.05, radius: 20),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textDim, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> r) {
    final date = DateTime.parse(r['date']);
    final isOverdue = date.isBefore(DateTime.now());
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.glassDecoration(opacity: 0.03, radius: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isOverdue ? AppTheme.accent : AppTheme.primary).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(isOverdue ? Icons.priority_high_rounded : Icons.notifications_active_rounded, 
                    color: isOverdue ? AppTheme.accent : AppTheme.primary, size: 24),
        ),
        title: Text(r['title'] ?? 'Untitled', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(DateFormat('MMM dd, yyyy • hh:mm a').format(date), 
                 style: TextStyle(color: isOverdue ? AppTheme.accent : AppTheme.textDim, fontSize: 12)),
            if (r['notes']?.isNotEmpty == true) 
              Text(r['notes'], style: TextStyle(color: AppTheme.textDark, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.textDark),
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
          Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.textDim.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No alerts found', style: TextStyle(color: AppTheme.textDim, fontSize: 16)),
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
          decoration: AppTheme.glassDecoration(color: AppTheme.surfaceLight, opacity: 1),
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set New Alert', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Reminder Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                        if(d != null) setSheetState(() => _selectedDate = d);
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(_selectedTime.format(context)),
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: _selectedTime);
                        if(t != null) setSheetState(() => _selectedTime = t);
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: 'Extra Notes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty) {
                      final dt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
                      await FirebaseService().addReminder(title: titleController.text, date: dt, notes: noteController.text);
                      await StorageService.saveLocalReminder({
                        'title': titleController.text,
                        'date': dt.toIso8601String(),
                        'notes': noteController.text,
                        'createdAt': DateTime.now().toIso8601String(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Alert', style: TextStyle(fontWeight: FontWeight.bold)),
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
        backgroundColor: AppTheme.surfaceLight,
        title: const Text('Delete Alert?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            Navigator.pop(context);
            await FirebaseService().deleteReminder(id);
          }, child: const Text('Delete', style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
  }
}