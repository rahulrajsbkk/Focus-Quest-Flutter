import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/gemma_service.dart';
import 'package:focus_quest/features/journal/widgets/mood_selector.dart';
import 'package:focus_quest/models/journal_draft.dart';

/// Cap the transcript so it can't blow past the model's context window; the
/// most recent turns matter most for a daily reflection.
const int _kMaxTranscriptChars = 3000;

/// Neutral fallback mood when the model is unsure or returns junk.
const String _kFallbackMood = '😐';

/// Turns a chat transcript into a [JournalDraft] using the on-device model.
class JournalInferenceService {
  JournalInferenceService(this._gemma);

  final GemmaService _gemma;

  Future<JournalDraft> infer(String transcript) async {
    final raw = await _gemma.generateOnce(
      _userPrompt(_truncate(transcript)),
      systemInstruction: _systemPrompt(),
    );
    return _parse(raw);
  }

  String _truncate(String transcript) {
    if (transcript.length <= _kMaxTranscriptChars) return transcript;
    final tail = transcript.substring(
      transcript.length - _kMaxTranscriptChars,
    );
    return '[earlier conversation truncated]\n$tail';
  }

  String _systemPrompt() {
    final moods = MoodSelector.moods
        .map((m) => '${m.emoji} (${m.label})')
        .join(', ');
    return 'You turn a chat conversation into a daily reflection journal '
        'entry. Respond with ONLY a single JSON object — no prose, no '
        'markdown, no code fences. The object must have exactly these string '
        'keys: "mood", "biggestWin", "mainDistraction", '
        '"improvementForTomorrow", "freeFlowEntry". The "mood" value MUST be '
        'exactly one of these emoji characters: $moods. If the mood is '
        'unclear, use "$_kFallbackMood". Keep biggestWin, mainDistraction and '
        'improvementForTomorrow to one short sentence each. freeFlowEntry is a '
        'short reflective paragraph. Write every value in the first person. '
        'Use an empty string for anything the conversation does not cover.';
  }

  String _userPrompt(String transcript) =>
      'Conversation:\n$transcript\n\nReturn the JSON object now.';

  JournalDraft _parse(String raw) {
    final json = _extractJson(raw);
    if (json == null) {
      // Couldn't get structured output — keep the model's text as a brain dump.
      return JournalDraft(mood: _kFallbackMood, freeFlowEntry: raw.trim());
    }
    return JournalDraft(
      mood: _coerceMood(json['mood']),
      biggestWin: _str(json['biggestWin']),
      mainDistraction: _str(json['mainDistraction']),
      improvementForTomorrow: _str(json['improvementForTomorrow']),
      freeFlowEntry: _str(json['freeFlowEntry']),
    );
  }

  Map<String, dynamic>? _extractJson(String raw) {
    final stripped = raw.replaceAll(
      RegExp('```(json)?', caseSensitive: false),
      '',
    );
    final start = stripped.indexOf('{');
    final end = stripped.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(stripped.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String _coerceMood(Object? value) {
    final raw = value?.toString().trim() ?? '';
    final allowed = MoodSelector.moods.map((m) => m.emoji).toSet();
    if (allowed.contains(raw)) return raw;
    for (final emoji in allowed) {
      if (raw.contains(emoji)) return emoji;
    }
    return _kFallbackMood;
  }

  String _str(Object? value) => value?.toString().trim() ?? '';
}

final journalInferenceProvider = Provider<JournalInferenceService>(
  (ref) => JournalInferenceService(ref.read(gemmaServiceProvider)),
);
