import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';

class RemindersScreen extends StatefulWidget {
  @override
  _RemindersScreenState createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _filteredReminders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  // Form controllers and focus nodes
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _titleFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
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
        final reminderDateTime = DateTime(reminderDate.year, reminderDate.month, reminderDate.day);
        
        switch (_selectedFilter) {
          case 'today':
            return reminderDateTime == today;
          case 'upcoming':
            return reminderDateTime.isAfter(today);
          case 'overdue':
            return reminderDateTime.isBefore(today);
          default:
            return true;
        }
      }).toList()
      ..sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    });
  }

  void _showAddReminderSheet() {
    _titleController.clear();
    _notesController.clear();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddReminderSheet(),
    ).then((_) {
      // Clear focus when sheet is closed
      _titleFocusNode.unfocus();
      _notesFocusNode.unfocus();
    });
  }

  Widget _buildAddReminderSheet() {
    return AnimatedPadding(
      padding: MediaQuery.of(context).viewInsets,
      duration: Duration(milliseconds: 100),
      curve: Curves.decelerate,
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 35,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 15),
                
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      SizedBox(width: 24),
                      Expanded(
                        child: Text(
                          'Add Reminder',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                
                // Form Content with proper scrolling
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: _buildReminderForm(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildReminderForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title Field
        Container(
          height: 56,
          child: TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            decoration: InputDecoration(
              labelText: 'Title *',
              labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF6C63FF), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Color(0xFF0F172A).withOpacity(0.5),
            ),
            style: TextStyle(color: Colors.white, fontSize: 16),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              _titleFocusNode.unfocus();
              FocusScope.of(context).requestFocus(_notesFocusNode);
            },
          ),
        ),
        SizedBox(height: 16),
        
        // Date & Time Selection
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _titleFocusNode.unfocus();
                  _notesFocusNode.unfocus();
                  _selectDate();
                },
                child: Container(
                  height: 56,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(12),
                    color: Color(0xFF0F172A).withOpacity(0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Color(0xFF64748B), size: 20),
                      SizedBox(width: 12),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _titleFocusNode.unfocus();
                  _notesFocusNode.unfocus();
                  _selectTime();
                },
                child: Container(
                  height: 56,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(12),
                    color: Color(0xFF0F172A).withOpacity(0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Color(0xFF64748B), size: 20),
                      SizedBox(width: 12),
                      Text(
                        _selectedTime.format(context),
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        
        // Notes Field
        Container(
          constraints: BoxConstraints(minHeight: 56, maxHeight: 150),
          child: TextField(
            controller: _notesController,
            focusNode: _notesFocusNode,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF6C63FF), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Color(0xFF0F172A).withOpacity(0.5),
              alignLabelWithHint: true,
            ),
            style: TextStyle(color: Colors.white, fontSize: 16),
            textInputAction: TextInputAction.done,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            onSubmitted: (_) {
              _notesFocusNode.unfocus();
              _saveReminder();
            },
          ),
        ),
        SizedBox(height: 24),
        
        // Buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: TextButton(
                  onPressed: () {
                    _titleFocusNode.unfocus();
                    _notesFocusNode.unfocus();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Color(0xFF334155),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    _titleFocusNode.unfocus();
                    _notesFocusNode.unfocus();
                    _saveReminder();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Add Reminder',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
      ],
    );
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF1E293B),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF1E293B),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  void _saveReminder() async {
    final title = _titleController.text.trim();
    
    if (title.isEmpty) {
      _showError('Please enter a title');
      _titleFocusNode.requestFocus();
      return;
    }

    // Combine date and time
    final scheduledDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await FirebaseService().addReminder(
        title: title,
        date: scheduledDate,
        notes: _notesController.text.trim(),
      );

      await StorageService.saveLocalReminder({
        'title': title,
        'date': scheduledDate.toIso8601String(),
        'notes': _notesController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      Navigator.pop(context);
      _showSuccess('Reminder added successfully!');
      _loadReminders();

    } catch (e) {
      _showError('Failed to add reminder');
    }
  }

  Widget _buildReminderItem(Map<String, dynamic> reminder) {
    final date = DateTime.parse(reminder['date']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(date.year, date.month, date.day);
    
    String status = 'upcoming';
    Color statusColor = Color(0xFF6C63FF);
    String statusText = 'Upcoming';
    
    if (reminderDate.isBefore(today)) {
      status = 'overdue';
      statusColor = Color(0xFFF87171);
      statusText = 'Overdue';
    } else if (reminderDate == today) {
      status = 'today';
      statusColor = Color(0xFFFBBF24);
      statusText = 'Today';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getReminderIcon(status),
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          reminder['title'],
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '${_formatDate(date)} • ${_formatTime(date)}',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
            if (reminder['notes']?.isNotEmpty == true) ...[
              SizedBox(height: 4),
              Text(
                reminder['notes'],
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              _getDaysText(date),
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
              ),
            ),
          ],
        ),
        onLongPress: () => _showDeleteDialog(reminder),
      ),
    );
  }

  IconData _getReminderIcon(String status) {
    switch (status) {
      case 'today':
        return Icons.today;
      case 'overdue':
        return Icons.warning;
      default:
        return Icons.schedule;
    }
  }

  String _getDaysText(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays > 0) {
      return 'in ${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  SizedBox(width: 8),
                  _buildFilterChip('Today', 'today'),
                  SizedBox(width: 8),
                  _buildFilterChip('Upcoming', 'upcoming'),
                  SizedBox(width: 8),
                  _buildFilterChip('Overdue', 'overdue'),
                ],
              ),
            ),
          ),
          
          // Reminders List
          Expanded(
            child: _isLoading 
                ? Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF),
                      strokeWidth: 2,
                    ),
                  )
                : _filteredReminders.isEmpty 
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _loadReminders(),
                        backgroundColor: Color(0xFF1E293B),
                        color: Color(0xFF6C63FF),
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredReminders.length,
                          itemBuilder: (context, index) => _buildReminderItem(_filteredReminders[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderSheet,
        backgroundColor: Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        child: Icon(Icons.add, size: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
          _filterReminders();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF6C63FF) : Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF6C63FF) : Color(0xFF334155),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Color(0xFF6C63FF).withOpacity(0.4),
            ),
            SizedBox(height: 16),
            Text(
              _getEmptyStateText(),
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _getEmptyStateSubtitle(),
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyStateText() {
    switch (_selectedFilter) {
      case 'today':
        return 'No Reminders Today';
      case 'upcoming':
        return 'No Upcoming Reminders';
      case 'overdue':
        return 'No Overdue Reminders';
      default:
        return 'No Reminders Yet';
    }
  }

  String _getEmptyStateSubtitle() {
    switch (_selectedFilter) {
      case 'today':
        return 'Add a reminder for today';
      case 'upcoming':
        return 'Add reminders for future dates';
      case 'overdue':
        return 'All your reminders are up to date!';
      default:
        return 'Add your first reminder to get started';
    }
  }

  void _showDeleteDialog(Map<String, dynamic> reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Reminder',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this reminder?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel', 
              style: TextStyle(color: Color(0xFF6C63FF), fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              _deleteReminder(reminder);
              Navigator.pop(context);
            },
            child: Text(
              'Delete', 
              style: TextStyle(color: Color(0xFFF87171), fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteReminder(Map<String, dynamic> reminder) async {
    try {
      await FirebaseService().deleteReminder(reminder['id']);
      _showSuccess('Reminder deleted successfully');
      _loadReminders();
    } catch (e) {
      _showError('Failed to delete reminder');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFF87171),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFF2DD4BF),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final tomorrow = today.add(Duration(days: 1));
    
    final reminderDate = DateTime(date.year, date.month, date.day);
    
    if (reminderDate == today) return 'Today';
    if (reminderDate == yesterday) return 'Yesterday';
    if (reminderDate == tomorrow) return 'Tomorrow';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}