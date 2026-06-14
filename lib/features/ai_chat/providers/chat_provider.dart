import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/gemma_service.dart';
import 'package:focus_quest/features/ai_chat/models/chat_message.dart';
import 'package:uuid/uuid.dart';

/// In-memory state of the AI assistant conversation.
@immutable
class ChatState {
  const ChatState({
    this.messages = const [],
    this.isBusy = false,
    this.isPreparing = false,
    this.error,
  });

  final List<ChatMessage> messages;

  /// A reply is being generated (model loading and/or streaming).
  final bool isBusy;

  /// The model is loading into memory before the first reply.
  final bool isPreparing;

  final String? error;

  /// Number of completed (non-streaming, non-empty) messages — used to gate
  /// "Create journal from chat" against trivially short conversations.
  int get completedMessageCount =>
      messages.where((m) => !m.isStreaming && m.text.trim().isNotEmpty).length;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isBusy,
    bool? isPreparing,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isBusy: isBusy ?? this.isBusy,
      isPreparing: isPreparing ?? this.isPreparing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  final Uuid _uuid = const Uuid();
  StreamSubscription<String>? _sub;

  GemmaService get _service => ref.read(gemmaServiceProvider);

  @override
  ChatState build() {
    ref.onDispose(() => _sub?.cancel());
    return const ChatState();
  }

  /// Sends [text], lazily loading the model on the first message, then streams
  /// the assistant reply token-by-token into the trailing assistant bubble.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isBusy) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );
    final assistantId = _uuid.v4();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: ChatRole.assistant,
      text: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isBusy: true,
      clearError: true,
    );

    if (!_service.isLoaded) {
      state = state.copyWith(isPreparing: true);
      try {
        await _service.loadModel();
      } on Object catch (e) {
        debugPrint('ChatNotifier: loadModel failed: $e');
        _finishWithError(
          assistantId,
          'Could not start the assistant on this device.',
        );
        return;
      }
      state = state.copyWith(isPreparing: false);
    }

    final buffer = StringBuffer();
    await _sub?.cancel();
    final completer = Completer<void>();
    _sub = _service
        .sendMessage(trimmed)
        .listen(
          (token) {
            buffer.write(token);
            _updateAssistant(assistantId, buffer.toString(), streaming: true);
          },
          onError: (Object e, StackTrace s) {
            debugPrint('ChatNotifier: stream error: $e');
            _updateAssistant(assistantId, buffer.toString(), streaming: false);
            state = state.copyWith(
              isBusy: false,
              error: 'The assistant ran into a problem. Please try again.',
            );
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            _updateAssistant(assistantId, buffer.toString(), streaming: false);
            state = state.copyWith(isBusy: false);
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
    return completer.future;
  }

  void _updateAssistant(String id, String text, {required bool streaming}) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == id) m.copyWith(text: text, isStreaming: streaming) else m,
      ],
    );
  }

  void _finishWithError(String assistantId, String message) {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != assistantId).toList(),
      isBusy: false,
      isPreparing: false,
      error: message,
    );
  }

  /// Builds a plain-text transcript of completed messages, for the journal
  /// inference step.
  String buildTranscript() {
    final buffer = StringBuffer();
    for (final m in state.messages) {
      if (m.isStreaming || m.text.trim().isEmpty) continue;
      buffer.writeln('${m.isUser ? 'User' : 'Assistant'}: ${m.text.trim()}');
    }
    return buffer.toString().trim();
  }

  void clearChat() {
    unawaited(_sub?.cancel());
    _sub = null;
    state = const ChatState();
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
