/// Base class for all Ninja callbacks
abstract class NinjaBaseCallback {
  final String action;
  final Map<String, dynamic>? data;

  NinjaBaseCallback(this.action, [this.data]);
}

/// Callback for story events
class NinjaStoriesCallback extends NinjaBaseCallback {
  NinjaStoriesCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for quiz events
class NinjaQuizCallback extends NinjaBaseCallback {
  NinjaQuizCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for core nudge events
class NinjaCoreCallback extends NinjaBaseCallback {
  NinjaCoreCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for nudge display events
class NinjaNudgesCallback extends NinjaBaseCallback {
  NinjaNudgesCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for survey events
class NinjaSurveyCallback extends NinjaBaseCallback {
  NinjaSurveyCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for spin the wheel events
class NinjaSpinTheWheelCallback extends NinjaBaseCallback {
  NinjaSpinTheWheelCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for gamification events
class NinjaGamificationCallback extends NinjaBaseCallback {
  NinjaGamificationCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for modal events
class NinjaModalsCallback extends NinjaBaseCallback {
  NinjaModalsCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for leaderboard events
class NinjaLeaderboardCallback extends NinjaBaseCallback {
  NinjaLeaderboardCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}

/// Callback for global experience events
class NinjaGlobalExperienceCallback extends NinjaBaseCallback {
  NinjaGlobalExperienceCallback(String action, [Map<String, dynamic>? data])
      : super(action, data);
}
