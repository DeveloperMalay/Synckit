import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables/notes_table.dart';
import 'tables/pending_mutations_table.dart';
import 'dao/notes_dao.dart';
import 'dao/mutations_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Notes, PendingMutations],
  daos: [NotesDao, MutationsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 2;
  
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Migration from version 1 to 2
          // Add pending_mutations table
          await m.createTable(pendingMutations);
          
          // Update notes table structure if needed
          // Since we removed some columns, we need to handle existing data
          await customStatement('DROP TABLE IF EXISTS users');
          await m.createTable(notes);
        }
      },
    );
  }
  
  // Convenience method to clear all data
  Future<void> clearAllData() async {
    await delete(notes).go();
    await delete(pendingMutations).go();
  }
  
  // Transaction helper for complex operations  
  Future<T> runTransaction<T>(Future<T> Function() action) async {
    return await transaction(() async {
      return await action();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'synckit.db'));
    
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;
    
    return NativeDatabase.createInBackground(file);
  });
}