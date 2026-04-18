import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

class MonthlyBillsScreen extends StatefulWidget {
  @override
  _MonthlyBillsScreenState createState() => _MonthlyBillsScreenState();
}

class _MonthlyBillsScreenState extends State<MonthlyBillsScreen> {
  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;
  
  // Filters
  String _searchQuery = '';
  String _selectedType = 'all';
  String _selectedCategory = 'all';
  double _minAmount = 0.0;
  double _maxAmount = 10000.0;
  
  // Summary data
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _netSavings = 0.0;
  Map<String, double> _categoryBreakdown = {};
  
  // Form controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
    _minAmountController.text = _minAmount.toStringAsFixed(2);
    _maxAmountController.text = _maxAmount.toStringAsFixed(2);
  }

  void _loadMonthlyData() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      FirebaseService().getMonthlyTransactions(_selectedMonth).listen((transactions) {
        if (mounted) {
          setState(() {
            _transactions = transactions;
            _calculateSummary();
            _applyFilters();
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print('Online load failed: $e');
      final localTransactions = await StorageService.getLocalTransactions(_selectedMonth);
      if (mounted) {
        setState(() {
          _transactions = localTransactions;
          _calculateSummary();
          _applyFilters();
          _isLoading = false;
        });
      }
    }
  }

  void _calculateSummary() {
    double income = 0.0;
    double expenses = 0.0;
    Map<String, double> categoryMap = {};

    for (final transaction in _transactions) {
      final amount = _safeConvertAmount(transaction['amount']);
      final category = transaction['category']?.toString() ?? 'Unknown';
      final type = transaction['type']?.toString() ?? 'expense';

      if (type == 'income') {
        income += amount;
      } else {
        expenses += amount;
      }

      // Category breakdown for expenses only
      if (type == 'expense') {
        categoryMap.update(
          category,
          (value) => value + amount,
          ifAbsent: () => amount
        );
      }
    }

    setState(() {
      _totalIncome = income;
      _totalExpenses = expenses;
      _netSavings = income - expenses;
      _categoryBreakdown = categoryMap;
    });
  }

  void _applyFilters() {
    if (!mounted) return;
    
    setState(() {
      _filteredTransactions = _transactions.where((transaction) {
        final matchesSearch = _searchQuery.isEmpty || 
            transaction['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (transaction['note']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        final matchesType = _selectedType == 'all' || 
            transaction['type'] == _selectedType;
        
        final amount = _safeConvertAmount(transaction['amount']);
        final matchesAmount = amount >= _minAmount && amount <= _maxAmount;
        
        final matchesCategory = _selectedCategory == 'all' || 
            transaction['category']?.toString() == _selectedCategory;
        
        return matchesSearch && matchesType && matchesAmount && matchesCategory;
      }).toList()
      ..sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA); // Newest first
      });
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Filter Transactions',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type Filter
                  _buildFilterSection(
                    'Transaction Type',
                    DropdownButton<String>(
                      value: _selectedType,
                      icon: Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      isExpanded: true,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      dropdownColor: Color(0xFF1E293B),
                      onChanged: (String? newValue) {
                        setState(() => _selectedType = newValue!);
                      },
                      items: ['all', 'income', 'expense'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value == 'all' ? 'All Types' : 
                            value == 'income' ? 'Income Only' : 'Expenses Only',
                            style: TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Category Filter
                  _buildFilterSection(
                    'Category',
                    DropdownButton<String>(
                      value: _selectedCategory,
                      icon: Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      isExpanded: true,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      dropdownColor: Color(0xFF1E293B),
                      onChanged: (String? newValue) {
                        setState(() => _selectedCategory = newValue!);
                      },
                      items: _getCategoryList(),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Amount Range
                  _buildFilterSection(
                    'Amount Range',
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _minAmountController,
                                decoration: InputDecoration(
                                  labelText: 'Min',
                                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Color(0xFF334155)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Color(0xFF6C63FF)),
                                  ),
                                ),
                                style: TextStyle(color: Colors.white),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  setState(() => _minAmount = double.tryParse(value) ?? 0.0);
                                },
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _maxAmountController,
                                decoration: InputDecoration(
                                  labelText: 'Max',
                                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Color(0xFF334155)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Color(0xFF6C63FF)),
                                  ),
                                ),
                                style: TextStyle(color: Colors.white),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  setState(() => _maxAmount = double.tryParse(value) ?? 10000.0);
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Range: \$${_minAmount.toStringAsFixed(2)} - \$${_maxAmount.toStringAsFixed(2)}',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetFilters();
                },
                child: Text(
                  'Reset All',
                  style: TextStyle(color: Color(0xFFF87171), fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _applyFilters();
                },
                child: Text(
                  'Apply Filters',
                  style: TextStyle(color: Color(0xFF6C63FF), fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<DropdownMenuItem<String>> _getCategoryList() {
    final categories = <String>{'all'};
    
    for (final transaction in _transactions) {
      final category = transaction['category']?.toString();
      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
    }
    
    return categories.toList().map((category) {
      return DropdownMenuItem<String>(
        value: category,
        child: Text(
          category == 'all' ? 'All Categories' : category,
          style: TextStyle(fontSize: 14),
        ),
      );
    }).toList();
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        child,
      ],
    );
  }

  void _resetFilters() {
    if (!mounted) return;
    
    setState(() {
      _searchQuery = '';
      _selectedType = 'all';
      _selectedCategory = 'all';
      _minAmount = 0.0;
      _maxAmount = 10000.0;
      _searchController.clear();
      _minAmountController.text = _minAmount.toStringAsFixed(2);
      _maxAmountController.text = _maxAmount.toStringAsFixed(2);
    });
    _applyFilters();
  }

  void _showMonthPicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    ).then((pickedDate) {
      if (pickedDate != null && pickedDate != _selectedMonth) {
        setState(() => _selectedMonth = pickedDate);
        _loadMonthlyData();
      }
    });
  }

  void _shareReport() {
    // Simple share functionality - you can enhance this later
    final reportText = '''
Monthly Financial Report - ${DateFormat('MMMM yyyy').format(_selectedMonth)}

Income: \$${_totalIncome.toStringAsFixed(2)}
Expenses: \$${_totalExpenses.toStringAsFixed(2)}
Net Savings: \$${_netSavings.toStringAsFixed(2)}

Transactions: ${_filteredTransactions.length}
''';

    _showSuccess('Report ready to share!\n\n$reportText');
  }

  double _safeConvertAmount(dynamic amountValue) {
    if (amountValue == null) return 0.0;
    if (amountValue is int) return amountValue.toDouble();
    if (amountValue is double) return amountValue;
    if (amountValue is String) return double.tryParse(amountValue) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Column(
        children: [
          // Header with Month Selection
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFF1E293B),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: Color(0xFF6C63FF), size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                      _loadMonthlyData();
                    });
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _showMonthPicker,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: Color(0xFF6C63FF), size: 18),
                          SizedBox(width: 8),
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, color: Color(0xFF6C63FF), size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                      _loadMonthlyData();
                    });
                  },
                ),
              ],
            ),
          ),

          // Summary Cards
          _buildSummaryCards(),

          // Search and Filter Bar
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        _applyFilters();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Color(0xFF64748B), size: 16),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.filter_list, color: Color(0xFF6C63FF), size: 18),
                    onPressed: _showFilterDialog,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.share, color: Color(0xFF2DD4BF), size: 18),
                    onPressed: _shareReport,
                  ),
                ),
              ],
            ),
          ),

          // Active Filters
          _buildActiveFilters(),

          // Transactions List
          Expanded(
            child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _filteredTransactions.isEmpty 
                    ? _buildEmptyState()
                    : _buildTransactionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Income',
              _totalIncome,
              Color(0xFF2DD4BF),
              Icons.arrow_upward,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Expenses',
              _totalExpenses,
              Color(0xFFF87171),
              Icons.arrow_downward,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Savings',
              _netSavings,
              _netSavings >= 0 ? Color(0xFFFBBF24) : Color(0xFFF87171),
              Icons.savings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    final activeFilters = <String>[];
    
    if (_selectedType != 'all') activeFilters.add(_selectedType);
    if (_selectedCategory != 'all') activeFilters.add(_selectedCategory);
    if (_minAmount > 0 || _maxAmount < 10000) activeFilters.add('Amount Range');
    if (_searchQuery.isNotEmpty) activeFilters.add('Search');

    if (activeFilters.isEmpty) return SizedBox();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          Text(
            'Active Filters:',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
          ),
          ...activeFilters.map((filter) => Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              filter,
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          )).toList(),
          GestureDetector(
            onTap: _resetFilters,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFFF87171).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: Color(0xFFF87171),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Transactions (${_filteredTransactions.length})',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Text(
                'Total: \$${_filteredTransactions.fold(0.0, (sum, transaction) {
                  final amount = _safeConvertAmount(transaction['amount']);
                  return transaction['type'] == 'income' ? sum + amount : sum - amount;
                }).toStringAsFixed(2)}',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _filteredTransactions.length,
            itemBuilder: (context, index) => _buildTransactionItem(_filteredTransactions[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isIncome = transaction['type'] == 'income';
    final amount = _safeConvertAmount(transaction['amount']);
    final date = DateTime.parse(transaction['date']);
    
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isIncome 
                ? Color(0xFF2DD4BF).withOpacity(0.2)
                : Color(0xFFF87171).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isIncome ? Icons.arrow_upward : Icons.arrow_downward,
            color: isIncome ? Color(0xFF2DD4BF) : Color(0xFFF87171),
            size: 16,
          ),
        ),
        title: Text(
          transaction['category']?.toString() ?? 'Unknown',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          '${_formatDate(date)} • ${transaction['note']?.toString() ?? 'No description'}',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isIncome ? Color(0xFF2DD4BF) : Color(0xFFF87171),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 2),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isIncome 
                    ? Color(0xFF2DD4BF).withOpacity(0.2)
                    : Color(0xFFF87171).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isIncome ? 'IN' : 'OUT',
                style: TextStyle(
                  color: isIncome ? Color(0xFF2DD4BF) : Color(0xFFF87171),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Color(0xFF6C63FF).withOpacity(0.4),
            ),
            SizedBox(height: 16),
            Text(
              'No Transactions Found',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your filters or select a different month',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              child: Text('Reset Filters'),
            ),
          ],
        ),
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
        duration: Duration(seconds: 4),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }
}