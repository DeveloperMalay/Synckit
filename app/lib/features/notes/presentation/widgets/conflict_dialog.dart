import 'package:flutter/material.dart';
import 'package:synckit_app/features/notes/domain/models/sync_conflict.dart';

class ConflictDialog extends StatefulWidget {
  final SyncConflict conflict;
  final String localTitle;
  final String localContent;
  final Function(ConflictResolution) onResolved;

  const ConflictDialog({
    super.key,
    required this.conflict,
    required this.localTitle,
    required this.localContent,
    required this.onResolved,
  });

  @override
  State<ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<ConflictDialog> {
  ConflictResolution? _selectedResolution;
  bool _showComparison = false;

  @override
  Widget build(BuildContext context) {
    final serverTitle = widget.conflict.serverData.title as String? ?? '';
    final serverContent = widget.conflict.serverData.content as String? ?? '';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sync_problem, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(child: Text('Sync Conflict Detected')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This note has been modified on both the server and locally.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Version information
            Card(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Version Info',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(
                            _showComparison
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onPressed: () {
                            setState(() {
                              _showComparison = !_showComparison;
                            });
                          },
                          tooltip:
                              _showComparison
                                  ? 'Hide comparison'
                                  : 'Show comparison',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Your version: ${widget.conflict.localVersion}'),
                    Text('Server version: ${widget.conflict.serverVersion}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Resolution options
            Text(
              'Choose which version to keep:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Local version option
            _buildVersionOption(
              context,
              resolution: ConflictResolution.keepLocal,
              icon: Icons.phone_android,
              title: 'Keep Local Version',
              subtitle: 'Use your changes',
              color: Colors.blue,
            ),
            const SizedBox(height: 8),

            // Server version option
            _buildVersionOption(
              context,
              resolution: ConflictResolution.keepServer,
              icon: Icons.cloud,
              title: 'Keep Server Version',
              subtitle: 'Use server changes',
              color: Colors.green,
            ),
            const SizedBox(height: 8),

            // Merge option
            _buildVersionOption(
              context,
              resolution: ConflictResolution.merge,
              icon: Icons.merge_type,
              title: 'Merge Both',
              subtitle: 'Combine both versions',
              color: Colors.purple,
            ),

            // Show comparison
            if (_showComparison) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildComparison(context, serverTitle, serverContent),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _selectedResolution != null
                  ? () {
                    Navigator.pop(context);
                    widget.onResolved(_selectedResolution!);
                  }
                  : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildVersionOption(
    BuildContext context, {
    required ConflictResolution resolution,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedResolution == resolution;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedResolution = resolution;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildComparison(
    BuildContext context,
    String serverTitle,
    String serverContent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version Comparison',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Local version
        _buildVersionPreview(
          context,
          label: 'Local Version',
          title: widget.localTitle,
          content: widget.localContent,
          color: Colors.blue,
        ),
        const SizedBox(height: 12),

        // Server version
        _buildVersionPreview(
          context,
          label: 'Server Version',
          title: serverTitle,
          content: serverContent,
          color: Colors.green,
        ),

        // Merge preview
        if (_selectedResolution == ConflictResolution.merge) ...[
          const SizedBox(height: 12),
          _buildVersionPreview(
            context,
            label: 'Merged Version (Preview)',
            title:
                widget.localTitle.isNotEmpty ? widget.localTitle : serverTitle,
            content: _mergeContent(widget.localContent, serverContent),
            color: Colors.purple,
          ),
        ],
      ],
    );
  }

  Widget _buildVersionPreview(
    BuildContext context, {
    required String label,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title.isEmpty ? 'Untitled' : title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            content.isEmpty ? 'No content' : content,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _mergeContent(String local, String server) {
    if (local == server) {
      return local;
    }

    if (local.isEmpty) {
      return server;
    }

    if (server.isEmpty) {
      return local;
    }

    // Simple merge strategy: combine both with separator
    return '=== Local Version ===\n$local\n\n=== Server Version ===\n$server';
  }
}

enum ConflictResolution { keepLocal, keepServer, merge }

// Helper function to show conflict dialog
Future<ConflictResolution?> showConflictDialog({
  required BuildContext context,
  required SyncConflict conflict,
  required String localTitle,
  required String localContent,
}) async {
  return await showDialog<ConflictResolution>(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => ConflictDialog(
          conflict: conflict,
          localTitle: localTitle,
          localContent: localContent,
          onResolved: (resolution) {
            Navigator.pop(context, resolution);
          },
        ),
  );
}
