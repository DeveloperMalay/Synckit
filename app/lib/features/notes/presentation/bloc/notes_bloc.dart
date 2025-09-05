import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/notes_repository.dart';
import '../../domain/models/sync_conflict.dart';
import '../../data/models/sync_response.dart' hide SyncConflict;
import '../widgets/conflict_resolution_dialog.dart' show ConflictResolution;

part 'notes_event.dart';
part 'notes_state.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  final NotesRepository _notesRepository;
  StreamSubscription<List<Note>>? _notesSubscription;
  Timer? _syncTimer;

  NotesBloc({
    NotesRepository? notesRepository,
  })  : _notesRepository = notesRepository ?? NotesRepository(),
        super(const NotesInitial()) {
    on<LoadNotes>(_onLoadNotes);
    on<WatchNotes>(_onWatchNotes);
    on<AddNote>(_onAddNote);
    on<UpdateNote>(_onUpdateNote);
    on<DeleteNote>(_onDeleteNote);
    on<SyncNotes>(_onSyncNotes);
    on<SearchNotes>(_onSearchNotes);
    on<ResolveConflicts>(_onResolveConflicts);
    
    // Register internal event handlers
    on<_NotesUpdated>((event, emit) {
      if (state is NotesLoaded) {
        emit((state as NotesLoaded).copyWith(
          notes: event.notes,
          pendingMutations: event.pendingMutations,
        ));
      } else {
        emit(NotesLoaded(
          notes: event.notes,
          pendingMutations: event.pendingMutations,
        ));
      }
    });
    
    on<_NotesError>((event, emit) {
      emit(NotesError(message: event.message));
    });

    // Start watching notes immediately
    add(const WatchNotes());
    
    // Set up periodic sync (every 30 seconds)
    _setupPeriodicSync();
  }

  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state is NotesLoaded && !(state as NotesLoaded).isSyncing) {
        add(const SyncNotes());
      }
    });
  }

  Future<void> _onLoadNotes(
    LoadNotes event,
    Emitter<NotesState> emit,
  ) async {
    emit(const NotesLoading());

    try {
      final notes = await _notesRepository.getLocalNotes();
      final pendingMutations = await _notesRepository.getPendingMutationsCount();

      emit(NotesLoaded(
        notes: notes,
        pendingMutations: pendingMutations,
      ));
    } catch (error) {
      emit(NotesError(message: error.toString()));
    }
  }

  Future<void> _onWatchNotes(
    WatchNotes event,
    Emitter<NotesState> emit,
  ) async {
    emit(const NotesLoading());

    await _notesSubscription?.cancel();
    _notesSubscription = _notesRepository.watchLocalNotes().listen(
      (notes) async {
        final pendingMutations = await _notesRepository.getPendingMutationsCount();
        
        if (!isClosed) {
          add(_NotesUpdated(notes: notes, pendingMutations: pendingMutations));
        }
      },
      onError: (error) {
        if (!isClosed) {
          add(_NotesError(message: error.toString()));
        }
      },
    );

    // Load initial data
    try {
      final notes = await _notesRepository.getLocalNotes();
      final pendingMutations = await _notesRepository.getPendingMutationsCount();

      emit(NotesLoaded(
        notes: notes,
        pendingMutations: pendingMutations,
      ));
    } catch (error) {
      emit(NotesError(message: error.toString()));
    }
  }

  Future<void> _onAddNote(
    AddNote event,
    Emitter<NotesState> emit,
  ) async {
    try {
      if (state is! NotesLoaded) return;

      final currentState = state as NotesLoaded;
      
      // Create note (offline-first)
      final newNote = await _notesRepository.createNote(
        title: event.title,
        content: event.content,
      );

      // Update state with new note
      final updatedNotes = List<Note>.from(currentState.notes)..insert(0, newNote);
      final pendingMutations = await _notesRepository.getPendingMutationsCount();

      emit(NoteOperationSuccess(
        message: 'Note added successfully',
        notes: updatedNotes,
      ));

      emit(currentState.copyWith(
        notes: updatedNotes,
        pendingMutations: pendingMutations,
      ));

      // Trigger sync in background
      add(const SyncNotes());
    } catch (error) {
      emit(NotesError(
        message: 'Failed to add note: ${error.toString()}',
        cachedNotes: state is NotesLoaded ? (state as NotesLoaded).notes : null,
      ));
    }
  }

  Future<void> _onUpdateNote(
    UpdateNote event,
    Emitter<NotesState> emit,
  ) async {
    try {
      if (state is! NotesLoaded) return;

      final currentState = state as NotesLoaded;

      // Update note (offline-first)
      final updatedNote = await _notesRepository.updateNote(
        id: event.id,
        title: event.title,
        content: event.content,
      );

      // Update state
      final updatedNotes = currentState.notes.map((note) {
        return note.id == event.id ? updatedNote : note;
      }).toList();

      final pendingMutations = await _notesRepository.getPendingMutationsCount();

      emit(NoteOperationSuccess(
        message: 'Note updated successfully',
        notes: updatedNotes,
      ));

      emit(currentState.copyWith(
        notes: updatedNotes,
        pendingMutations: pendingMutations,
      ));

      // Trigger sync in background
      add(const SyncNotes());
    } catch (error) {
      emit(NotesError(
        message: 'Failed to update note: ${error.toString()}',
        cachedNotes: state is NotesLoaded ? (state as NotesLoaded).notes : null,
      ));
    }
  }

  Future<void> _onDeleteNote(
    DeleteNote event,
    Emitter<NotesState> emit,
  ) async {
    try {
      if (state is! NotesLoaded) return;

      final currentState = state as NotesLoaded;

      // Delete note (offline-first)
      await _notesRepository.deleteNote(event.id);

      // Update state
      final updatedNotes = currentState.notes
          .where((note) => note.id != event.id)
          .toList();

      final pendingMutations = await _notesRepository.getPendingMutationsCount();

      emit(NoteOperationSuccess(
        message: 'Note deleted successfully',
        notes: updatedNotes,
      ));

      emit(currentState.copyWith(
        notes: updatedNotes,
        pendingMutations: pendingMutations,
      ));

      // Trigger sync in background
      add(const SyncNotes());
    } catch (error) {
      emit(NotesError(
        message: 'Failed to delete note: ${error.toString()}',
        cachedNotes: state is NotesLoaded ? (state as NotesLoaded).notes : null,
      ));
    }
  }

  Future<void> _onSyncNotes(
    SyncNotes event,
    Emitter<NotesState> emit,
  ) async {
    if (state is! NotesLoaded) return;

    final currentState = state as NotesLoaded;

    // Don't sync if already syncing
    if (currentState.isSyncing) return;

    emit(currentState.copyWith(isSyncing: true));

    try {
      // Perform sync
      final syncResponse = await _notesRepository.syncWithServer();

      // Reload notes after sync
      final notes = await _notesRepository.getLocalNotes();
      final pendingMutations = await _notesRepository.getPendingMutationsCount();

      // Show sync success state briefly
      emit(NotesSyncSuccess(
        syncedCount: syncResponse.applied.length,
        conflictCount: syncResponse.conflicts.length,
        conflicts: syncResponse.conflicts,
        notes: notes,
      ));

      // Return to loaded state
      emit(NotesLoaded(
        notes: notes,
        pendingMutations: pendingMutations,
        lastSyncTime: DateTime.now(),
      ));
    } catch (error) {
      // Sync failed but keep showing local data
      emit(currentState.copyWith(
        isSyncing: false,
      ));
      
      // Only show error briefly, don't disrupt the UI
      if (error.toString().contains('Connection')) {
        // Silent fail for connection errors (offline mode)
      } else {
        emit(NotesError(
          message: 'Sync failed: ${error.toString()}',
          cachedNotes: currentState.notes,
        ));
        
        // Restore previous state
        emit(currentState.copyWith(isSyncing: false));
      }
    }
  }

  Future<void> _onSearchNotes(
    SearchNotes event,
    Emitter<NotesState> emit,
  ) async {
    if (state is! NotesLoaded) return;

    final currentState = state as NotesLoaded;

    try {
      final searchResults = event.query.isEmpty
          ? await _notesRepository.getLocalNotes()
          : await _notesRepository.searchLocalNotes(event.query);

      emit(currentState.copyWith(notes: searchResults));
    } catch (error) {
      emit(NotesError(
        message: 'Search failed: ${error.toString()}',
        cachedNotes: currentState.notes,
      ));
    }
  }

  Future<void> _onResolveConflicts(
    ResolveConflicts event,
    Emitter<NotesState> emit,
  ) async {
    try {
      // Get the current conflicts from state
      List<SyncConflict> conflicts = [];
      if (state is NotesSyncSuccess) {
        conflicts = (state as NotesSyncSuccess).conflicts;
      }
      
      if (conflicts.isEmpty) {
        // No conflicts to resolve
        return;
      }
      
      // Show loading state while resolving
      if (state is NotesLoaded) {
        emit((state as NotesLoaded).copyWith(isSyncing: true));
      }
      
      // Apply the resolutions
      await _notesRepository.resolveConflicts(event.resolutions, conflicts);
      
      // Get updated notes
      final updatedNotes = await _notesRepository.getLocalNotes();
      final pendingCount = await _notesRepository.getPendingMutationsCount();
      
      // Emit success state
      emit(NotesLoaded(
        notes: updatedNotes,
        pendingMutations: pendingCount,
        isSyncing: false,
      ));
      
      // If we have pending mutations after resolution, sync them
      if (pendingCount > 0) {
        add(const SyncNotes());
      }
    } catch (error) {
      // Handle error
      final currentNotes = state is NotesLoaded 
          ? (state as NotesLoaded).notes
          : <Note>[];
      
      emit(NotesError(
        message: 'Failed to resolve conflicts: ${error.toString()}',
        cachedNotes: currentNotes,
      ));
    }
  }

  @override
  Future<void> close() {
    _notesSubscription?.cancel();
    _syncTimer?.cancel();
    return super.close();
  }
}

// Internal events for stream updates
class _NotesUpdated extends NotesEvent {
  final List<Note> notes;
  final int pendingMutations;

  const _NotesUpdated({
    required this.notes,
    required this.pendingMutations,
  });

  @override
  List<Object?> get props => [notes, pendingMutations];
}

class _NotesError extends NotesEvent {
  final String message;

  const _NotesError({required this.message});

  @override
  List<Object?> get props => [message];
}