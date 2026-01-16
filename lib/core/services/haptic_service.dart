import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

/// Service for providing haptic feedback across the app.
///
/// Gracefully handles platforms that don't support haptic feedback.
class HapticService {
  factory HapticService() {
    return _instance;
  }

  HapticService._internal();

  static final HapticService _instance = HapticService._internal();

  bool? _canVibrate;

  /// Check if the device supports haptic feedback.
  Future<bool> _checkCanVibrate() async {
    if (_canVibrate != null) return _canVibrate!;

    try {
      _canVibrate = await Vibrate.canVibrate;
    } on PlatformException {
      // Platform doesn't support vibration (e.g., macOS, Windows, Linux)
      debugPrint('HapticService: Platform does not support vibration');
      _canVibrate = false;
    }
    return _canVibrate!;
  }

  /// Trigger a basic vibration.
  Future<void> vibrate() async {
    if (!await _checkCanVibrate()) return;

    try {
      await Vibrate.vibrate();
    } on PlatformException catch (e) {
      debugPrint('HapticService: Failed to vibrate: $e');
    }
  }

  /// Trigger a light haptic impact.
  Future<void> lightImpact() async {
    if (!await _checkCanVibrate()) return;

    try {
      await Vibrate.feedback(FeedbackType.light);
    } on PlatformException catch (e) {
      debugPrint('HapticService: Failed to provide light impact: $e');
    }
  }

  /// Trigger a medium haptic impact.
  Future<void> mediumImpact() async {
    if (!await _checkCanVibrate()) return;

    try {
      await Vibrate.feedback(FeedbackType.medium);
    } on PlatformException catch (e) {
      debugPrint('HapticService: Failed to provide medium impact: $e');
    }
  }

  /// Trigger a heavy haptic impact.
  Future<void> heavyImpact() async {
    if (!await _checkCanVibrate()) return;

    try {
      await Vibrate.feedback(FeedbackType.heavy);
    } on PlatformException catch (e) {
      debugPrint('HapticService: Failed to provide heavy impact: $e');
    }
  }

  /// Trigger a selection click haptic.
  Future<void> selectionClick() async {
    if (!await _checkCanVibrate()) return;

    try {
      await Vibrate.feedback(FeedbackType.selection);
    } on PlatformException catch (e) {
      debugPrint('HapticService: Failed to provide selection click: $e');
    }
  }
}
