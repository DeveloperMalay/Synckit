import 'package:equatable/equatable.dart';

class NoteModel extends Equatable {
  final String id;
  final String title;
  final String content;
  final int version;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.version,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      version: json['version'] as int? ?? 0,
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'version': version,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    int? version,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      version: version ?? this.version,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  List<Object?> get props => [
        id,
        title,
        content,
        version,
        userId,
        createdAt,
        updatedAt,
      ];
}