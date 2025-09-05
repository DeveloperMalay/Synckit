import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../models/note_model.dart';
import '../models/sync_response.dart' hide SyncConflict;
import '../../domain/models/sync_conflict.dart';
import '../../presentation/widgets/conflict_resolution_dialog.dart'
    show ConflictResolution;
import 'package:uuid/uuid.dart';

class NotesRepository {
  final DioClient _dioClient;
  final AppDatabase _database;
  final SyncService _syncService;
  final _uuid = const Uuid();

  NotesRepository({
    DioClient? dioClient,
    AppDatabase? database,
    SyncService? syncService,
  }) : _dioClient = dioClient ?? DioClient(),
       _database = database ?? AppDatabase(),
       _syncService = syncService ?? SyncService();

  // Local database operations
  Future<List<Note>> getLocalNotes() async {
    return await _database.notesDao.getAllNotes();
  }

  Stream<List<Note>> watchLocalNotes() {
    return _database.notesDao.watchAllNotes();
  }

  Future<Note?> getLocalNoteById(String id) async {
    return await _database.notesDao.getNoteById(id);
  }

  Future<List<Note>> searchLocalNotes(String query) async {
    return await _database.notesDao.searchNotes(query);
  }

  // Create note (offline-first)
  Future<Note> createNote({
    required String title,
    required String content,
  }) async {
    final noteId = _uuid.v4();
    final now = DateTime.now();

    // Save to local database first
    await _database.notesDao.insertNote(
      NoteCompanion(
        id: Value(noteId),
        title: Value(title),
        content: Value(content),
        version: const Value(0),
        updatedAt: Value(now),
      ),
    );

    // Queue mutation for sync
    await _syncService.queueNoteCreation(
      noteId: noteId,
      title: title,
      content: content,
    );

    // Return the created note
    final note = await _database.notesDao.getNoteById(noteId);
    return note!;
  }

  // Update note (offline-first)
  Future<Note> updateNote({
    required String id,
    required String title,
    required String content,
  }) async {
    // Get current note to check version
    final currentNote = await _database.notesDao.getNoteById(id);
    if (currentNote == null) {
      throw Exception('Note not found');
    }

    // Update locally
    await _database.notesDao.updateNoteById(
      id,
      NoteCompanion(
        title: Value(title),
        content: Value(content),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Queue mutation for sync
    await _syncService.queueNoteUpdate(
      noteId: id,
      title: title,
      content: content,
      currentVersion: currentNote.version,
    );

    // Return updated note
    final updatedNote = await _database.notesDao.getNoteById(id);
    return updatedNote!;
  }

  // Delete note (offline-first)
  Future<void> deleteNote(String id) async {
    // Delete locally
    await _database.notesDao.deleteNoteById(id);

    // Queue mutation for sync
    await _syncService.queueNoteDeletion(id);
  }

  // Sync with server
  Future<SyncResponse> syncWithServer() async {
    try {
      // First, process any pending mutations
      final mutationResults = await _processPendingMutations();

      // Get all local notes for sync
      final localNotes = await _database.notesDao.getAllNotes();

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

      // Send to server sync endpoint
      final response = await _dioClient.post(
        '/notes/sync',
        data: {'changes': changes},
      );

      final syncResponse = SyncResponse.fromJson(
        response.data as Map<String, dynamic>?,
      );

      // Process applied changes
      for (final appliedNote in syncResponse.applied) {
        await _database.notesDao.upsertNote(
          NoteCompanion(
            id: Value(appliedNote.id),
            title: Value(appliedNote.title),
            content: Value(appliedNote.content),
            version: Value(appliedNote.version),
            updatedAt: Value(appliedNote.updatedAt),
          ),
        );
      }

      // Handle conflicts - automatically resolve by taking server version
      for (final conflict in syncResponse.conflicts) {
        // Update local version to match server to prevent repeated conflicts
        await _database.notesDao.upsertNote(
          NoteCompanion(
            id: Value(conflict.id),
            title: Value(conflict.serverData.title),
            content: Value(conflict.serverData.content),
            version: Value(conflict.serverVersion),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      return syncResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Process pending mutations
  Future<List<MutationResult>> _processPendingMutations() async {
    final mutations = await _database.mutationsDao.getPendingMutationsInOrder();
    final results = <MutationResult>[];

    for (final mutation in mutations) {
      try {
        final payload = _database.mutationsDao.parsePayload(mutation);

        Response response;
        switch (mutation.method) {
          case 'POST':
            response = await _dioClient.post(mutation.endpoint, data: payload);
            break;
          case 'PUT':
            response = await _dioClient.put(mutation.endpoint, data: payload);
            break;
          case 'DELETE':
            response = await _dioClient.delete(mutation.endpoint);
            break;
          default:
            throw Exception('Unsupported method: ${mutation.method}');
        }

        // If successful, delete the mutation
        await _database.mutationsDao.deleteMutation(mutation.id);

        // Update local note with server response if applicable
        if (response.data != null &&
            response.data is Map &&
            response.data['id'] != null) {
          final noteData = response.data as Map<String, dynamic>;
          await _database.notesDao.upsertNote(
            NoteCompanion(
              id: Value(noteData['id'] as String),
              title: Value(noteData['title'] as String? ?? ''),
              content: Value(noteData['content'] as String? ?? ''),
              version: Value(noteData['version'] as int? ?? 0),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }

        results.add(MutationResult(mutationId: mutation.id, success: true));
      } catch (error) {
        results.add(
          MutationResult(
            mutationId: mutation.id,
            success: false,
            error: error.toString(),
          ),
        );
      }
    }

    return results;
  }

  // Fetch notes from server and update local database
  Future<List<Note>> fetchAndStoreNotes() async {
    try {
      final response = await _dioClient.get('/notes');

      final notes =
          (response.data as List)
              .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
              .toList();

      // Update local database
      for (final note in notes) {
        await _database.notesDao.upsertNote(
          NoteCompanion(
            id: Value(note.id),
            title: Value(note.title),
            content: Value(note.content),
            version: Value(note.version),
            updatedAt: Value(note.updatedAt),
          ),
        );
      }

      return await _database.notesDao.getAllNotes();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get pending mutations count
  Future<int> getPendingMutationsCount() async {
    return await _database.mutationsDao.countPendingMutations();
  }

  // Check if there are pending mutations
  Future<bool> hasPendingMutations() async {
    return await _syncService.hasPendingMutations();
  }

  // Clear all local data
  Future<void> clearAllData() async {
    await _database.clearAllData();
  }

  // Resolve conflicts for notes
  Future<void> resolveConflicts(
    Map<String, ConflictResolution> resolutions,
    List<SyncConflict> conflicts,
  ) async {
    for (final entry in resolutions.entries) {
      final noteId = entry.key;
      final resolution = entry.value;

      // Find the conflict for this note
      final conflict = conflicts.firstWhere((c) => c.id == noteId);

      switch (resolution) {
        case ConflictResolution.keepLocal:
          // Keep local version - queue an update to sync
          if (conflict.localVersion != null) {
            await _syncService.queueNoteUpdate(
              noteId: noteId,
              title: conflict.localData.title,
              content: conflict.localData.content,
              currentVersion: conflict.serverVersion,
            );
          }
          break;

        case ConflictResolution.keepServer:
          // Keep server version - update local database
          await _database.notesDao.upsertNote(
            NoteCompanion(
              id: Value(noteId),
              title: Value(conflict.serverData.title),
              content: Value(conflict.serverData.content),
              version: Value(conflict.serverVersion),
              updatedAt: Value(conflict.serverData.updatedAt),
            ),
          );
          break;

        case ConflictResolution.merge:
          // Merge both versions - combine content
          final mergedTitle = conflict.localData.title;
          final mergedContent = _mergeContent(
            conflict.localData.content,
            conflict.serverData.content,
          );

          // Update local database with merged content
          await _database.notesDao.upsertNote(
            NoteCompanion(
              id: Value(noteId),
              title: Value(mergedTitle),
              content: Value(mergedContent),
              version: Value(conflict.serverVersion),
              updatedAt: Value(DateTime.now()),
            ),
          );

          // Queue update to sync merged content
          await _syncService.queueNoteUpdate(
            noteId: noteId,
            title: mergedTitle,
            content: mergedContent,
            currentVersion: conflict.serverVersion,
          );
          break;
      }
    }
  }

  String _mergeContent(String localContent, String serverContent) {
    // Simple merge strategy: combine both with clear separation
    if (localContent.isEmpty) return serverContent;
    if (serverContent.isEmpty) return localContent;
    if (localContent == serverContent) return localContent;

    return '''=== Local Version ===
$localContent

=== Server Version ===
$serverContent

=== Merged ===
$localContent
$serverContent''';
  }

  String _handleError(DioException error) {
    if (error.response?.data != null && error.response?.data['error'] != null) {
      return error.response!.data['error'];
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Data saved locally.';
      case DioExceptionType.connectionError:
        return 'No connection. Changes will sync when online.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

class MutationResult {
  final String mutationId;
  final bool success;
  final String? error;

  MutationResult({required this.mutationId, required this.success, this.error});
}
