import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';

class TransactionsScreen extends StatefulWidget {
  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _currentMonth = DateTime.now();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  String _searchQuery = '';
  String _selectedType = 'all';
  bool _isLoading = true;

  // Form controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
  }

  void _loadTransactions() async {
    setState(() => _isLoading = true);
    
    try {
      FirebaseService().getMonthlyTransactions(_currentMonth).listen((transactions) {
        if (mounted) {
          setState(() {
            _transactions = transactions;
            _filterTransactions();
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      final localTransactions = await StorageService.getLocalTransactions(_currentMonth);
      if (mounted) {
        setState(() {
          _transactions = localTransactions;
          _filterTransactions();
          _isLoading = false;
        });
      }
    }
  }

  void _filterTransactions() {
    setState(() {
      _filteredTransactions = _transactions.where((transaction) {
        final matchesSearch = _searchQuery.isEmpty || 
            transaction['category'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (transaction['note']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        final matchesType = _selectedType == 'all' || 
            transaction['type'] == _selectedType;
        
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  void _showAddTransactionSheet(bool isIncome) {
    _amountController.clear();
    _categoryController.clear();
    _noteController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddTransactionSheet(isIncome),
    );
  }

  Widget _buildAddTransactionSheet(bool isIncome) {
    List<String> categories = isIncome 
        ? ['Salary', 'Freelance', 'Investment', 'Business', 'Gift', 'Other']
        : ['Food', 'Transportation', 'Entertainment', 'Utilities', 'Shopping', 'Healthcare', 'Other'];

    String selectedCategory = categories.first;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        width: 30,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Color(0xFF64748B),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      // Header with close button
                      Row(
                        children: [
                          SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              'Add ${isIncome ? 'Income' : 'Expense'}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Color(0xFF94A3B8), size: 18),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      
                      // Amount Field
                      Container(
                        height: 45,
                        child: TextField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount *',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF334155)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF6C63FF)),
                            ),
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(color: Colors.white, fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      // Category Dropdown
                      Container(
                        height: 45,
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFF334155)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            icon: Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 18),
                            isExpanded: true,
                            style: TextStyle(color: Colors.white, fontSize: 12),
                            dropdownColor: Color(0xFF1E293B),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedCategory = newValue;
                                });
                              }
                            },
                            items: categories.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      // Note Field
                      Container(
                        height: 45,
                        child: TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: 'Note (Optional)',
                            labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF334155)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF6C63FF)),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  backgroundColor: Color(0xFF334155),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text('Cancel', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                onPressed: () => _saveTransaction(isIncome, selectedCategory),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isIncome ? Color(0xFF2DD4BF) : Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Add',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _saveTransaction(bool isIncome, String category) async {
    final amountText = _amountController.text.trim();
    final noteText = _noteController.text.trim();

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
      await FirebaseService().addTransaction(
        type: isIncome ? 'income' : 'expense',
        amount: amount,
        category: category,
        date: DateTime.now(),
        note: noteText,
      );

      await StorageService.saveLocalTransaction({
        'type': isIncome ? 'income' : 'expense',
        'amount': amount.toString(),
        'category': category,
        'date': DateTime.now().toIso8601String(),
        'note': noteText,
        'createdAt': DateTime.now().toIso8601String(),
      });

      Navigator.pop(context);
      _showSuccess('${isIncome ? 'Income' : 'Expense'} added successfully!');
      _loadTransactions();

    } catch (e) {
      _showError('Failed to add transaction: $e');
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 12)),
        backgroundColor: Color(0xFFF87171),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 12)),
        backgroundColor: Color(0xFF2DD4BF),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 2, // أصغر AppBar
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Color(0xFF6C63FF),
          labelColor: Color(0xFF6C63FF),
          unselectedLabelColor: Color(0xFF64748B),
          labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: 'Income'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsContent('income'),
          _buildTransactionsContent('expense'),
        ],
      ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 16),
        child: FloatingActionButton(
          onPressed: _showAddMenu,
          backgroundColor: Color(0xFF6C63FF),
          child: Icon(Icons.add, color: Colors.white, size: 20),
          // mini: true, // FAB أصغر
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildTransactionsContent(String type) {
    final filtered = _filteredTransactions.where((t) => t['type'] == type).toList();
    
    return Column(
      children: [
        // Search & Filter - أصغر
        Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterTransactions();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: Color(0xFF64748B), size: 16),
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
              SizedBox(width: 6),
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedType = value;
                      _filterTransactions();
                    });
                  },
                  icon: Icon(Icons.filter_list, color: Color(0xFF6C63FF), size: 16),
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'all', child: Text('All Types', style: TextStyle(fontSize: 11))),
                    PopupMenuItem(value: 'income', child: Text('Income Only', style: TextStyle(fontSize: 11))),
                    PopupMenuItem(value: 'expense', child: Text('Expenses Only', style: TextStyle(fontSize: 11))),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Transactions List
        Expanded(
          child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2))
              : filtered.isEmpty 
                  ? _buildEmptyState(type)
                  : RefreshIndicator(
                      onRefresh: () async => _loadTransactions(),
                      backgroundColor: Color(0xFF1E293B),
                      color: Color(0xFF6C63FF),
                      child: ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _buildTransactionItem(filtered[index]),
                      ),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        minLeadingWidth: 30,
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
          transaction['category'] ?? 'Unknown',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          '${_formatDate(date)} • ${transaction['note'] ?? 'No description'}',
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
        onLongPress: () => _showDeleteDialog(transaction),
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'income' ? Icons.money_off : Icons.receipt_long,
              size: 48,
              color: Color(0xFF6C63FF).withOpacity(0.4),
            ),
            SizedBox(height: 12),
            Text(
              type == 'income' ? 'No Income Yet' : 'No Expenses Yet',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              type == 'income' 
                  ? 'Add your first income transaction'
                  : 'Add your first expense transaction',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
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
                'Add Transaction',
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
                  _buildAddOption(Icons.add_circle, 'Income', Color(0xFF2DD4BF), true),
                  _buildAddOption(Icons.remove_circle, 'Expense', Color(0xFFF87171), false),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String label, Color color, bool isIncome) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showAddTransactionSheet(isIncome);
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

  void _showDeleteDialog(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Transaction',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        content: Text(
          'Are you sure you want to delete this transaction?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 11)),
          ),
          TextButton(
            onPressed: () {
              _deleteTransaction(transaction);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Color(0xFFF87171), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _deleteTransaction(Map<String, dynamic> transaction) async {
    try {
      final date = DateTime.parse(transaction['date']);
      final amount = _safeConvertAmount(transaction['amount']);
      await FirebaseService().deleteTransaction(
        transaction['id'],
        date,
        transaction['type'],
        amount,
      );
      
      _showSuccess('Transaction deleted successfully');
      _loadTransactions();
      
    } catch (e) {
      _showError('Failed to delete transaction');
    }
  }

  double _safeConvertAmount(dynamic amountValue) {
    if (amountValue == null) return 0.0;
    if (amountValue is int) return amountValue.toDouble();
    if (amountValue is double) return amountValue;
    if (amountValue is String) return double.tryParse(amountValue) ?? 0.0;
    return 0.0;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}