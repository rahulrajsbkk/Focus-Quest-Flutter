import 'package:flutter/foundation.dart';

/// Who authored a chat message.
enum ChatRole { user, assistant }

/// A single message in the AI assistant conversation. Held in memory only
/// (per session) — the durable artifact is the journal entry the user saves.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isStreaming = false,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime timestamp;

  /// True while assistant tokens are still arriving for this message.
  final bool isStreaming;

  bool get isUser => role == ChatRole.user;

  ChatMessage copyWith({String? text, bool? isStreaming}) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
