/// The subtask last paused from the floating HUD or the home widget. Until it is started again it is
/// not offered as the "next" task, so a stop does not come back as a Continue prompt or as the
/// headline of the widget. Cleared when a timer runs again.
class StoppedTaskMemory {
  StoppedTaskMemory._();

  static String? subTaskId;
}
