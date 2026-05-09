import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';


class MonthlyBillsScreen extends StatefulWidget {
  const MonthlyBillsScreen({super.key});

  @override
  State<MonthlyBillsScreen> createState() => _MonthlyBillsScreenState();
}

class _MonthlyBillsScreenState extends State<MonthlyBillsScreen> {
  final DateTime _selectedMonth = DateTime.now();
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
      debugPrint('Online load failed: $e');
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

    for (final transaction in _transactions) {
      final amount = _safeConvertAmount(transaction['amount']);
      final type = transaction['type']?.toString() ?? 'expense';

      if (type == 'income') {
        income += amount;
      } else {
        expenses += amount;
      }
    }

    setState(() {
      _totalIncome = income;
      _totalExpenses = expenses;
      _netSavings = income - expenses;
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
        final dateA = DateTime.parse(a['date'] ?? DateTime.now().toIso8601String());
        final dateB = DateTime.parse(b['date'] ?? DateTime.now().toIso8601String());
        return dateB.compareTo(dateA);
      });
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Filter Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterSection('Type', DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    onChanged: (v) => setState(() => _selectedType = v!),
                    items: ['all', 'income', 'expense'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  )),
                  const SizedBox(height: 16),
                  _buildFilterSection('Amount Range', Row(
                    children: [
                      Expanded(child: TextField(
                        controller: _minAmountController,
                        decoration: const InputDecoration(labelText: 'Min'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _minAmount = double.tryParse(v) ?? 0.0),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(
                        controller: _maxAmountController,
                        decoration: const InputDecoration(labelText: 'Max'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _maxAmount = double.tryParse(v) ?? 10000.0),
                      )),
                    ],
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () { _resetFilters(); Navigator.pop(context); }, child: const Text('Reset', style: TextStyle(color: Colors.red))),
              TextButton(onPressed: () { _applyFilters(); Navigator.pop(context); }, child: const Text('Apply')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedType = 'all';
      _selectedCategory = 'all';
      _minAmount = 0.0;
      _maxAmount = 10000.0;
      _searchController.clear();
      _minAmountController.text = '0.00';
      _maxAmountController.text = '10000.00';
    });
    _applyFilters();
  }

  double _safeConvertAmount(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Financial Report'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildFilterBar(),
          _buildActiveFilters(),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryCard('Income', _totalIncome, Colors.green),
          const SizedBox(width: 8),
          _buildSummaryCard('Expenses', _totalExpenses, Colors.red),
          const SizedBox(width: 8),
          _buildSummaryCard('Savings', _netSavings, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            Text('\$${value.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) { setState(() => _searchQuery = v); _applyFilters(); },
              decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search)),
            ),
          ),
          IconButton(icon: const Icon(Icons.filter_list, color: Colors.indigoAccent), onPressed: _showFilterDialog),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    final filters = <String>[];
    if (_selectedType != 'all') filters.add(_selectedType);
    if (_searchQuery.isNotEmpty) filters.add('Search');
    
    if (filters.isEmpty) return const SizedBox();
    
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.map((f) => Chip(label: Text(f))).toList(),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final t = _filteredTransactions[index];
        final isIncome = t['type'] == 'income';
        final amt = _safeConvertAmount(t['amount']);
        return Card(
          color: const Color(0xFF1E293B),
          child: ListTile(
            leading: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? Colors.green : Colors.red),
            title: Text(t['category'] ?? 'General', style: const TextStyle(color: Colors.white)),
            subtitle: Text(t['note'] ?? '', style: const TextStyle(color: Colors.grey)),
            trailing: Text('\$${amt.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() => const Center(child: Text('No results found', style: TextStyle(color: Colors.grey)));
}