import '../services/storage_service.dart';

/// Combines Firestore rows for [month] with local rows that are not synced yet.
Future<List<Map<String, dynamic>>> mergeFirebaseMonthWithPendingLocal(
  List<Map<String, dynamic>> remoteDocs,
  DateTime month,
) async {
  final locals = await StorageService.getLocalTransactions(month);
  final pending =
      locals.where((t) => (t['pendingSync'] as bool?) == true).toList();
  final remote = remoteDocs.map((t) {
    final m = Map<String, dynamic>.from(t);
    m['pendingSync'] = false;
    return m;
  }).toList();
  final merged = [...pending, ...remote];
  merged.sort((a, b) {
    final da = DateTime.tryParse(a['date']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final db = DateTime.tryParse(b['date']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  });
  return merged;
}
