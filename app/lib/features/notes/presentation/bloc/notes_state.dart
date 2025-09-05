part of 'notes_bloc.dart';

abstract class NotesState extends Equatable {
  const NotesState();

  @override
  List<Object?> get props => [];
}

class NotesInitial extends NotesState {
  const NotesInitial();
}

class NotesLoading extends NotesState {
  const NotesLoading();
}

class NotesLoaded extends NotesState {
  final List<Note> notes;
  final bool isSyncing;
  final int pendingMutations;
  final DateTime? lastSyncTime;

  const NotesLoaded({
    required this.notes,
    this.isSyncing = false,
    this.pendingMutations = 0,
    this.lastSyncTime,
  });

  NotesLoaded copyWith({
    List<Note>? notes,
    bool? isSyncing,
    int? pendingMutations,
    DateTime? lastSyncTime,
  }) {
    return NotesLoaded(
      notes: notes ?? this.notes,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingMutations: pendingMutations ?? this.pendingMutations,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  @override
  List<Object?> get props => [notes, isSyncing, pendingMutations, lastSyncTime];
}

class NotesError extends NotesState {
  final String message;
  final List<Note>? cachedNotes;

  const NotesError({
    required this.message,
    this.cachedNotes,
  });

  @override
  List<Object?> get props => [message, cachedNotes];
}

class NotesSyncSuccess extends NotesState {
  final int syncedCount;
  final int conflictCount;
  final List<SyncConflict> conflicts;
  final List<Note> notes;

  const NotesSyncSuccess({
    required this.syncedCount,
    required this.conflictCount,
    required this.conflicts,
    required this.notes,
  });

  @override
  List<Object?> get props => [syncedCount, conflictCount, conflicts, notes];
}

class NoteOperationSuccess extends NotesState {
  final String message;
  final List<Note> notes;

  const NoteOperationSuccess({
    required this.message,
    required this.notes,
  });

  @override
  List<Object?> get props => [message, notes];
}