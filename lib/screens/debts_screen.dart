// screens/debts_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/firebase_service.dart';

class DebtsScreen extends StatefulWidget {
  @override
  _DebtsScreenState createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _consolidatedDebts = {};
  List<Map<String, dynamic>> _ioweList = [];
  List<Map<String, dynamic>> _owedToMeList = [];
  List<Map<String, dynamic>> _filteredIOweList = [];
  List<Map<String, dynamic>> _filteredOwedToMeList = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  StreamSubscription? _debtsSubscription;

  // Search and filter
  String _searchQuery = '';
  String _selectedPerson = 'all';
  List<String> _allPersons = [];

  // Form controllers
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() async {
    await _loadDebts();
  }

  Future<void> _loadDebts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      _debtsSubscription?.cancel();
      
      _debtsSubscription = FirebaseService().getDebts().listen(
        (debts) {
          if (mounted) {
            setState(() {
              try {
                _processDebtsData(debts);
                _isLoading = false;
                _hasError = false;
                _updateAllPersonsList();
                _filterDebts();
              } catch (e) {
                _handleDataError('Error processing debts data: $e');
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            _handleDataError('Failed to load debts: $error');
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      _handleDataError('Error setting up debts listener: $e');
    }
  }

  void _processDebtsData(Map<String, dynamic> debts) {
    try {
      // Handle iOwe data safely
      final iOweData = debts['iOwe'];
      if (iOweData is List) {
        _ioweList = _convertToListOfMaps(iOweData);
        // Sort by date (newest first)
        _ioweList.sort((a, b) {
          final dateA = DateTime.parse(a['createdAt'] ?? '2000-01-01');
          final dateB = DateTime.parse(b['createdAt'] ?? '2000-01-01');
          return dateB.compareTo(dateA);
        });
      } else {
        _ioweList = [];
      }

      // Handle owedToMe data safely
      final owedToMeData = debts['owedToMe'];
      if (owedToMeData is List) {
        _owedToMeList = _convertToListOfMaps(owedToMeData);
        // Sort by date (newest first)
        _owedToMeList.sort((a, b) {
          final dateA = DateTime.parse(a['createdAt'] ?? '2000-01-01');
          final dateB = DateTime.parse(b['createdAt'] ?? '2000-01-01');
          return dateB.compareTo(dateA);
        });
      } else {
        _owedToMeList = [];
      }

      _calculateConsolidatedDebts();
    } catch (e) {
      throw Exception('Data processing error: $e');
    }
  }

  void _updateAllPersonsList() {
    final allPersons = <String>{};
    
    // Add persons from iOwe
    for (final debt in _ioweList) {
      final person = debt['person']?.toString() ?? 'Unknown';
      if (person.isNotEmpty) {
        allPersons.add(person);
      }
    }
    
    // Add persons from owedToMe
    for (final debt in _owedToMeList) {
      final person = debt['person']?.toString() ?? 'Unknown';
      if (person.isNotEmpty) {
        allPersons.add(person);
      }
    }
    
    _allPersons = ['all', ...allPersons.toList()..sort()];
  }

  void _filterDebts() {
    // Filter I Owe list
    _filteredIOweList = _ioweList.where((debt) {
      final person = debt['person']?.toString().toLowerCase() ?? '';
      final notes = debt['notes']?.toString().toLowerCase() ?? '';
      final amount = debt['amount']?.toString() ?? '';
      
      final matchesSearch = _searchQuery.isEmpty || 
          person.contains(_searchQuery.toLowerCase()) ||
          notes.contains(_searchQuery.toLowerCase()) ||
          amount.contains(_searchQuery);
      
      final matchesPerson = _selectedPerson == 'all' || 
          debt['person']?.toString() == _selectedPerson;
      
      return matchesSearch && matchesPerson;
    }).toList();

    // Filter Owed to Me list
    _filteredOwedToMeList = _owedToMeList.where((debt) {
      final person = debt['person']?.toString().toLowerCase() ?? '';
      final notes = debt['notes']?.toString().toLowerCase() ?? '';
      final amount = debt['amount']?.toString() ?? '';
      
      final matchesSearch = _searchQuery.isEmpty || 
          person.contains(_searchQuery.toLowerCase()) ||
          notes.contains(_searchQuery.toLowerCase()) ||
          amount.contains(_searchQuery);
      
      final matchesPerson = _selectedPerson == 'all' || 
          debt['person']?.toString() == _selectedPerson;
      
      return matchesSearch && matchesPerson;
    }).toList();
  }

  List<Map<String, dynamic>> _convertToListOfMaps(List<dynamic> data) {
    final List<Map<String, dynamic>> result = [];
    
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        result.add(item);
      } else if (item is Map) {
        final convertedMap = <String, dynamic>{};
        item.forEach((key, value) {
          convertedMap[key.toString()] = value;
        });
        result.add(convertedMap);
      }
    }
    
    return result;
  }

  void _handleDataError(String error) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = error;
        _ioweList = [];
        _owedToMeList = [];
        _filteredIOweList = [];
        _filteredOwedToMeList = [];
        _consolidatedDebts = {};
        _allPersons = ['all'];
      });
    }
    print('Debts Screen Error: $error');
  }

  void _calculateConsolidatedDebts() {
    try {
      Map<String, double> personBalances = {};

      for (final debt in _ioweList) {
        final person = debt['person']?.toString() ?? 'Unknown';
        final amount = _safeConvertAmount(debt['amount']);
        personBalances.update(person, (value) => value - amount, ifAbsent: () => -amount);
      }

      for (final debt in _owedToMeList) {
        final person = debt['person']?.toString() ?? 'Unknown';
        final amount = _safeConvertAmount(debt['amount']);
        personBalances.update(person, (value) => value + amount, ifAbsent: () => amount);
      }

      _consolidatedDebts = {};
      personBalances.forEach((person, balance) {
        _consolidatedDebts[person] = {
          'balance': balance,
          'status': balance > 0 ? 'owed_to_me' : balance < 0 ? 'i_owe' : 'settled',
          'absoluteAmount': balance.abs(),
        };
      });
    } catch (e) {
      print('Error calculating consolidated debts: $e');
      _consolidatedDebts = {};
    }
  }

  double _safeConvertAmount(dynamic amount) {
    try {
      if (amount == null) return 0.0;
      if (amount is int) return amount.toDouble();
      if (amount is double) return amount;
      if (amount is String) return double.tryParse(amount) ?? 0.0;
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Search and Filter Widget
  Widget _buildSearchFilterBar() {
    return Container(
      padding: EdgeInsets.all(12),
      color: Color(0xFF0F172A),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterDebts();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by person, amount, or notes...',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Color(0xFF64748B), size: 16),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          SizedBox(height: 8),
          
          // Person Filter
          Row(
            children: [
              Text(
                'Filter by:',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 32,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPerson,
                      icon: Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
                      isExpanded: true,
                      style: TextStyle(color: Colors.white, fontSize: 11),
                      dropdownColor: Color(0xFF1E293B),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPerson = newValue ?? 'all';
                          _filterDebts();
                        });
                      },
                      items: _allPersons.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value == 'all' ? 'All Persons' : value,
                            style: TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Clear Filters Button
              if (_searchQuery.isNotEmpty || _selectedPerson != 'all')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedPerson = 'all';
                      _filterDebts();
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDebtMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildAddDebtMenu(),
    );
  }

  Widget _buildAddDebtMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 3,
                decoration: BoxDecoration(
                  color: Color(0xFF64748B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Add Debt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAddOption(Icons.arrow_upward, 'I Owe', Color(0xFFF87171), true),
                  _buildAddOption(Icons.arrow_downward, 'Owed to Me', Color(0xFF2DD4BF), false),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String label, Color color, bool isIOwe) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showAddDebtSheet(isIOwe);
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDebtSheet(bool isIOwe) {
    _personController.clear();
    _amountController.clear();
    _notesController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddDebtSheet(isIOwe),
    );
  }

  Widget _buildAddDebtSheet(bool isIOwe) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 30,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          'Add ${isIOwe ? 'I Owe' : 'Owed to Me'}',
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
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  
                  // Person Field
                  TextField(
                    controller: _personController,
                    decoration: InputDecoration(
                      labelText: 'Person *',
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
                        borderSide: BorderSide(color: Color(0xFF6C63FF)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16),
                  
                  // Amount Field
                  TextField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount *',
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
                        borderSide: BorderSide(color: Color(0xFF6C63FF)),
                      ),
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(color: Colors.white, fontSize: 16),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 16),
                  
                  // Notes Field
                  TextField(
                    controller: _notesController,
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
                        borderSide: BorderSide(color: Color(0xFF6C63FF)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                  ),
                  SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Color(0xFF334155),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Cancel', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _saveDebt(isIOwe),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isIOwe ? Color(0xFFF87171) : Color(0xFF2DD4BF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Add',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveDebt(bool isIOwe) async {
    final personText = _personController.text.trim();
    final amountText = _amountController.text.trim();
    final notesText = _notesController.text.trim();

    if (personText.isEmpty) {
      _showError('Please enter person name');
      return;
    }

    if (amountText.isEmpty) {
      _showError('Please enter amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    try {
      await FirebaseService().addDebt(
        type: isIOwe ? 'iOwe' : 'owedToMe',
        person: personText,
        amount: amount,
        notes: notesText,
      );

      Navigator.pop(context);
      _showSuccess('Debt added successfully!');

    } catch (e) {
      _showError('Failed to add debt: $e');
    }
  }

  void _deleteFromIOwe(int index) async {
    if (index < 0 || index >= _ioweList.length) return;

    final debtToDelete = _ioweList[index];
    final person = debtToDelete['person']?.toString() ?? 'Unknown';
    final amount = _safeConvertAmount(debtToDelete['amount']);
    final debtId = debtToDelete['id']?.toString() ?? index.toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1E293B),
          title: Text(
            'Delete Debt',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Text(
            'Are you sure you want to delete the debt of \$${amount.toStringAsFixed(2)} for $person?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 16)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseService().deleteDebt('iOwe', debtId);
                  _showSuccess('Debt deleted successfully');
                } catch (e) {
                  _showError('Error deleting debt: $e');
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _deleteFromOwedToMe(int index) async {
    if (index < 0 || index >= _owedToMeList.length) return;

    final debtToDelete = _owedToMeList[index];
    final person = debtToDelete['person']?.toString() ?? 'Unknown';
    final amount = _safeConvertAmount(debtToDelete['amount']);
    final debtId = debtToDelete['id']?.toString() ?? index.toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1E293B),
          title: Text(
            'Delete Debt',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Text(
            'Are you sure you want to delete the debt of \$${amount.toStringAsFixed(2)} from $person?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 16)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseService().deleteDebt('owedToMe', debtId);
                  _showSuccess('Debt deleted successfully');
                } catch (e) {
                  _showError('Error deleting debt: $e');
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(fontSize: 16)),
          backgroundColor: Color(0xFFF87171),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(fontSize: 16)),
          backgroundColor: Color(0xFF2DD4BF),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Color(0xFF6C63FF),
          labelColor: Color(0xFF6C63FF),
          unselectedLabelColor: Color(0xFF64748B),
          labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: 'Summary'),
            Tab(text: 'I Owe'),
            Tab(text: 'Owed to Me'),
          ],
        ),
      ),
      body: _hasError
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildIOweTab(),
                _buildOwedToMeTab(),
              ],
            ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 16),
        child: FloatingActionButton(
          onPressed: _showAddDebtMenu,
          backgroundColor: Color(0xFF6C63FF),
          child: Icon(Icons.add, color: Colors.white, size: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFF87171),
            ),
            SizedBox(height: 16),
            Text(
              'Error Loading Debts',
              style: TextStyle(
                color: Color(0xFFF87171),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDebts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Retry', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }

    final List<MapEntry<String, dynamic>> sortedDebts = 
        _consolidatedDebts.entries.toList()
          ..sort((a, b) {
            final aAmount = (a.value['absoluteAmount'] as double? ?? 0.0);
            final bAmount = (b.value['absoluteAmount'] as double? ?? 0.0);
            return bAmount.compareTo(aAmount);
          });

    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Balance',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _calculateNetBalance(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: sortedDebts.isEmpty
              ? _buildEmptyState('No Debts', 'Add your first debt to see the summary')
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: sortedDebts.length,
                  itemBuilder: (context, index) {
                    final entry = sortedDebts[index];
                    final person = entry.key;
                    final data = entry.value;
                    final balance = data['balance'] as double? ?? 0.0;
                    final status = data['status'] as String? ?? 'settled';
                    
                    return _buildConsolidatedDebtItem(person, balance, status);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConsolidatedDebtItem(String person, double balance, String status) {
    final bool isPositive = balance > 0;
    final bool isSettled = balance == 0;
    
    Color color = isSettled ? Color(0xFF94A3B8) : 
                 isPositive ? Color(0xFF2DD4BF) : Color(0xFFF87171);
    
    String statusText = isSettled ? 'SETTLED' : 
                       isPositive ? 'OWES YOU' : 'YOU OWE';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isSettled ? Icons.check_circle : 
            isPositive ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          person,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? '+' : isSettled ? '' : '-'}\$${balance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            if (!isSettled) Text(
              isPositive ? 'They owe you' : 'You owe them',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOweTab() {
    return _buildDebtList(_filteredIOweList, true);
  }

  Widget _buildOwedToMeTab() {
    return _buildDebtList(_filteredOwedToMeList, false);
  }

  Widget _buildDebtList(List<Map<String, dynamic>> debts, bool isIOwe) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }

    return Column(
      children: [
        _buildSearchFilterBar(),
        Expanded(
          child: debts.isEmpty
              ? _buildEmptyState(
                  isIOwe ? 'No Debts' : 'No Money Owed',
                  isIOwe ? 'You don\'t owe anyone' : 'No one owes you money'
                )
              : ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: debts.length,
                  itemBuilder: (context, index) {
                    final debt = debts[index];
                    return GestureDetector(
                      onLongPress: () {
                        if (isIOwe) {
                          _deleteFromIOwe(_ioweList.indexOf(debt));
                        } else {
                          _deleteFromOwedToMe(_owedToMeList.indexOf(debt));
                        }
                      },
                      child: _buildDebtItem(debt, isIOwe),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDebtItem(Map<String, dynamic> debt, bool isIOwe) {
    final amount = _safeConvertAmount(debt['amount']);
    final person = debt['person']?.toString() ?? 'Unknown';
    final createdAt = debt['createdAt'] != null 
        ? DateTime.parse(debt['createdAt'])
        : DateTime.now();
    
    return Container(
      margin: EdgeInsets.only(bottom: 8, left: 8, right: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isIOwe ? Color(0xFFF87171).withOpacity(0.2) 
                         : Color(0xFF2DD4BF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isIOwe ? Icons.arrow_upward : Icons.arrow_downward,
            color: isIOwe ? Color(0xFFF87171) : Color(0xFF2DD4BF),
            size: 20,
          ),
        ),
        title: Text(
          person,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (debt['notes']?.toString().isNotEmpty == true) ...[
              Text(
                debt['notes'].toString(),
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 2),
            Text(
              _formatDate(createdAt),
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIOwe ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isIOwe ? Color(0xFFF87171) : Color(0xFF2DD4BF),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 2),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isIOwe ? Color(0xFFF87171).withOpacity(0.2) 
                             : Color(0xFF2DD4BF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isIOwe ? 'YOU OWE' : 'OWES YOU',
                style: TextStyle(
                  color: isIOwe ? Color(0xFFF87171) : Color(0xFF2DD4BF),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _calculateNetBalance() {
    try {
      double totalIOwe = _ioweList.fold(0.0, (sum, debt) => sum + _safeConvertAmount(debt['amount']));
      double totalOwedToMe = _owedToMeList.fold(0.0, (sum, debt) => sum + _safeConvertAmount(debt['amount']));
      double net = totalOwedToMe - totalIOwe;
      
      return '${net >= 0 ? '+' : '-'}\$${net.abs().toStringAsFixed(2)}';
    } catch (e) {
      return '\$0.00';
    }
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              size: 64,
              color: Color(0xFF6C63FF).withOpacity(0.4),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
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

  @override
  void dispose() {
    _debtsSubscription?.cancel();
    _personController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}