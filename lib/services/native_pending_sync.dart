import 'package:flutter/services.dart';
import 'firebase_service.dart';
import 'storage_service.dart';

/// Drains the Android Quick Add queue (`SharedPreferences`) into this app:
/// - Offline or on Firebase failure: rows in SQLite with `pendingSync` (cloud icon in UI).
/// - Online: uploads straight to Firebase when possible.
///
/// Uses a single in-flight [Future] so parallel callers (Home, Activity tab, …) wait on the same work.
class NativePendingSync {
  NativePendingSync._();

  static const MethodChannel _channel = MethodChannel('expenses.tracker/pending');
  static Future<void>? _inFlight;

  static DateTime _parseNativeDate(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now();
    final ms = int.tryParse(raw);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  static Future<void> syncQuickAddQueue() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  static Future<void> _run() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPending');
      if (result == null) return;

      final prefs = Map<String, dynamic>.from(result);
      final count = prefs['count'] as int? ?? 0;
      if (count == 0) return;

      await _channel.invokeMethod('clearPending');

      final firebaseService = FirebaseService();
      final online = await firebaseService.isConnected;

      for (var i = 1; i <= count; i++) {
        final type = prefs['txn_${i}_type'] as String? ?? 'expense';
        final amount =
            double.tryParse(prefs['txn_${i}_amount']?.toString() ?? '0') ?? 0;
        final category = prefs['txn_${i}_category'] as String? ?? 'Other';
        final note = prefs['txn_${i}_note'] as String? ?? '';
        if (amount <= 0) continue;

        final at = _parseNativeDate(prefs['txn_${i}_date']?.toString());
        final localPayload = {
          'type': type,
          'amount': amount.toString(),
          'category': category,
          'date': at.toIso8601String(),
          'accountId': '',
          'note': note,
          'createdAt': at.toIso8601String(),
        };

        if (online) {
          try {
            await firebaseService.addTransaction(
              type: type,
              amount: amount,
              category: category,
              date: at,
              accountId: '',
              note: note,
              clientCreatedAt: at,
            );
          } catch (_) {
            await StorageService.saveLocalTransaction(localPayload);
          }
        } else {
          await StorageService.saveLocalTransaction(localPayload);
        }
      }
    } catch (_) {}
  }
}
