import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/dao/notes_dao.dart';
import '../database/dao/mutations_dao.dart';

class SyncService {
  final AppDatabase _database;
  late final NotesDao _notesDao;
  late final MutationsDao _mutationsDao;

  SyncService({AppDatabase? database}) : _database = database ?? AppDatabase() {
    _notesDao = _database.notesDao;
    _mutationsDao = _database.mutationsDao;
  }

  // Queue a note creation mutation
  Future<void> queueNoteCreation({
    required String noteId,
    required String title,
    required String content,
  }) async {
    // Save note locally with version 0
    await _notesDao.upsertNote(
      NoteCompanion(
        id: Value(noteId),
        title: Value(title),
        content: Value(content),
        version: const Value(0),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Queue mutation for sync
    await _mutationsDao.queueMutation(
      id: 'create_$noteId',
      endpoint: '/notes',
      method: 'POST',
      payload: {'id': noteId, 'title': title, 'content': content},
    );
  }

  // Queue a note update mutation
  Future<void> queueNoteUpdate({
    required String noteId,
    required String title,
    required String content,
    required int currentVersion,
  }) async {
    // Update note locally
    await _notesDao.updateNoteById(
      noteId,
      NoteCompanion(
        title: Value(title),
        content: Value(content),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Queue mutation for sync
    await _mutationsDao.queueMutation(
      id: 'update_$noteId',
      endpoint: '/notes/$noteId',
      method: 'PUT',
      payload: {
        'title': title,
        'content': content,
        'baseVersion': currentVersion,
      },
    );
  }

  // Queue a note deletion mutation
  Future<void> queueNoteDeletion(String noteId) async {
    // Delete note locally
    await _notesDao.deleteNoteById(noteId);

    // Queue mutation for sync
    await _mutationsDao.queueMutation(
      id: 'delete_$noteId',
      endpoint: '/notes/$noteId',
      method: 'DELETE',
      payload: {},
    );
  }

  // Process all pending mutations
  Future<List<SyncResult>> processPendingMutations() async {
    final mutations = await _mutationsDao.getPendingMutationsInOrder();
    final results = <SyncResult>[];

    for (final mutation in mutations) {
      try {
        // TODO: Send mutation to server using DioClient
        // For now, just simulate success
        await Future.delayed(const Duration(milliseconds: 100));

        // If successful, delete the mutation
        await _mutationsDao.deleteMutation(mutation.id);

        results.add(SyncResult(mutationId: mutation.id, success: true));
      } catch (error) {
        results.add(
          SyncResult(
            mutationId: mutation.id,
            success: false,
            error: error.toString(),
          ),
        );
      }
    }

    return results;
  }

  // Sync notes with server
  Future<SyncStatus> syncNotes() async {
    try {
      // First, process pending mutations
      final mutationResults = await processPendingMutations();

      // Get all local notes for sync
      final localNotes = await _notesDao.getAllNotes();

      // Prepare changes for sync endpoint
      final changes =
          localNotes
              .map(
                (note) => {
                  'id': note.id,
                  'title': note.title,
                  'content': note.content,
                  'baseVersion': note.version,
                },
              )
              .toList();

      // TODO: Send to server /notes/sync endpoint
      // Parse response and handle conflicts

      return SyncStatus(
        success: true,
        syncedCount: localNotes.length,
        conflictCount: 0,
        pendingMutations: await _mutationsDao.countPendingMutations(),
      );
    } catch (error) {
      return SyncStatus(
        success: false,
        error: error.toString(),
        pendingMutations: await _mutationsDao.countPendingMutations(),
      );
    }
  }

  // Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    final noteCount = (await _notesDao.getAllNotes()).length;
    final pendingMutationCount = await _mutationsDao.countPendingMutations();
    final mutations = await _mutationsDao.getAllPendingMutations();

    return SyncStatistics(
      totalNotes: noteCount,
      pendingMutations: pendingMutationCount,
      mutationsByType: {
        'POST': mutations.where((m) => m.method == 'POST').length,
        'PUT': mutations.where((m) => m.method == 'PUT').length,
        'DELETE': mutations.where((m) => m.method == 'DELETE').length,
      },
    );
  }

  // Clear all pending mutations
  Future<void> clearPendingMutations() async {
    await _mutationsDao.deleteAllMutations();
  }

  // Check if there are pending mutations
  Future<bool> hasPendingMutations() async {
    final count = await _mutationsDao.countPendingMutations();
    return count > 0;
  }
}

class SyncResult {
  final String mutationId;
  final bool success;
  final String? error;

  SyncResult({required this.mutationId, required this.success, this.error});
}

class SyncStatus {
  final bool success;
  final int syncedCount;
  final int conflictCount;
  final int pendingMutations;
  final String? error;

  SyncStatus({
    required this.success,
    this.syncedCount = 0,
    this.conflictCount = 0,
    this.pendingMutations = 0,
    this.error,
  });
}

class SyncStatistics {
  final int totalNotes;
  final int pendingMutations;
  final Map<String, int> mutationsByType;

  SyncStatistics({
    required this.totalNotes,
    required this.pendingMutations,
    required this.mutationsByType,
  });
}
