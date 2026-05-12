import 'package:flutter/material.dart';

/// Sort modes for transaction lists (Activity + monthly report).
enum TransactionListSort {
  dateNewest,
  dateOldest,
  amountHigh,
  amountLow,
  categoryAz,
}

extension TransactionListSortX on TransactionListSort {
  String get label {
    switch (this) {
      case TransactionListSort.dateNewest:
        return 'Date · Newest first';
      case TransactionListSort.dateOldest:
        return 'Date · Oldest first';
      case TransactionListSort.amountHigh:
        return 'Amount · High to low';
      case TransactionListSort.amountLow:
        return 'Amount · Low to high';
      case TransactionListSort.categoryAz:
        return 'Category · A–Z';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionListSort.dateNewest:
      case TransactionListSort.dateOldest:
        return Icons.calendar_today_rounded;
      case TransactionListSort.amountHigh:
      case TransactionListSort.amountLow:
        return Icons.payments_rounded;
      case TransactionListSort.categoryAz:
        return Icons.sort_by_alpha_rounded;
    }
  }
}

double _txnAmount(Map<String, dynamic> t) {
  final v = t['amount'];
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime _txnDate(Map<String, dynamic> t) {
  return DateTime.tryParse(t['date']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

void sortTransactions(
  List<Map<String, dynamic>> list,
  TransactionListSort sort,
) {
  switch (sort) {
    case TransactionListSort.dateNewest:
      list.sort((a, b) => _txnDate(b).compareTo(_txnDate(a)));
      break;
    case TransactionListSort.dateOldest:
      list.sort((a, b) => _txnDate(a).compareTo(_txnDate(b)));
      break;
    case TransactionListSort.amountHigh:
      list.sort((a, b) => _txnAmount(b).compareTo(_txnAmount(a)));
      break;
    case TransactionListSort.amountLow:
      list.sort((a, b) => _txnAmount(a).compareTo(_txnAmount(b)));
      break;
    case TransactionListSort.categoryAz:
      list.sort((a, b) {
        final ca = (a['category'] ?? '').toString().toLowerCase();
        final cb = (b['category'] ?? '').toString().toLowerCase();
        final c = ca.compareTo(cb);
        if (c != 0) return c;
        return _txnDate(b).compareTo(_txnDate(a));
      });
      break;
  }
}

List<String> distinctCategories(List<Map<String, dynamic>> transactions) {
  final set = <String>{};
  for (final t in transactions) {
    final c = t['category']?.toString();
    if (c != null && c.isNotEmpty) set.add(c);
  }
  final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}
