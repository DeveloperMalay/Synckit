import 'package:flutter/material.dart';
import '../../domain/models/sync_conflict.dart';

enum ConflictResolution {
  keepLocal,
  keepServer,
  merge,
}

class ConflictResolutionDialog extends StatefulWidget {
  final List<SyncConflict> conflicts;
  final Function(Map<String, ConflictResolution>) onResolve;

  const ConflictResolutionDialog({
    Key? key,
    required this.conflicts,
    required this.onResolve,
  }) : super(key: key);

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  final Map<String, ConflictResolution> resolutions = {};

  @override
  void initState() {
    super.initState();
    // Default all conflicts to "keep server"
    for (final conflict in widget.conflicts) {
      resolutions[conflict.id] = ConflictResolution.keepServer;
    }
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

  Widget _buildVersionCard({
    required String title,
    required String content,
    required DateTime updatedAt,
    required int version,
    required Color backgroundColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: backgroundColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                '$title (v$version)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(updatedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              content.isEmpty ? '(empty)' : content,
              style: const TextStyle(fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionOption(
    String conflictId,
    ConflictResolution value,
    String label,
    String description,
    IconData icon,
  ) {
    final isSelected = resolutions[conflictId] == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          resolutions[conflictId] = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey[800],
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Radio<ConflictResolution>(
              value: value,
              groupValue: resolutions[conflictId],
              onChanged: (newValue) {
                setState(() {
                  resolutions[conflictId] = newValue!;
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange[700],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync Conflicts Detected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          '${widget.conflicts.length} note${widget.conflicts.length > 1 ? 's have' : ' has'} conflicting changes',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Conflicts list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                itemCount: widget.conflicts.length,
                itemBuilder: (context, index) {
                  final conflict = widget.conflicts[index];
                  return Card(
                    margin: EdgeInsets.only(
                      bottom: index < widget.conflicts.length - 1 ? 16 : 0,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Note title
                          Row(
                            children: [
                              Icon(
                                Icons.note_rounded,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  conflict.localData.title.isEmpty 
                                    ? 'Untitled Note' 
                                    : conflict.localData.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Version comparison
                          Row(
                            children: [
                              Expanded(
                                child: _buildVersionCard(
                                  title: 'Local',
                                  content: conflict.localData.content,
                                  updatedAt: conflict.localData.updatedAt,
                                  version: conflict.localVersion,
                                  backgroundColor: Colors.blue[50]!,
                                  icon: Icons.phone_android,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.compare_arrows,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildVersionCard(
                                  title: 'Server',
                                  content: conflict.serverData.content,
                                  updatedAt: conflict.serverData.updatedAt,
                                  version: conflict.serverVersion,
                                  backgroundColor: Colors.green[50]!,
                                  icon: Icons.cloud,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Resolution options
                          const Text(
                            'Choose resolution:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              _buildResolutionOption(
                                conflict.id,
                                ConflictResolution.keepLocal,
                                'Keep Local',
                                'Use your device\'s version',
                                Icons.phone_android,
                              ),
                              const SizedBox(height: 8),
                              _buildResolutionOption(
                                conflict.id,
                                ConflictResolution.keepServer,
                                'Keep Server',
                                'Use the server\'s version',
                                Icons.cloud_download,
                              ),
                              const SizedBox(height: 8),
                              _buildResolutionOption(
                                conflict.id,
                                ConflictResolution.merge,
                                'Merge Both',
                                'Combine both versions',
                                Icons.merge_type,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // Cancel - keep all as local
                      final allLocal = <String, ConflictResolution>{};
                      for (final conflict in widget.conflicts) {
                        allLocal[conflict.id] = ConflictResolution.keepLocal;
                      }
                      Navigator.of(context).pop();
                      widget.onResolve(allLocal);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onResolve(resolutions);
                    },
                    icon: const Icon(Icons.check),
                    label: Text(
                      'Apply Resolutions (${resolutions.length})',
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}