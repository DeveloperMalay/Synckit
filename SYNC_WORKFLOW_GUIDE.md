# SyncKit - Complete Sync Workflow Guide

## 1. Setup and Registration

### Start the Backend Server
```bash
cd SyncKit/backend
bun run dev
# Server runs at http://localhost:3000/api
```

### Register a New User (via API or Next.js)
```bash
# Using cURL
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "name": "Test User"
  }'

# Response:
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "uuid-here",
    "email": "user@example.com",
    "name": "Test User"
  }
}
```

Or register via Next.js web app:
1. Navigate to http://localhost:3001/register
2. Fill in the registration form
3. You'll be redirected to /notes after successful registration

## 2. Flutter App - Login and JWT Storage

### Login Flow in Flutter

```dart
// In login_screen.dart, when user taps login:
void _handleLogin() async {
  final email = _emailController.text;
  final password = _passwordController.text;
  
  // This triggers the LoginEvent in AuthBloc
  context.read<AuthBloc>().add(LoginEvent(
    email: email,
    password: password,
  ));
}

// AuthBloc handles the login:
// 1. Calls AuthRepository.login()
// 2. Stores JWT token securely
// 3. Updates auth state
```

### JWT Storage Implementation
The app uses `flutter_secure_storage` for secure token storage:

```dart
// In auth_repository.dart
class AuthRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<void> _saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }
  
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }
}
```

## 3. Creating and Editing Notes Offline

### Create a Note Offline

```dart
// User creates a note in the Flutter app
void _createNoteOffline() {
  // This gets handled by NotesBloc
  context.read<NotesBloc>().add(AddNoteEvent(
    title: 'Shopping List',
    content: 'Milk, Eggs, Bread',
  ));
}

// Behind the scenes in NotesBloc:
// 1. Creates note in local Drift database
// 2. Adds to PendingMutations table with type 'create'
// 3. Updates UI immediately (optimistic update)
```

### Edit a Note Offline

```dart
void _editNoteOffline(Note note) {
  context.read<NotesBloc>().add(UpdateNoteEvent(
    id: note.id,
    title: 'Updated Shopping List',
    content: 'Milk, Eggs, Bread, Butter',
  ));
}

// NotesBloc:
// 1. Updates note in local database
// 2. Adds to PendingMutations with type 'update'
// 3. Keeps track of baseVersion for conflict detection
```

### View Pending Changes
```dart
// The UI shows sync status
if (state.pendingChangesCount > 0) {
  Text('${state.pendingChangesCount} changes pending sync')
}
```

## 4. Triggering Sync with API

### Manual Sync Trigger

```dart
// User taps the sync button
void _triggerSync() {
  context.read<NotesBloc>().add(SyncNotesEvent());
}

// SyncNotesEvent handler in NotesBloc:
Stream<NotesState> _mapSyncNotesEventToState() async* {
  yield state.copyWith(isSyncing: true);
  
  try {
    // 1. Get all pending mutations
    final pendingMutations = await _notesRepository.getPendingMutations();
    
    // 2. Get all local notes with their versions
    final localNotes = await _notesRepository.getAllNotes();
    
    // 3. Prepare sync payload
    final changes = localNotes.map((note) => SyncChange(
      id: note.id,
      title: note.title,
      content: note.content,
      baseVersion: note.version,
    )).toList();
    
    // 4. Call sync API
    final response = await _notesRepository.syncWithServer(changes);
    
    // 5. Process response
    await _processSyncResponse(response);
    
    yield state.copyWith(
      isSyncing: false,
      lastSyncTime: DateTime.now(),
    );
  } catch (e) {
    yield state.copyWith(
      isSyncing: false,
      error: 'Sync failed: $e',
    );
  }
}
```

### Sync API Call Details

```dart
// In notes_repository.dart
Future<SyncResponse> syncWithServer(List<SyncChange> changes) async {
  final token = await _authRepository.getToken();
  
  final response = await http.post(
    Uri.parse('http://localhost:3000/api/notes/sync'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'changes': changes}),
  );
  
  final data = jsonDecode(response.body);
  return SyncResponse(
    applied: data['applied'],
    conflicts: data['conflicts'],
  );
}
```

## 5. Handling Conflicts with Dialog

### Conflict Detection
When sync returns conflicts, the app shows a resolution dialog:

```dart
// In notes_list_screen.dart
void _showConflictDialog(List<SyncConflict> conflicts) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConflictResolutionDialog(
      conflicts: conflicts,
      onResolve: (resolutions) {
        _resolveConflicts(resolutions);
      },
    ),
  );
}
```

### Conflict Resolution Dialog Implementation

```dart
class ConflictResolutionDialog extends StatefulWidget {
  final List<SyncConflict> conflicts;
  final Function(Map<String, ConflictResolution>) onResolve;
  
  @override
  _ConflictResolutionDialogState createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  Map<String, ConflictResolution> resolutions = {};
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sync Conflicts Detected'),
      content: SingleChildScrollView(
        child: Column(
          children: widget.conflicts.map((conflict) => Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Note: ${conflict.note.title}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  
                  // Local version
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Version (v${conflict.localVersion}):'),
                        Text(conflict.localData.content),
                        Text(
                          'Modified: ${_formatDate(conflict.localData.updatedAt)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Server version
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Server Version (v${conflict.serverVersion}):'),
                        Text(conflict.serverData.content),
                        Text(
                          'Modified: ${_formatDate(conflict.serverData.updatedAt)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Resolution options
                  Text('Choose resolution:'),
                  RadioListTile<ConflictResolution>(
                    title: Text('Keep Local'),
                    value: ConflictResolution.keepLocal,
                    groupValue: resolutions[conflict.id],
                    onChanged: (value) {
                      setState(() {
                        resolutions[conflict.id] = value!;
                      });
                    },
                  ),
                  RadioListTile<ConflictResolution>(
                    title: Text('Keep Server'),
                    value: ConflictResolution.keepServer,
                    groupValue: resolutions[conflict.id],
                    onChanged: (value) {
                      setState(() {
                        resolutions[conflict.id] = value!;
                      });
                    },
                  ),
                  RadioListTile<ConflictResolution>(
                    title: Text('Merge Both'),
                    value: ConflictResolution.merge,
                    groupValue: resolutions[conflict.id],
                    onChanged: (value) {
                      setState(() {
                        resolutions[conflict.id] = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: resolutions.length == widget.conflicts.length
            ? () {
                Navigator.of(context).pop();
                widget.onResolve(resolutions);
              }
            : null,
          child: Text('Resolve All'),
        ),
      ],
    );
  }
}
```

### Applying Conflict Resolutions

```dart
void _resolveConflicts(Map<String, ConflictResolution> resolutions) {
  context.read<NotesBloc>().add(ResolveConflictsEvent(resolutions));
}

// In NotesBloc
Stream<NotesState> _mapResolveConflictsEventToState(
  ResolveConflictsEvent event,
) async* {
  for (final entry in event.resolutions.entries) {
    final noteId = entry.key;
    final resolution = entry.value;
    final conflict = state.conflicts.firstWhere((c) => c.id == noteId);
    
    switch (resolution) {
      case ConflictResolution.keepLocal:
        // Keep local version, will retry on next sync
        break;
        
      case ConflictResolution.keepServer:
        // Update local with server version
        await _notesRepository.updateNote(
          noteId,
          title: conflict.serverData.title,
          content: conflict.serverData.content,
          version: conflict.serverVersion,
        );
        break;
        
      case ConflictResolution.merge:
        // Merge both versions
        final mergedContent = '''
${conflict.localData.content}

--- Server Version ---
${conflict.serverData.content}
''';
        await _notesRepository.updateNote(
          noteId,
          title: conflict.localData.title,
          content: mergedContent,
          version: conflict.serverVersion,
        );
        break;
    }
  }
  
  // Clear conflicts and refresh
  yield state.copyWith(conflicts: []);
  add(LoadNotesEvent());
}
```

## 6. Verifying Updates in Next.js Dashboard

### Auto-refresh in Next.js
The Next.js dashboard uses React Query with automatic refetching:

```typescript
// In use-notes.ts
const { notes } = useNotes({
  refetchInterval: 30000, // Refetch every 30 seconds
  refetchOnWindowFocus: true, // Refetch when window gains focus
});
```

### Manual Refresh
Users can also manually refresh:

```typescript
// Click "Sync Now" button in Next.js
const { syncNotes, isSyncing } = useSyncNotes();

<button onClick={() => syncNotes()}>
  {isSyncing ? 'Syncing...' : 'Sync Now'}
</button>
```

### Viewing Synced Notes
1. Open http://localhost:3001/notes
2. You'll see all notes with their version numbers:
   - Yellow badge (v0) = New/unsynced
   - Green badge (v1+) = Synced with server
3. The table shows:
   - Title and content preview
   - Version number
   - Last updated timestamp
   - Edit/Delete actions

### Real-time Conflict Alerts
If conflicts are detected during sync:

```typescript
// Next.js shows conflict alert
{hasConflicts && (
  <Alert>
    {conflicts.length} sync conflict(s) detected
    <button onClick={() => resolveAllConflicts('server')}>
      Resolve All (Accept Server)
    </button>
  </Alert>
)}
```

## Testing the Complete Flow

### Test Scenario 1: Basic Sync
1. Create a note in Flutter while offline
2. Go online and tap sync
3. Open Next.js dashboard - note appears immediately

### Test Scenario 2: Conflict Resolution
1. Create a note in Flutter and sync
2. Edit the note in Next.js dashboard
3. Edit the same note in Flutter (while offline)
4. Go online and sync in Flutter
5. Conflict dialog appears - choose resolution
6. Verify resolution in both Flutter and Next.js

### Test Scenario 3: Multi-device Sync
1. Login on Flutter device A
2. Login on Flutter device B
3. Login on Next.js
4. Create notes on device A while offline
5. Create different notes on device B while offline
6. Sync both devices
7. Verify all notes appear in Next.js with correct versions

## Debugging Tips

### Check Pending Mutations
```dart
// In Flutter debug console
final pending = await database.pendingMutations.all().get();
print('Pending mutations: ${pending.length}');
```

### Monitor Sync Requests
```bash
# Backend logs show sync activity
[SYNC] User abc-123: 3 changes received
[SYNC] Applied: 2, Conflicts: 1
```

### Verify JWT Token
```dart
// In Flutter
final token = await storage.read(key: 'auth_token');
print('Token exists: ${token != null}');
```

### Check Local Database
```dart
// View all local notes
final notes = await database.notes.all().get();
notes.forEach((note) {
  print('Note: ${note.title} (v${note.version})');
});
```