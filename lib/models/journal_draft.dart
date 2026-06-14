import 'package:flutter/foundation.dart';

/// A lightweight, unsaved set of reflection fields used to pre-fill the
/// Daily Reflection screen — e.g. inferred by the AI assistant from a chat.
///
/// Kept separate from JournalEntry (which owns id/date/timestamps and is the
/// persisted form) so the journal and AI features can share a prefill type
/// without coupling.
@immutable
class JournalDraft {
  const JournalDraft({
    this.mood,
    this.biggestWin = '',
    this.mainDistraction = '',
    this.improvementForTomorrow = '',
    this.freeFlowEntry = '',
  });

  /// One of the mood emojis defined in `MoodSelector.moods`, or null when the
  /// model couldn't determine a mood.
  final String? mood;
  final String biggestWin;
  final String mainDistraction;
  final String improvementForTomorrow;
  final String freeFlowEntry;
}
