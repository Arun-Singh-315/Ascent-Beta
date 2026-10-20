/// Single home for short user-facing hints and labels.
///
/// Keep every string here to a few words. Long instructions belong in a popup
/// (see `showAscentHelp`), never inline on a screen.
class AppCopy {
  AppCopy._();

  // Inputs
  static const captureHint = 'Jot a thought';
  static const activityHint = 'Add a task';
  static String messageHint(String assistantName) => 'Message $assistantName';

  // Home actions
  static const startDay = 'Start';
  static const dayStarted = 'Day started';
  static const planTask = 'Plan a task';
  static const askAssistant = 'Ask';

  // Option tiles
  static const typeTodo = 'To-do';
  static const typeTimer = 'Timer';
  static const typeFlexible = 'Flexible';
  static const dateToday = 'Today';
  static const dateTomorrow = 'Tomorrow';
  static const reminderOff = 'No reminder';

  // Day Start
  static const skip = 'Skip';
  static const next = 'Next';
  static const done = 'Done';
  static const back = 'Back';
}
