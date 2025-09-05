import 'dart:convert';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/pending_mutations_table.dart';

part 'mutations_dao.g.dart';

@DriftAccessor(tables: [PendingMutations])
class MutationsDao extends DatabaseAccessor<AppDatabase> with _$MutationsDaoMixin {
  MutationsDao(AppDatabase db) : super(db);
  
  // Queue a new mutation
  Future<void> queueMutation({
    required String id,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    await into(pendingMutations).insert(
      PendingMutationCompanion(
        id: Value(id),
        endpoint: Value(endpoint),
        method: Value(method),
        payload: Value(jsonEncode(payload)),
      ),
    );
  }
  
  // Get all pending mutations
  Future<List<PendingMutation>> getAllPendingMutations() =>
      select(pendingMutations).get();
  
  // Get pending mutations in order (oldest first)
  Future<List<PendingMutation>> getPendingMutationsInOrder() =>
      (select(pendingMutations)
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
  
  // Get next mutation to process
  Future<PendingMutation?> getNextMutation() =>
      (select(pendingMutations)
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
        ..limit(1))
          .getSingleOrNull();
  
  // Delete mutation after successful sync
  Future<int> deleteMutation(String id) =>
      (delete(pendingMutations)..where((m) => m.id.equals(id))).go();
  
  // Delete all mutations
  Future<int> deleteAllMutations() => delete(pendingMutations).go();
  
  // Count pending mutations
  Future<int> countPendingMutations() async {
    final count = await customSelect(
      'SELECT COUNT(*) as count FROM pending_mutations',
      readsFrom: {pendingMutations},
    ).getSingleOrNull();
    
    return count?.data['count'] as int? ?? 0;
  }
  
  // Get mutations by endpoint
  Future<List<PendingMutation>> getMutationsByEndpoint(String endpoint) =>
      (select(pendingMutations)..where((m) => m.endpoint.equals(endpoint)))
          .get();
  
  // Get mutations by method
  Future<List<PendingMutation>> getMutationsByMethod(String method) =>
      (select(pendingMutations)..where((m) => m.method.equals(method)))
          .get();
  
  // Batch delete mutations
  Future<void> deleteMutations(List<String> ids) async {
    await batch((batch) {
      for (final id in ids) {
        batch.deleteWhere(pendingMutations, (m) => m.id.equals(id));
      }
    });
  }
  
  // Clear old mutations (older than specified days)
  Future<int> clearOldMutations(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    return (delete(pendingMutations)
      ..where((m) => m.createdAt.isSmallerThanValue(cutoffDate)))
        .go();
  }
  
  // Check if mutation exists
  Future<bool> mutationExists(String id) async {
    final result = await (select(pendingMutations)
      ..where((m) => m.id.equals(id)))
        .getSingleOrNull();
    return result != null;
  }
  
  // Parse payload from mutation
  Map<String, dynamic> parsePayload(PendingMutation mutation) {
    try {
      return jsonDecode(mutation.payload) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}