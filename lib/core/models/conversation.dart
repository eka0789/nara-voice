/// Conversation transcript models. Sensitive screen content and private
/// message text are never persisted by default (see context store).
enum MessageRole { user, assistant, system }

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.language,
    this.meta = const <String, Object?>{},
  });

  final String id;
  final MessageRole role;
  final String text;
  final DateTime createdAt;

  /// BCP-47 tag detected for user utterances (`id` or `en`).
  final String? language;

  /// Execution metadata only — never private screen content.
  final Map<String, Object?> meta;

  ConversationMessage copyWith({String? text, Map<String, Object?>? meta}) {
    return ConversationMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      language: language,
      meta: meta ?? this.meta,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'role': role.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'language': language,
        'meta': meta,
      };

  static ConversationMessage fromMap(Map<Object?, Object?> map) {
    return ConversationMessage(
      id: (map['id'] as String?) ?? '',
      role: MessageRole.values.firstWhere(
        (r) => r.name == (map['role'] as String?),
        orElse: () => MessageRole.system,
      ),
      text: (map['text'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.now(),
      language: map['language'] as String?,
      meta: (map['meta'] as Map<Object?, Object?>?)?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
  }
}
