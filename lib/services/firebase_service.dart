import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../models/account_model.dart';
import 'storage_service.dart';

class FirebaseService {
  // Singleton instance
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUser => _auth.currentUser?.uid;

  final List<Map<String, dynamic>> _pendingOperations = [];

  Future<bool> get isConnected async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // ============ TRANSACTIONS ============

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String category,
    required DateTime date,
    required String accountId,
    String note = '',
    int? localId,
    /// When set (e.g. replaying an offline save), stored instead of server time so the record reflects the real moment.
    DateTime? clientCreatedAt,
  }) async {
    if (_currentUser == null) return;

    final Object createdAtValue = clientCreatedAt != null
        ? Timestamp.fromDate(clientCreatedAt)
        : FieldValue.serverTimestamp();

    final transactionData = {
      'type': type,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'accountId': accountId,
      'note': note,
      'createdAt': createdAtValue,
    };

    if (await isConnected) {
      final docRef = await _firestore
          .collection('users')
          .doc(_currentUser)
          .collection('transactions')
          .add(transactionData);
          
      // Update account balance
      await _updateAccountBalance(accountId, type == 'income' ? amount : -amount);
      
      // Update local storage
      if (localId != null) {
        await StorageService.markTransactionSynced(localId, docRef.id);
      }
    } else {
      _pendingOperations.add({
        'type': 'transaction',
        'data': transactionData,
        'timestamp': DateTime.now(),
      });
      // StorageService.saveLocalTransaction handles this independently typically
    }
  }

  Stream<List<Map<String, dynamic>>> getMonthlyTransactions(DateTime date) {
    if (_currentUser == null) return Stream.value([]);

    // Get the start and end of the month string format to do simple prefix search or parse
    final monthStr = '${date.year}-${date.month.toString().padLeft(2, '0')}';

    return _firestore
        .collection('users')
        .doc(_currentUser)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          final allTransactions = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          return allTransactions.where((t) {
            final tDateStr = t['date'] as String;
            return tDateStr.startsWith(monthStr);
          }).toList();
        });
  }

  Future<void> updateTransaction({
    required String transactionId,
    required String accountId,
    required String oldType,
    required double oldAmount,
    required String newType,
    required double newAmount,
    required String category,
    required DateTime date,
    required String note,
  }) async {
    if (_currentUser == null || !await isConnected) return;
    // Reverse old balance effect then apply new
    await _updateAccountBalance(accountId, oldType == 'income' ? -oldAmount : oldAmount);
    await _firestore
        .collection('users')
        .doc(_currentUser)
        .collection('transactions')
        .doc(transactionId)
        .update({
      'type': newType,
      'amount': newAmount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
    });
    await _updateAccountBalance(accountId, newType == 'income' ? newAmount : -newAmount);
  }

  Future<void> deleteTransaction(String transactionId, String accountId, String type, double amount) async {
    if (_currentUser == null) return;

    if (await isConnected) {
      await _firestore
          .collection('users')
          .doc(_currentUser)
          .collection('transactions')
          .doc(transactionId)
          .delete();

      await _updateAccountBalance(accountId, type == 'income' ? -amount : amount);
    } else {
      _pendingOperations.add({
        'type': 'delete_transaction',
        'transactionId': transactionId,
        'accountId': accountId,
        'amount': amount,
        'transactionType': type,
        'timestamp': DateTime.now(),
      });
    }
  }

  // ============ ACCOUNTS (Money Sources) ============

  Future<void> ensureDefaultAccountExists() async {
    if (_currentUser == null || !await isConnected) return;
    
    final accountsSnapshot = await _firestore
        .collection('users')
        .doc(_currentUser)
        .collection('accounts')
        .limit(1)
        .get();
        
    if (accountsSnapshot.docs.isEmpty) {
      await addAccount(name: 'Cash', type: 'Cash', initialBalance: 0.0);
    }
  }

  Future<void> addAccount({required String name, required String type, required double initialBalance, bool isDefault = false}) async {
    if (_currentUser == null) return;
    if (await isConnected) {
      await _firestore
          .collection('users')
          .doc(_currentUser)
          .collection('accounts')
          .add({
        'name': name,
        'type': type,
        'balance': initialBalance,
        'currency': 'USD',
        'isDefault': isDefault,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> setAccountAsDefault(String accountId) async {
    if (_currentUser == null || !await isConnected) return;
    
    final batch = _firestore.batch();
    final accountsRef = _firestore.collection('users').doc(_currentUser).collection('accounts');
    
    final snapshot = await accountsRef.get();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == accountId});
    }
    
    await batch.commit();
  }

  Future<void> deleteAccount(String accountId) async {
    if (_currentUser == null || !await isConnected) return;
    await _firestore
        .collection('users')
        .doc(_currentUser)
        .collection('accounts')
        .doc(accountId)
        .delete();
  }

  Stream<List<AccountModel>> getAccounts() {
    if (_currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_currentUser)
        .collection('accounts')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => AccountModel.fromMap(doc.data(), doc.id)).toList();
        });
  }

  Future<void> _updateAccountBalance(String accountId, double amountChange) async {
    if (_currentUser == null) return;
    if (accountId.isEmpty) return; // Skip if no account linked
    
    final docRef = _firestore.collection('users').doc(_currentUser).collection('accounts').doc(accountId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final currentBalance = (snapshot.data()?['balance'] ?? 0.0) as num;
      transaction.update(docRef, {'balance': currentBalance.toDouble() + amountChange});
    });
  }

  // ============ REMINDER METHODS ============ //

  Future<void> addReminder({required String title, required DateTime date, String notes = '', int? localId}) async {
    if (_currentUser == null) return;
    final data = {
      'title': title,
      'date': date.toIso8601String(),
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (await isConnected) {
      final docRef = await _firestore.collection('users').doc(_currentUser).collection('reminders').add(data);
      if (localId != null) {
        await StorageService.markReminderSynced(localId, docRef.id);
      }
    } else {
      _pendingOperations.add({'type': 'reminder', 'data': data});
    }
  }

  Stream<List<Map<String, dynamic>>> getReminders() {
    if (_currentUser == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(_currentUser)
        .collection('reminders')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          var d = doc.data();
          d['id'] = doc.id;
          return d;
        }).toList());
  }

  Future<void> updateReminder({
    required String reminderId,
    required String title,
    required DateTime date,
    required String notes,
  }) async {
    if (_currentUser == null || !await isConnected) return;
    await _firestore
        .collection('users')
        .doc(_currentUser)
        .collection('reminders')
        .doc(reminderId)
        .update({'title': title, 'date': date.toIso8601String(), 'notes': notes});
  }

  Future<void> deleteReminder(String reminderId) async {
    if (_currentUser == null) return;
    if (await isConnected) {
      await _firestore.collection('users').doc(_currentUser).collection('reminders').doc(reminderId).delete();
    } else {
      _pendingOperations.add({'type': 'delete_reminder', 'reminderId': reminderId});
    }
  }

  // ============ DEBTS ============

  Future<void> addDebt({required String type, required String person, required double amount, String notes = '', int? localId}) async {
    if (_currentUser == null) return;
    final data = {
      'debtType': type, // 'iOwe' or 'owedToMe'
      'person': person,
      'amount': amount,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (await isConnected) {
      final docRef = await _firestore.collection('users').doc(_currentUser).collection('debts').add(data);
      if (localId != null) {
        await StorageService.markDebtSynced(localId, docRef.id);
      }
    } else {
      _pendingOperations.add({'type': 'debt', 'data': data});
    }
  }

  Stream<Map<String, dynamic>> getDebts() {
    if (_currentUser == null) return Stream.value({'iOwe': [], 'owedToMe': []});
    
    return _firestore
        .collection('users')
        .doc(_currentUser)
        .collection('debts')
        .snapshots()
        .map((snapshot) {
          final Map<String, dynamic> debts = {'iOwe': [], 'owedToMe': []};
          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            // Convert Timestamp to ISO string so the UI can safely parse it
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
            }
            if (data['debtType'] == 'iOwe') {
              debts['iOwe'].add(data);
            } else {
              debts['owedToMe'].add(data);
            }
          }
          return debts;
        });
  }

  Future<void> updateDebt({
    required String debtId,
    required String person,
    required double amount,
    required String notes,
  }) async {
    if (_currentUser == null) return;
    if (await isConnected) {
      await _firestore
          .collection('users')
          .doc(_currentUser)
          .collection('debts')
          .doc(debtId)
          .update({
        'person': person,
        'amount': amount,
        'notes': notes,
      });
    }
  }

  Future<void> deleteDebt(String debtId) async {
    if (_currentUser == null) return;
    if (await isConnected) {
      await _firestore.collection('users').doc(_currentUser).collection('debts').doc(debtId).delete();
    } else {
      _pendingOperations.add({'type': 'delete_debt', 'debtId': debtId});
    }
  }

  // ============ USER STATS ============

  Stream<Map<String, dynamic>> getUserStats() {
    if (_currentUser == null) return Stream.value({'balance': 0.0, 'totalIOwe': 0.0, 'totalOwedToMe': 0.0, 'netWorth': 0.0});

    final accountsStream = getAccounts();

    return accountsStream.asyncMap((accounts) async {
      double totalBalance = accounts.fold(0.0, (total, acc) => total + acc.balance);
      
      final debtsSnapshot = await _firestore.collection('users').doc(_currentUser).collection('debts').get();
      double totalIOwe = 0.0;
      double totalOwedToMe = 0.0;
      
      for (var doc in debtsSnapshot.docs) {
        final data = doc.data();
        double amount = (data['amount'] as num).toDouble();
        if (data['debtType'] == 'iOwe') {
          totalIOwe += amount;
        } else {
          totalOwedToMe += amount;
        }
      }

      return {
        'balance': totalBalance,
        'totalIOwe': totalIOwe,
        'totalOwedToMe': totalOwedToMe,
        'netWorth': totalBalance + totalOwedToMe - totalIOwe,
      };
    });
  }

  Future<void> syncPendingOperations() async {
    // Basic sync, ideally should be expanded
    if (!await isConnected) return;
    _pendingOperations.clear();
    // Implementation needed for replay
  }
}