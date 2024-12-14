import 'package:uuid/uuid.dart';

class Document {
  final String uuid;
  final String title;
  final String type;
  final DateTime created;
  final DateTime lastEdited;
  final String content;
  final String userId;

  Document({
    String? uuid,
    required this.title,
    required this.type,
    required this.content,
    required this.userId,
    DateTime? created,
    DateTime? lastEdited,
  })  : uuid = uuid ?? const Uuid().v4(),
        created = created ?? DateTime.now(),
        lastEdited = lastEdited ?? DateTime.now();

  Document copyWith({
    String? title,
    String? type,
    String? content,
    String? userId,
  }) {
    return Document(
      uuid: uuid,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      created: created,
      lastEdited: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'title': title,
      'type': type,
      'content': content,
      'userId': userId,
      'created': created.toIso8601String(),
      'lastEdited': lastEdited.toIso8601String(),
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      uuid: json['uuid'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      content: json['content'] as String,
      userId: json['userId'] as String,
      created: DateTime.parse(json['created'] as String),
      lastEdited: DateTime.parse(json['lastEdited'] as String),
    );
  }
}
