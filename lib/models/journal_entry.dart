import 'package:flutter/foundation.dart';

/// Represents a daily journal entry / reflection.
@immutable
class JournalEntry {
  /// Creates a new JournalEntry.
  const JournalEntry({
    required this.id,
    required this.date,
    required this.mood,
    required this.biggestWin,
    required this.mainDistraction,
    required this.improvementForTomorrow,
    required this.createdAt,
    this.freeFlowEntry,
    this.updatedAt,
  });

  /// Creates a JournalEntry from a JSON map.
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      mood: json['mood'] as String,
      biggestWin: json['biggestWin'] as String,
      mainDistraction: json['mainDistraction'] as String,
      improvementForTomorrow: json['improvementForTomorrow'] as String,
      freeFlowEntry: json['freeFlowEntry'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Unique identifier (usually UUID).
  final String id;

  /// The date of the reflection (usually just the day, time stripped).
  final DateTime date;

  /// The chosen mood (emoji/sticker string).
  final String mood;

  /// Answer to "What was your biggest win?".
  final String biggestWin;

  /// Answer to "What distracted you most?".
  final String mainDistraction;

  /// Answer to "One thing to do differently tomorrow?".
  final String improvementForTomorrow;

  /// Optional free-flow brain dump text.
  final String? freeFlowEntry;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Converts the JournalEntry to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'id': id,
      'date': date.toIso8601String(),
      'mood': mood,
      'biggestWin': biggestWin,
      'mainDistraction': mainDistraction,
      'improvementForTomorrow': improvementForTomorrow,
      'freeFlowEntry': freeFlowEntry,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Creates a copy of this JournalEntry with the given fields replaced.
  JournalEntry copyWith({
    String? id,
    DateTime? date,
    String? mood,
    String? biggestWin,
    String? mainDistraction,
    String? improvementForTomorrow,
    String? freeFlowEntry,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      biggestWin: biggestWin ?? this.biggestWin,
      mainDistraction: mainDistraction ?? this.mainDistraction,
      improvementForTomorrow:
          improvementForTomorrow ?? this.improvementForTomorrow,
      freeFlowEntry: freeFlowEntry ?? this.freeFlowEntry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEntry &&
        other.id == id &&
        other.date == date &&
        other.mood == mood &&
        other.biggestWin == biggestWin &&
        other.mainDistraction == mainDistraction &&
        other.improvementForTomorrow == improvementForTomorrow &&
        other.freeFlowEntry == freeFlowEntry &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      date,
      mood,
      biggestWin,
      mainDistraction,
      improvementForTomorrow,
      freeFlowEntry,
      createdAt,
      updatedAt,
    );
  }
}
