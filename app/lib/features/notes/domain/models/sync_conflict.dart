class SyncConflict {
  final String id;
  final NoteData localData;
  final NoteData serverData;
  final int localVersion;
  final int serverVersion;

  SyncConflict({
    required this.id,
    required this.localData,
    required this.serverData,
    required this.localVersion,
    required this.serverVersion,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    // Handle backend response format
    final clientVersion = json['clientVersion'] ?? json['localVersion'] ?? 0;
    final serverVer = json['serverVersion'] ?? 0;
    
    // Create empty local data since backend doesn't send it
    final localData = NoteData(
      title: '',
      content: '',
      updatedAt: DateTime.now(),
    );
    
    // Parse server data if available
    final serverDataJson = json['serverData'];
    final serverData = serverDataJson != null && serverDataJson is Map<String, dynamic>
        ? NoteData(
            title: serverDataJson['title'] ?? '',
            content: serverDataJson['content'] ?? '',
            updatedAt: DateTime.now(),
          )
        : NoteData(
            title: '',
            content: '',
            updatedAt: DateTime.now(),
          );
    
    return SyncConflict(
      id: json['id'],
      localData: localData,
      serverData: serverData,
      localVersion: clientVersion,
      serverVersion: serverVer,
    );
  }
}

class NoteData {
  final String title;
  final String content;
  final DateTime updatedAt;

  NoteData({
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  factory NoteData.fromJson(Map<String, dynamic> json) {
    return NoteData(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}