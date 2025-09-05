import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/notes_table.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(AppDatabase db) : super(db);
  
  // Get all notes
  Future<List<Note>> getAllNotes() => select(notes).get();
  
  // Watch all notes (real-time updates)
  Stream<List<Note>> watchAllNotes() => select(notes).watch();
  
  // Get note by ID
  Future<Note?> getNoteById(String id) =>
      (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  
  // Insert new note
  Future<int> insertNote(NoteCompanion note) =>
      into(notes).insert(note);
  
  // Update existing note
  Future<bool> updateNote(Note note) =>
      update(notes).replace(note);
  
  // Update note with new data
  Future<int> updateNoteById(String id, NoteCompanion note) =>
      (update(notes)..where((n) => n.id.equals(id))).write(note);
  
  // Upsert note (insert or update)
  Future<void> upsertNote(NoteCompanion note) =>
      into(notes).insertOnConflictUpdate(note);
  
  // Batch upsert notes
  Future<void> upsertNotes(List<NoteCompanion> notesList) async {
    await batch((batch) {
      batch.insertAll(
        notes,
        notesList,
        mode: InsertMode.insertOrReplace,
      );
    });
  }
  
  // Delete note by ID
  Future<int> deleteNoteById(String id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();
  
  // Delete all notes
  Future<int> deleteAllNotes() => delete(notes).go();
  
  // Get notes that need syncing (version conflict detection)
  Future<List<Note>> getNotesForSync() =>
      select(notes).get();
  
  // Update note version after successful sync
  Future<void> updateNoteVersion(String id, int newVersion) async {
    await (update(notes)..where((n) => n.id.equals(id)))
      .write(NoteCompanion(
        version: Value(newVersion),
        updatedAt: Value(DateTime.now()),
      ));
  }
  
  // Search notes by title or content
  Future<List<Note>> searchNotes(String query) {
    return (select(notes)
      ..where((n) =>
          n.title.contains(query) |
          n.content.contains(query)))
        .get();
  }
  
  // Get notes modified after a specific date
  Future<List<Note>> getNotesModifiedAfter(DateTime date) =>
      (select(notes)..where((n) => n.updatedAt.isBiggerThanValue(date)))
          .get();
  
  // Get notes by version
  Future<List<Note>> getNotesByVersion(int version) =>
      (select(notes)..where((n) => n.version.equals(version))).get();
}