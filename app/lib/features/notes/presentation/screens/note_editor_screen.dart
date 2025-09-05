import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/notes_bloc.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({
    super.key,
    this.note,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get _isNewNote => widget.note == null;

  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some content to your note'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    if (_isNewNote) {
      context.read<NotesBloc>().add(
            AddNote(
              title: title.isEmpty ? 'Untitled Note' : title,
              content: content,
            ),
          );
    } else {
      context.read<NotesBloc>().add(
            UpdateNote(
              id: widget.note!.id,
              title: title.isEmpty ? 'Untitled Note' : title,
              content: content,
              currentVersion: widget.note!.version,
            ),
          );
    }

    // Pop after a short delay to show the saving state
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNewNote ? 'New Note' : 'Edit Note'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isSaving ? null : _saveNote,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
          ],
        ),
        body: BlocListener<NotesBloc, NotesState>(
          listener: (context, state) {
            if (state is NotesError) {
              setState(() {
                _isSaving = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Column(
            children: [
              // Note metadata
              if (!_isNewNote)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Version ${widget.note!.version}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Modified: ${_formatDate(widget.note!.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const Spacer(),
                      if (widget.note!.version == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Not synced',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                    ],
                  ),
                ),
              
              // Editor fields
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Title field
                      TextField(
                        controller: _titleController,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        decoration: const InputDecoration(
                          hintText: 'Note Title',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 1,
                      ),
                      const Divider(height: 32),
                      
                      // Content field
                      Expanded(
                        child: TextField(
                          controller: _contentController,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Start typing your note...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Character count
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_contentController.text.length} characters',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${_contentController.text.split(' ').where((word) => word.isNotEmpty).length} words',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _hasChanges
            ? FloatingActionButton(
                onPressed: _isSaving ? null : _saveNote,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.save),
              )
            : null,
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