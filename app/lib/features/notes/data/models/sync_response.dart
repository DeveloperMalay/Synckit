import 'package:equatable/equatable.dart';
import 'note_model.dart';
import '../../domain/models/sync_conflict.dart';

class SyncResponse extends Equatable {
  final List<NoteModel> applied;
  final List<SyncConflict> conflicts;
  
  const SyncResponse({
    required this.applied,
    required this.conflicts,
  });
  
  factory SyncResponse.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SyncResponse(applied: [], conflicts: []);
    }
    
    return SyncResponse(
      applied: (json['applied'] as List<dynamic>? ?? [])
          .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      conflicts: (json['conflicts'] as List<dynamic>? ?? [])
          .map((e) => SyncConflict.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  
  @override
  List<Object?> get props => [applied, conflicts];
}