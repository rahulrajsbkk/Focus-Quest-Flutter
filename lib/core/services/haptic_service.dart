import 'package:flutter_vibrate/flutter_vibrate.dart';

class HapticService {
  factory HapticService() {
    return _instance;
  }

  HapticService._internal();

  static final HapticService _instance = HapticService._internal();

  Future<void> vibrate() async {
    final canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      await Vibrate.vibrate();
    }
  }

  Future<void> lightImpact() async {
    final canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      await Vibrate.feedback(FeedbackType.light);
    }
  }

  Future<void> mediumImpact() async {
    final canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      await Vibrate.feedback(FeedbackType.medium);
    }
  }

  Future<void> heavyImpact() async {
    final canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      await Vibrate.feedback(FeedbackType.heavy);
    }
  }

  Future<void> selectionClick() async {
    final canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      await Vibrate.feedback(FeedbackType.selection);
    }
  }
}
