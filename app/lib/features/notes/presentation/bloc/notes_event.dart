part of 'notes_bloc.dart';

abstract class NotesEvent extends Equatable {
  const NotesEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotes extends NotesEvent {
  const LoadNotes();
}

class AddNote extends NotesEvent {
  final String title;
  final String content;

  const AddNote({
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [title, content];
}

class UpdateNote extends NotesEvent {
  final String id;
  final String title;
  final String content;
  final int currentVersion;

  const UpdateNote({
    required this.id,
    required this.title,
    required this.content,
    required this.currentVersion,
  });

  @override
  List<Object?> get props => [id, title, content, currentVersion];
}

class DeleteNote extends NotesEvent {
  final String id;

  const DeleteNote({required this.id});

  @override
  List<Object?> get props => [id];
}

class SyncNotes extends NotesEvent {
  const SyncNotes();
}

class WatchNotes extends NotesEvent {
  const WatchNotes();
}

class SearchNotes extends NotesEvent {
  final String query;

  const SearchNotes({required this.query});

  @override
  List<Object?> get props => [query];
}

class ResolveConflicts extends NotesEvent {
  final Map<String, ConflictResolution> resolutions;

  const ResolveConflicts({required this.resolutions});

  @override
  List<Object?> get props => [resolutions];
}