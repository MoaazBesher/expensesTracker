import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class StorageService {
  // Singleton instance
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static Database? _database;
  static const String _dbName = 'finflow_elite.db';
  static const int _dbVersion = 1;

  // Initialize database
  static Future<void> init() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // Create database tables
  static Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        account_id TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        debt_type TEXT NOT NULL,
        amount REAL NOT NULL,
        person TEXT NOT NULL,
        due_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        operation_data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_retry TEXT
      )
    ''');

    debugPrint('🎯 FinFlow Elite Database Created Successfully');
  }

  static Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add new columns or tables for future versions
    }
  }

  // ============ TRANSACTION METHODS ============ //

  /// Save transaction locally
  static Future<int> saveLocalTransaction(Map<String, dynamic> transaction) async {
    await init();
    
    return await _database!.insert('transactions', {
      'type': transaction['type'],
      'amount': double.parse(transaction['amount']),
      'category': transaction['category'],
      'date': transaction['date'],
      'account_id': transaction['accountId'],
      'note': transaction['note'] ?? '',
      'created_at': transaction['createdAt'],
      'is_synced': 0,
      'sync_status': 'pending',
    });
  }

  /// Get local transactions
  static Future<List<Map<String, dynamic>>> getLocalTransactions(DateTime date) async {
    await init();
    
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    
    final transactions = await _database!.query(
      'transactions',
      where: 'date LIKE ?',
      whereArgs: ['$monthKey%'],
      orderBy: 'date DESC',
    );

    return transactions.map((map) {
      final synced = (map['is_synced'] as int? ?? 0) == 1;
      return {
        'id': 'local_${map['id']}',
        'type': map['type'] as String,
        'amount': (map['amount'] as double).toString(),
        'category': map['category'] as String,
        'date': map['date'] as String,
        'accountId': map['account_id'] as String,
        'note': map['note'] as String? ?? '',
        'createdAt': map['created_at'] as String,
        'isLocal': true,
        'pendingSync': !synced,
      };
    }).toList();
  }

  /// Get unsynced transactions
  static Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
    await init();
    
    final transactions = await _database!.query(
      'transactions',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    return transactions.map((map) {
      return {
        'id': map['id'] as int,
        'type': map['type'] as String,
        'amount': map['amount'] as double,
        'category': map['category'] as String,
        'date': map['date'] as String,
        'accountId': map['account_id'] as String,
        'note': map['note'] as String? ?? '',
        'createdAt': map['created_at'] as String,
      };
    }).toList();
  }

  /// Delete a row from local transactions (e.g. user deleted a pending item).
  static Future<void> deleteLocalTransaction(int localId) async {
    await init();
    await _database!.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Update a pending (not yet synced) local transaction.
  static Future<void> updateLocalTransaction(
    int localId, {
    required double amount,
    required String category,
    required String dateIso,
    required String note,
  }) async {
    await init();
    await _database!.update(
      'transactions',
      {
        'amount': amount,
        'category': category,
        'date': dateIso,
        'note': note,
      },
      where: 'id = ? AND is_synced = ?',
      whereArgs: [localId, 0],
    );
  }

  /// Mark transaction as synced
  static Future<void> markTransactionSynced(int localId, String firebaseId) async {
    await init();
    
    await _database!.update(
      'transactions',
      {
        'is_synced': 1,
        'firebase_id': firebaseId,
        'sync_status': 'synced',
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ============ REMINDER METHODS ============ //

  /// Save reminder locally
  static Future<int> saveLocalReminder(Map<String, dynamic> reminder) async {
    await init();
    
    return await _database!.insert('reminders', {
      'title': reminder['title'],
      'date': reminder['date'],
      'notes': reminder['notes'] ?? '',
      'created_at': reminder['createdAt'],
      'is_synced': 0,
      'sync_status': 'pending',
    });
  }

  /// Get local reminders
  static Future<List<Map<String, dynamic>>> getLocalReminders() async {
    await init();
    
    final reminders = await _database!.query(
      'reminders',
      orderBy: 'date ASC',
    );

    return reminders.map((map) {
      return {
        'id': 'local_${map['id']}',
        'title': map['title'] as String,
        'date': map['date'] as String,
        'notes': map['notes'] as String? ?? '',
        'createdAt': map['created_at'] as String,
        'isLocal': true,
      };
    }).toList();
  }

  /// Get unsynced reminders
  static Future<List<Map<String, dynamic>>> getUnsyncedReminders() async {
    await init();
    
    final reminders = await _database!.query(
      'reminders',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    return reminders.map((map) {
      return {
        'id': map['id'] as int,
        'title': map['title'] as String,
        'date': map['date'] as String,
        'notes': map['notes'] as String? ?? '',
        'createdAt': map['created_at'] as String,
      };
    }).toList();
  }

  /// Mark reminder as synced
  static Future<void> markReminderSynced(int localId, String firebaseId) async {
    await init();
    
    await _database!.update(
      'reminders',
      {
        'is_synced': 1,
        'firebase_id': firebaseId,
        'sync_status': 'synced',
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Delete a local-only reminder row (e.g. unsynced or before cloud delete).
  static Future<void> deleteLocalReminder(int localId) async {
    await init();
    await _database!.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ============ DEBT METHODS ============ //

  /// Save debt locally
  static Future<int> saveLocalDebt(String debtType, Map<String, dynamic> debt) async {
    await init();
    
    return await _database!.insert('debts', {
      'debt_type': debtType,
      'amount': double.parse(debt['amount']),
      'person': debt['person'],
      'due_date': debt['dueDate'],
      'notes': debt['notes'] ?? '',
      'created_at': debt['createdAt'],
      'is_synced': 0,
      'sync_status': 'pending',
    });
  }

  /// Get local debts (only unsynced ones for UI merging)
  static Future<Map<String, List<Map<String, dynamic>>>> getLocalDebts() async {
    await init();
    
    final debts = await _database!.query(
      'debts',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );

    final Map<String, List<Map<String, dynamic>>> categorizedDebts = {
      'iOwe': [],
      'owedToMe': [],
    };

    for (final debt in debts) {
      final debtMap = {
        'id': 'local_${debt['id']}',
        'debtType': debt['debt_type'] as String,
        'amount': (debt['amount'] as double).toString(),
        'person': debt['person'] as String,
        'dueDate': debt['due_date'] as String?,
        'notes': debt['notes'] as String? ?? '',
        'createdAt': debt['created_at'] as String,
        'isLocal': true,
        'pendingSync': true,
      };

      if (debt['debt_type'] == 'iOwe') {
        categorizedDebts['iOwe']!.add(debtMap);
      } else {
        categorizedDebts['owedToMe']!.add(debtMap);
      }
    }

    return categorizedDebts;
  }

  /// Get unsynced debts
  static Future<List<Map<String, dynamic>>> getUnsyncedDebts() async {
    await init();
    
    final debts = await _database!.query(
      'debts',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    return debts.map((map) {
      return {
        'id': map['id'] as int,
        'debt_type': map['debt_type'] as String,
        'amount': map['amount'] as double,
        'person': map['person'] as String,
        'due_date': map['due_date'] as String?,
        'notes': map['notes'] as String? ?? '',
        'createdAt': map['created_at'] as String,
      };
    }).toList();
  }

  /// Mark debt as synced
  static Future<void> markDebtSynced(int localId, String firebaseId) async {
    await init();
    
    await _database!.update(
      'debts',
      {
        'is_synced': 1,
        'firebase_id': firebaseId,
        'sync_status': 'synced',
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Delete a local debt row
  static Future<void> deleteLocalDebt(int localId) async {
    await init();
    await _database!.delete(
      'debts',
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Update a pending (unsynced) local debt
  static Future<void> updateLocalDebt(
    int localId, {
    required String person,
    required double amount,
    required String notes,
  }) async {
    await init();
    await _database!.update(
      'debts',
      {
        'person': person,
        'amount': amount,
        'notes': notes,
      },
      where: 'id = ? AND is_synced = ?',
      whereArgs: [localId, 0],
    );
  }

  // ============ PENDING OPERATIONS METHODS ============ //

  /// Save pending operation
  static Future<int> savePendingOperation(String type, Map<String, dynamic> data) async {
    await init();
    
    return await _database!.insert('pending_operations', {
      'operation_type': type,
      'operation_data': _encodeOperationData(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  /// Get pending operations
  static Future<List<Map<String, dynamic>>> getPendingOperations() async {
    await init();
    
    final operations = await _database!.query(
      'pending_operations',
      orderBy: 'created_at ASC',
    );

    return operations.map((map) {
      // Fix: Handle the type conversion safely
      final operationData = map['operation_data'];
      final String operationDataString;
      
      if (operationData is String) {
        operationDataString = operationData;
      } else {
        operationDataString = operationData.toString();
      }
      
      return {
        'id': map['id'] as int,
        'type': map['operation_type'] as String,
        'data': _decodeOperationData(operationDataString),
        'createdAt': map['created_at'] as String,
        'retryCount': map['retry_count'] as int,
      };
    }).toList();
  }

  /// Remove pending operation
  static Future<void> removePendingOperation(int id) async {
    await init();
    await _database!.delete(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increment retry count
  static Future<void> incrementRetryCount(int id) async {
    await init();
    await _database!.update(
      'pending_operations',
      {
        'retry_count': await _getRetryCount(id) + 1,
        'last_retry': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> _getRetryCount(int id) async {
    final result = await _database!.query(
      'pending_operations',
      columns: ['retry_count'],
      where: 'id = ?',
      whereArgs: [id],
    );
    
    return result.first['retry_count'] as int;
  }

  // ============ SYNC METHODS ============ //

  /// Sync all local data to Firebase
  static Future<void> syncAllLocalData() async {
    await init();
    
    if (!await FirebaseService().isConnected) return;
    
    debugPrint('🔄 Starting Master Sync...');

    // 1. Sync Transactions
    final unsyncedTransactions = await getUnsyncedTransactions();
    for (final t in unsyncedTransactions) {
      try {
        await FirebaseService().addTransaction(
          type: t['type'],
          amount: t['amount'],
          category: t['category'],
          date: DateTime.parse(t['date'] as String),
          accountId: t['accountId'] as String,
          note: t['note'] as String,
          localId: t['id'] as int,
          clientCreatedAt: DateTime.tryParse(t['createdAt'] as String? ?? ''),
        );
      } catch (e) {
        debugPrint('❌ Transaction sync failed: $e');
      }
    }

    // 2. Sync Reminders
    final unsyncedReminders = await getUnsyncedReminders();
    for (final r in unsyncedReminders) {
      try {
        await FirebaseService().addReminder(
          title: r['title'],
          date: DateTime.parse(r['date']),
          notes: r['notes'],
          localId: r['id'] as int,
        );
      } catch (e) {
        debugPrint('❌ Reminder sync failed: $e');
      }
    }

    // 3. Sync Debts
    final unsyncedDebts = await getUnsyncedDebts();
    for (final d in unsyncedDebts) {
      try {
        await FirebaseService().addDebt(
          type: d['debt_type'],
          person: d['person'],
          amount: d['amount'],
          notes: d['notes'],
          localId: d['id'] as int,
        );
      } catch (e) {
        debugPrint('❌ Debt sync failed: $e');
      }
    }

    await saveLastSyncTimestamp();
    debugPrint('✅ Master Sync Completed');
  }

  // ============ SHARED PREFERENCES METHODS ============ //

  /// Save user balance locally
  static Future<void> saveLocalBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_balance', balance);
  }

  /// Get local user balance
  static Future<double> getLocalBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('user_balance') ?? 0.0;
  }

  /// Save last sync timestamp
  static Future<void> saveLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync', DateTime.now().toIso8601String());
  }

  /// Get last sync timestamp
  static Future<DateTime?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_sync');
    return lastSync != null ? DateTime.parse(lastSync) : null;
  }

  /// Save user preferences
  static Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (preferences.containsKey('currency')) {
      await prefs.setString('currency', preferences['currency'] as String);
    }
    
    if (preferences.containsKey('theme')) {
      await prefs.setString('theme', preferences['theme'] as String);
    }
    
    if (preferences.containsKey('notifications')) {
      await prefs.setBool('notifications', preferences['notifications'] as bool);
    }
  }

  /// Get user preferences
  static Future<Map<String, dynamic>> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'currency': prefs.getString('currency') ?? 'USD',
      'theme': prefs.getString('theme') ?? 'dark',
      'notifications': prefs.getBool('notifications') ?? true,
    };
  }

  // ============ UTILITY METHODS ============ //

  /// Encode operation data for storage
  static String _encodeOperationData(Map<String, dynamic> data) {
    // Use JSON encoding for proper handling
    return jsonEncode(data);
  }

  /// Decode operation data from storage
  static Map<String, dynamic> _decodeOperationData(String encoded) {
    try {
      // Use JSON decoding for proper handling
      final Map<String, dynamic> decoded = jsonDecode(encoded);
      return decoded;
    } catch (e) {
      // Fallback to simple decoding if JSON fails
      final Map<String, dynamic> data = {};
      final pairs = encoded.split('|');
      
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          data[parts[0]] = parts[1];
        }
      }
      
      return data;
    }
  }

  /// Clear all local data (for testing/debugging)
  static Future<void> clearAllData() async {
    await init();
    
    await _database!.delete('transactions');
    await _database!.delete('reminders');
    await _database!.delete('debts');
    await _database!.delete('pending_operations');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    debugPrint('🗑️ All local data cleared');
  }

  /// Get database statistics
  static Future<Map<String, int>> getDatabaseStats() async {
    await init();
    
    final transactionCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM transactions')
    ) ?? 0;
    
    final reminderCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM reminders')
    ) ?? 0;
    
    final debtCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM debts')
    ) ?? 0;
    
    final pendingOpsCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM pending_operations')
    ) ?? 0;

    return {
      'transactions': transactionCount,
      'reminders': reminderCount,
      'debts': debtCount,
      'pending_operations': pendingOpsCount,
    };
  }

  /// Close database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
} 