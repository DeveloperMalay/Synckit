import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/notes_bloc.dart';
import 'note_editor_screen.dart';
import '../widgets/conflict_resolution_dialog.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load notes when screen opens
    context.read<NotesBloc>().add(const LoadNotes());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          BlocBuilder<NotesBloc, NotesState>(
            builder: (context, state) {
              if (state is NotesLoaded && state.pendingMutations > 0) {
                return IconButton(
                  icon: Badge(
                    label: Text('${state.pendingMutations}'),
                    child: const Icon(Icons.sync),
                  ),
                  onPressed: () {
                    context.read<NotesBloc>().add(const SyncNotes());
                  },
                  tooltip: 'Sync pending changes',
                );
              }
              if (state is NotesLoaded && state.isSyncing) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.sync),
                onPressed: () {
                  context.read<NotesBloc>().add(const SyncNotes());
                },
                tooltip: 'Sync notes',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            context.read<NotesBloc>().add(
                              const SearchNotes(query: ''),
                            );
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
              ),
              onChanged: (query) {
                context.read<NotesBloc>().add(SearchNotes(query: query));
              },
            ),
          ),

          // Notes list
          Expanded(
            child: BlocConsumer<NotesBloc, NotesState>(
              listener: (context, state) {
                if (state is NotesError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                      action:
                          state.cachedNotes != null
                              ? SnackBarAction(
                                label: 'Retry',
                                onPressed: () {
                                  context.read<NotesBloc>().add(
                                    const SyncNotes(),
                                  );
                                },
                              )
                              : null,
                    ),
                  );
                }

                if (state is NoteOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }

                if (state is NotesSyncSuccess) {
                  if (state.conflictCount > 0) {
                    _showConflictsSummary(context, state);
                  } else if (state.syncedCount > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Synced ${state.syncedCount} notes'),
                        backgroundColor: Colors.blue,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              builder: (context, state) {
                if (state is NotesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is NotesError && state.cachedNotes == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading notes',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.message,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<NotesBloc>().add(const LoadNotes());
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final notes = _getNotesFromState(state);

                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No notes found'
                              : 'No notes yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Try searching with different keywords'
                              : 'Tap + to create your first note',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<NotesBloc>().add(const SyncNotes());
                    await Future.delayed(const Duration(seconds: 2));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _NoteCard(
                        note: note,
                        onTap: () => _navigateToEditor(context, note),
                        onDelete: () => _deleteNote(context, note),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }

  List<Note> _getNotesFromState(NotesState state) {
    if (state is NotesLoaded) {
      return state.notes;
    } else if (state is NotesError && state.cachedNotes != null) {
      return state.cachedNotes!;
    } else if (state is NoteOperationSuccess) {
      return state.notes;
    } else if (state is NotesSyncSuccess) {
      return state.notes;
    }
    return [];
  }

  void _navigateToEditor(BuildContext context, Note? note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorScreen(note: note)),
    );
  }

  void _deleteNote(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Note'),
            content: Text('Are you sure you want to delete "${note.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.read<NotesBloc>().add(DeleteNote(id: note.id));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showConflictsSummary(BuildContext context, NotesSyncSuccess state) {
    // If there are conflicts, show the resolution dialog
    if (state.conflicts.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => ConflictResolutionDialog(
              conflicts: state.conflicts,
              onResolve: (resolutions) {
                // Handle conflict resolutions
                context.read<NotesBloc>().add(
                  ResolveConflicts(resolutions: resolutions),
                );
              },
            ),
      );
    } else {
      // Show simple summary if no detailed conflicts
      showDialog(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Sync Conflicts'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${state.conflictCount} conflicts found during sync.'),
                  const SizedBox(height: 8),
                  const Text(
                    'Server version was kept for conflicting notes.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled Note' : note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.version == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        onTap();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.content.isEmpty ? 'No content' : note.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(note.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'v${note.version}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
