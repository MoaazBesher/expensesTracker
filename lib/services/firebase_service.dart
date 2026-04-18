import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class FirebaseService {
  // Singleton instance
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();
  
  // Firebase references
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUser = 'user1'; // Single user for now

  // Queue for offline operations
  final List<Map<String, dynamic>> _pendingOperations = [];

  // Check internet connectivity
  Future<bool> get isConnected async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // ============ TRANSACTION METHODS ============ //

  /// Add a new transaction (income or expense)
  Future<void> addTransaction({
    required String type, // 'income' or 'expense'
    required double amount,
    required String category,
    required DateTime date,
    String note = '',
  }) async {
    final transactionData = {
      'type': type,
      'amount': amount.toStringAsFixed(2),
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (await isConnected) {
      // Online: Save directly to Firebase
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final transactionRef = _database
          .child('users')
          .child(_currentUser)
          .child('transactions')
          .child(monthKey)
          .push();
      
      await transactionRef.set(transactionData);
      
      // Update balance
      await _updateBalance(type == 'income' ? amount : -amount);
    } else {
      // Offline: Add to pending operations
      _pendingOperations.add({
        'type': 'transaction',
        'data': transactionData,
        'timestamp': DateTime.now(),
      });
      
      // Save to local storage (will be implemented in storage_service)
      // await StorageService.saveLocalTransaction(transactionData);
    }
  }

  /// Get monthly transactions
  Stream<List<Map<String, dynamic>>> getMonthlyTransactions(DateTime date) {
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final transactionsRef = _database
        .child('users')
        .child(_currentUser)
        .child('transactions')
        .child(monthKey);

    return transactionsRef.onValue.map((event) {
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      if (data == null) return [];

      final List<Map<String, dynamic>> transactions = [];
      data.forEach((key, value) {
        transactions.add({
          'id': key,
          ...value,
        });
      });

      // Sort by date (newest first)
      transactions.sort((a, b) => 
          DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

      return transactions;
    });
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId, DateTime date, String type, double amount) async {
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    
    if (await isConnected) {
      await _database
          .child('users')
          .child(_currentUser)
          .child('transactions')
          .child(monthKey)
          .child(transactionId)
          .remove();

      // Update balance (reverse the transaction)
      await _updateBalance(type == 'income' ? -amount : amount);
    } else {
      // Add to pending delete operations
      _pendingOperations.add({
        'type': 'delete_transaction',
        'transactionId': transactionId,
        'monthKey': monthKey,
        'amount': amount,
        'transactionType': type,
        'timestamp': DateTime.now(),
      });
    }
  }

  // ============ BALANCE METHODS ============ //

  /// Get current balance
  Stream<double> getBalance() {
    final balanceRef = _database
        .child('users')
        .child(_currentUser)
        .child('balance');

    return balanceRef.onValue.map((event) {
      final dynamic data = event.snapshot.value;
      // Fix: Handle different data types safely
      if (data == null) return 0.0;
      if (data is int) return data.toDouble();
      if (data is double) return data;
      if (data is String) return double.tryParse(data) ?? 0.0;
      return 0.0;
    });
  }

  /// Update user balance
  Future<void> _updateBalance(double amount) async {
    if (await isConnected) {
      final balanceRef = _database
          .child('users')
          .child(_currentUser)
          .child('balance');

      final currentBalance = await balanceRef.once().then((snapshot) {
        final dynamic data = snapshot.snapshot.value;
        // Fix: Handle different data types safely
        if (data == null) return 0.0;
        if (data is int) return data.toDouble();
        if (data is double) return data;
        if (data is String) return double.tryParse(data) ?? 0.0;
        return 0.0;
      });

      await balanceRef.set(currentBalance + amount);
    }
  }

  /// Set manual balance
  Future<void> setBalance(double newBalance) async {
    if (await isConnected) {
      await _database
          .child('users')
          .child(_currentUser)
          .child('balance')
          .set(newBalance);
    }
  }

  // ============ REMINDER METHODS ============ //

  /// Add a new reminder
  Future<void> addReminder({
    required String title,
    required DateTime date,
    String notes = '',
  }) async {
    final reminderData = {
      'title': title,
      'date': date.toIso8601String(),
      'notes': notes,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (await isConnected) {
      final reminderRef = _database
          .child('users')
          .child(_currentUser)
          .child('reminders')
          .push();

      await reminderRef.set(reminderData);
    } else {
      _pendingOperations.add({
        'type': 'reminder',
        'data': reminderData,
        'timestamp': DateTime.now(),
      });
    }
  }

  /// Get all reminders
  Stream<List<Map<String, dynamic>>> getReminders() {
    final remindersRef = _database
        .child('users')
        .child(_currentUser)
        .child('reminders');

    return remindersRef.onValue.map((event) {
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      if (data == null) return [];

      final List<Map<String, dynamic>> reminders = [];
      data.forEach((key, value) {
        reminders.add({
          'id': key,
          ...value,
        });
      });

      // Sort by date (ascending)
      reminders.sort((a, b) => 
          DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

      return reminders;
    });
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    if (await isConnected) {
      await _database
          .child('users')
          .child(_currentUser)
          .child('reminders')
          .child(reminderId)
          .remove();
    } else {
      _pendingOperations.add({
        'type': 'delete_reminder',
        'reminderId': reminderId,
        'timestamp': DateTime.now(),
      });
    }
  }

  // ============ DEBT METHODS ============ //

  /// Add a debt (I Owe or Owed to Me)
  Future<void> addDebt({
    required String type, // 'iOwe' or 'owedToMe'
    required String person,
    required double amount,
    String notes = '',
  }) async {
    final debtData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'amount': amount.toStringAsFixed(2),
      'person': person,
      'notes': notes,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (await isConnected) {
      final debtsRef = _database
          .child('users')
          .child(_currentUser)
          .child('debts')
          .child(type);

      final doc = await debtsRef.once();
      final Map<dynamic, dynamic>? currentData = doc.snapshot.value as Map?;
      
      List<dynamic> currentDebts = [];
      if (currentData != null && currentData['debts'] != null) {
        currentDebts = List.from(currentData['debts']);
      }

      currentDebts.add(debtData);

      await debtsRef.set({
        'debts': currentDebts,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } else {
      _pendingOperations.add({
        'type': 'debt',
        'debtType': type,
        'data': debtData,
        'timestamp': DateTime.now(),
      });
    }
  }

  /// Get all debts
  Stream<Map<String, dynamic>> getDebts() {
    final debtsRef = _database
        .child('users')
        .child(_currentUser)
        .child('debts');

    return debtsRef.onValue.map((event) {
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      
      final Map<String, dynamic> debts = {
        'iOwe': [],
        'owedToMe': [],
      };

      if (data != null) {
        // Process I Owe
        if (data['iOwe'] != null && data['iOwe'] is Map) {
          final iOweData = data['iOwe'] as Map;
          if (iOweData['debts'] != null && iOweData['debts'] is List) {
            debts['iOwe'] = List.from(iOweData['debts']);
          }
        }

        // Process Owed to Me
        if (data['owedToMe'] != null && data['owedToMe'] is Map) {
          final owedToMeData = data['owedToMe'] as Map;
          if (owedToMeData['debts'] != null && owedToMeData['debts'] is List) {
            debts['owedToMe'] = List.from(owedToMeData['debts']);
          }
        }
      }

      return debts;
    });
  }

  /// Delete a debt
  Future<void> deleteDebt(String debtType, String debtId) async {
    if (await isConnected) {
      final debtsRef = _database
          .child('users')
          .child(_currentUser)
          .child('debts')
          .child(debtType);

      final doc = await debtsRef.once();
      final Map<dynamic, dynamic>? currentData = doc.snapshot.value as Map?;
      
      if (currentData != null && currentData['debts'] != null) {
        List<dynamic> currentDebts = List.from(currentData['debts']);
        
        // البحث عن الدين باستخدام ID وإزالته
        currentDebts.removeWhere((debt) {
          if (debt is Map) {
            final id = debt['id']?.toString();
            return id == debtId;
          }
          return false;
        });

        await debtsRef.set({
          'debts': currentDebts,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
    } else {
      _pendingOperations.add({
        'type': 'delete_debt',
        'debtType': debtType,
        'debtId': debtId,
        'timestamp': DateTime.now(),
      });
    }
  }

  // ============ SYNC METHODS ============ //

  /// Sync all pending operations when coming online
  Future<void> syncPendingOperations() async {
    if (!await isConnected) return;

    for (final operation in List.from(_pendingOperations)) {
      try {
        switch (operation['type']) {
          case 'transaction':
            await addTransaction(
              type: operation['data']['type'],
              amount: double.parse(operation['data']['amount']),
              category: operation['data']['category'],
              date: DateTime.parse(operation['data']['date']),
              note: operation['data']['note'],
            );
            break;

          case 'reminder':
            await addReminder(
              title: operation['data']['title'],
              date: DateTime.parse(operation['data']['date']),
              notes: operation['data']['notes'],
            );
            break;

          case 'debt':
            await addDebt(
              type: operation['debtType'],
              amount: double.parse(operation['data']['amount']),
              person: operation['data']['person'],
              notes: operation['data']['notes'],
            );
            break;

          // Handle delete operations
          case 'delete_transaction':
            // Note: We need the original transaction data for balance update
            // This would require more complex handling with local storage
            break;

          case 'delete_reminder':
            await deleteReminder(operation['reminderId']);
            break;

          case 'delete_debt':
            await deleteDebt(operation['debtType'], operation['debtId']);
            break;
        }

        // Remove successful operation from queue
        _pendingOperations.remove(operation);
      } catch (e) {
        print('Failed to sync operation: $e');
        // Keep failed operations for retry
      }
    }
  }

  // ============ ANALYTICS METHODS ============ //

  /// Get monthly summary
  Future<Map<String, double>> getMonthlySummary(DateTime date) async {
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final transactionsRef = _database
        .child('users')
        .child(_currentUser)
        .child('transactions')
        .child(monthKey);

    try {
      final snapshot = await transactionsRef.once();
      final Map<dynamic, dynamic>? data = snapshot.snapshot.value as Map?;

      double totalIncome = 0.0;
      double totalExpenses = 0.0;

      if (data != null) {
        data.forEach((key, value) {
          // Fix: Handle amount conversion safely
          final dynamic amountValue = value['amount'];
          double amount = 0.0;
          
          if (amountValue is int) {
            amount = amountValue.toDouble();
          } else if (amountValue is double) {
            amount = amountValue;
          } else if (amountValue is String) {
            amount = double.tryParse(amountValue) ?? 0.0;
          }
          
          if (value['type'] == 'income') {
            totalIncome += amount;
          } else {
            totalExpenses += amount;
          }
        });
      }

      return {
        'income': totalIncome,
        'expenses': totalExpenses,
        'savings': totalIncome - totalExpenses,
      };
    } catch (e) {
      return {'income': 0.0, 'expenses': 0.0, 'savings': 0.0};
    }
  }

  /// Get category-wise expenses
  Future<Map<String, double>> getCategoryExpenses(DateTime date) async {
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final transactionsRef = _database
        .child('users')
        .child(_currentUser)
        .child('transactions')
        .child(monthKey);

    try {
      final snapshot = await transactionsRef.once();
      final Map<dynamic, dynamic>? data = snapshot.snapshot.value as Map?;

      final Map<String, double> categoryTotals = {};

      if (data != null) {
        data.forEach((key, value) {
          if (value['type'] == 'expense') {
            final category = value['category'];
            // Fix: Handle amount conversion safely
            final dynamic amountValue = value['amount'];
            double amount = 0.0;
            
            if (amountValue is int) {
              amount = amountValue.toDouble();
            } else if (amountValue is double) {
              amount = amountValue;
            } else if (amountValue is String) {
              amount = double.tryParse(amountValue) ?? 0.0;
            }
            
            categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
          }
        });
      }

      return categoryTotals;
    } catch (e) {
      return {};
    }
  }

  // ============ UTILITY METHODS ============ //

  /// Clear all user data (for testing)
  Future<void> clearUserData() async {
    if (await isConnected) {
      await _database
          .child('users')
          .child(_currentUser)
          .remove();
    }
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final balance = await getBalance().first;
    final debts = await getDebts().first;
    
    double totalIOwe = 0.0;
    double totalOwedToMe = 0.0;

    if (debts['iOwe'] is List) {
      for (final debt in debts['iOwe'] as List) {
        if (debt is Map && debt['amount'] != null) {
          totalIOwe += _safeConvertAmount(debt['amount']);
        }
      }
    }

    if (debts['owedToMe'] is List) {
      for (final debt in debts['owedToMe'] as List) {
        if (debt is Map && debt['amount'] != null) {
          totalOwedToMe += _safeConvertAmount(debt['amount']);
        }
      }
    }

    return {
      'balance': balance,
      'totalIOwe': totalIOwe,
      'totalOwedToMe': totalOwedToMe,
      'netWorth': balance + totalOwedToMe - totalIOwe,
    };
  }

  // Helper method for safe amount conversion
  double _safeConvertAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is int) return amount.toDouble();
    if (amount is double) return amount;
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }
}

List<Map<String, dynamic>> _convertToListOfMaps(List<dynamic> data) {
  final List<Map<String, dynamic>> result = [];
  
  for (final item in data) {
    if (item is Map<String, dynamic>) {
      result.add(item);
    } else if (item is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      final convertedMap = <String, dynamic>{};
      item.forEach((key, value) {
        convertedMap[key.toString()] = value;
      });
      result.add(convertedMap);
    }
  }
  
  return result;
}