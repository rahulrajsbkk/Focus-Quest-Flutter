import 'package:flutter_quest/models/focus_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FocusSession', () {
    final testDate = DateTime(2025, 1, 15, 10);

    group('factory constructors', () {
      test('start() creates an active session', () {
        final session = FocusSession.start(
          id: 'session-1',
          questId: 'quest-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        );

        expect(session.id, 'session-1');
        expect(session.questId, 'quest-1');
        expect(session.status, FocusSessionStatus.active);
        expect(session.type, FocusSessionType.focus);
        expect(session.plannedDuration, const Duration(minutes: 25));
        expect(session.startedAt, testDate);
      });

      test('start() uses current time if not provided', () {
        final before = DateTime.now();
        final session = FocusSession.start(
          id: 'session-1',
          plannedDuration: const Duration(minutes: 25),
        );
        final after = DateTime.now();

        final beforeMinusOne = before.subtract(const Duration(seconds: 1));
        final afterPlusOne = after.add(const Duration(seconds: 1));
        expect(session.startedAt.isAfter(beforeMinusOne), isTrue);
        expect(session.startedAt.isBefore(afterPlusOne), isTrue);
      });
    });

    group('pause and resume', () {
      test('pause() sets status to paused and records time', () {
        final session = FocusSession.start(
          id: 'session-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        );

        final pauseTime = testDate.add(const Duration(minutes: 10));
        final paused = session.pause(at: pauseTime);

        expect(paused.status, FocusSessionStatus.paused);
        expect(paused.pausedAt, pauseTime);
        expect(paused.isPaused, isTrue);
        expect(paused.isActive, isFalse);
      });

      test('pause() does nothing if not active', () {
        final session = FocusSession.start(
          id: 'session-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        ).complete(at: testDate.add(const Duration(minutes: 25)));

        final result = session.pause();

        expect(result.status, FocusSessionStatus.completed);
      });

      test('resume() calculates paused duration', () {
        final session = FocusSession.start(
          id: 'session-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        );

        final pauseTime = testDate.add(const Duration(minutes: 10));
        final paused = session.pause(at: pauseTime);

        final resumeTime = pauseTime.add(const Duration(minutes: 5));
        final resumed = paused.resume(at: resumeTime);

        expect(resumed.status, FocusSessionStatus.active);
        expect(resumed.totalPausedDuration, const Duration(minutes: 5));
        expect(resumed.resumedAt, resumeTime);
        expect(resumed.pausedAt, isNull);
      });

      test('resume() does nothing if not paused', () {
        final session = FocusSession.start(
          id: 'session-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        );

        final result = session.resume();

        expect(result.status, FocusSessionStatus.active);
        expect(result.totalPausedDuration, Duration.zero);
      });
    });

    group('complete and interrupt', () {
      test('complete() marks session as completed', () {
        final session = FocusSession.start(
          id: 'session-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        );

        final completedTime = testDate.add(const Duration(minutes: 25));
        final completed = session.complete(at: completedTime, notes: 'Done!');

        expect(completed.status, FocusSessionStatus.completed);
        expect(completed.completedAt, completedTime);
        expect(completed.notes, 'Done!');
        expect(completed.hasEnded, isTrue);
      });

      test('interrupt() marks session as interrupted', () {
        final session = FocusSession.start(
          id: 'session-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        );

        final interruptTime = testDate.add(const Duration(minutes: 10));
        final interrupted = session.interrupt(
          at: interruptTime,
          notes: 'Phone rang',
        );

        expect(interrupted.status, FocusSessionStatus.interrupted);
        expect(interrupted.completedAt, interruptTime);
        expect(interrupted.notes, 'Phone rang');
        expect(interrupted.hasEnded, isTrue);
      });
    });

    group('progress calculation', () {
      test('progress is 0 at start', () {
        final session = FocusSession(
          id: 'session-1',
          type: FocusSessionType.focus,
          status: FocusSessionStatus.completed,
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
          completedAt: testDate,
        );

        expect(session.progress, 0.0);
      });

      test('progress is 1.0 when completed on time', () {
        final session = FocusSession(
          id: 'session-1',
          type: FocusSessionType.focus,
          status: FocusSessionStatus.completed,
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
          completedAt: testDate.add(const Duration(minutes: 25)),
        );

        expect(session.progress, 1.0);
      });

      test('progress is capped at 1.0 for overtime', () {
        final session = FocusSession(
          id: 'session-1',
          type: FocusSessionType.focus,
          status: FocusSessionStatus.completed,
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
          completedAt: testDate.add(const Duration(minutes: 30)),
        );

        expect(session.progress, 1.0);
      });

      test('progress is 0.5 at halfway', () {
        final session = FocusSession(
          id: 'session-1',
          type: FocusSessionType.focus,
          status: FocusSessionStatus.completed,
          plannedDuration: const Duration(minutes: 20),
          startedAt: testDate,
          completedAt: testDate.add(const Duration(minutes: 10)),
        );

        expect(session.progress, closeTo(0.5, 0.01));
      });
    });

    group('JSON serialization', () {
      test('toJson() correctly serializes all fields', () {
        final session = FocusSession(
          id: 'session-1',
          questId: 'quest-1',
          subQuestId: 'sub-1',
          type: FocusSessionType.focus,
          status: FocusSessionStatus.active,
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
          totalPausedDuration: const Duration(minutes: 2),
          notes: 'Working on Focus Quest',
        );

        final json = session.toJson();

        expect(json['id'], 'session-1');
        expect(json['questId'], 'quest-1');
        expect(json['subQuestId'], 'sub-1');
        expect(json['type'], 'focus');
        expect(json['status'], 'active');
        expect(json['plannedDurationSeconds'], 1500);
        expect(json['startedAt'], testDate.toIso8601String());
        expect(json['totalPausedDurationSeconds'], 120);
        expect(json['notes'], 'Working on Focus Quest');
      });

      test('fromJson() correctly deserializes all fields', () {
        final json = {
          'id': 'session-2',
          'questId': 'quest-1',
          'type': 'shortBreak',
          'status': 'completed',
          'plannedDurationSeconds': 300,
          'startedAt': testDate.toIso8601String(),
          'completedAt': testDate
              .add(const Duration(minutes: 5))
              .toIso8601String(),
          'totalPausedDurationSeconds': 0,
        };

        final session = FocusSession.fromJson(json);

        expect(session.id, 'session-2');
        expect(session.type, FocusSessionType.shortBreak);
        expect(session.status, FocusSessionStatus.completed);
        expect(session.plannedDuration, const Duration(minutes: 5));
      });

      test('round-trip serialization preserves data', () {
        final session = FocusSession(
          id: 'session-1',
          questId: 'quest-1',
          type: FocusSessionType.longBreak,
          status: FocusSessionStatus.paused,
          plannedDuration: const Duration(minutes: 15),
          startedAt: testDate,
          pausedAt: testDate.add(const Duration(minutes: 5)),
          totalPausedDuration: const Duration(minutes: 1),
        );

        final json = session.toJson();
        final restored = FocusSession.fromJson(json);

        expect(restored, session);
      });

      test('can restore interrupted session after app restart', () {
        // Simulate saving session before app close
        final session = FocusSession.start(
          id: 'session-1',
          questId: 'quest-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        );

        final json = session.toJson();

        // Simulate app restart and restore
        final restored = FocusSession.fromJson(json);

        expect(restored.id, session.id);
        expect(restored.questId, session.questId);
        expect(restored.status, FocusSessionStatus.active);
        expect(restored.startedAt, testDate);
        expect(restored.plannedDuration, const Duration(minutes: 25));
      });
    });

    group('elapsed duration', () {
      test('elapsedDuration excludes paused time for completed session', () {
        final session = FocusSession(
          id: 'session-1',
          type: FocusSessionType.focus,
          status: FocusSessionStatus.completed,
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
          completedAt: testDate.add(const Duration(minutes: 30)),
          totalPausedDuration: const Duration(minutes: 5),
        );

        // Total time: 30 min, Paused: 5 min, Elapsed: 25 min
        expect(session.elapsedDuration, const Duration(minutes: 25));
      });
    });

    group('remaining duration', () {
      test('remainingDuration is zero when completed', () {
        final session = FocusSession(
          id: 'session-1',
          type: FocusSessionType.focus,
          status: FocusSessionStatus.completed,
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
          completedAt: testDate.add(const Duration(minutes: 25)),
        );

        expect(session.remainingDuration, Duration.zero);
      });
    });
  });

  group('FocusSessionType', () {
    test('all types are correctly named', () {
      expect(FocusSessionType.focus.name, 'focus');
      expect(FocusSessionType.shortBreak.name, 'shortBreak');
      expect(FocusSessionType.longBreak.name, 'longBreak');
    });
  });

  group('FocusSessionStatus', () {
    test('all statuses are correctly named', () {
      expect(FocusSessionStatus.active.name, 'active');
      expect(FocusSessionStatus.paused.name, 'paused');
      expect(FocusSessionStatus.completed.name, 'completed');
      expect(FocusSessionStatus.interrupted.name, 'interrupted');
    });
  });
}
