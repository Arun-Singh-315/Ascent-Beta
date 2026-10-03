import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';

class _CommandMessage {
  final String text;
  final bool isUser;
  final int? reminderId;
  final String? reminderTitle;
  final DateTime? scheduledTime;

  const _CommandMessage({
    required this.text,
    required this.isUser,
    this.reminderId,
    this.reminderTitle,
    this.scheduledTime,
  });
}

class PlanMyDaySheet extends ConsumerStatefulWidget {
  const PlanMyDaySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlanMyDaySheet(),
    );
  }

  @override
  ConsumerState<PlanMyDaySheet> createState() => _PlanMyDaySheetState();
}

class _PlanMyDaySheetState extends ConsumerState<PlanMyDaySheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_CommandMessage> _messages = [];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleInput(String input) async {
    final text = input.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(_CommandMessage(text: text, isUser: true));
    });
    _scrollToBottom();

    final lower = text.toLowerCase();

    // 1. Check for Reminder intent (e.g. "remind me to drink water in 2 mins")
    if (lower.startsWith('remind') || lower.contains('remind me')) {
      await _processReminderIntent(text);
      return;
    }

    // 2. Check for "What do I have planned" query
    if (lower.contains('what') && (lower.contains('plan') || lower.contains('today'))) {
      final taskDao = ref.read(taskDaoProvider);
      final tasks = await taskDao.watchTodayTasks().first;
      if (tasks.isEmpty) {
        setState(() {
          _messages.add(const _CommandMessage(
            text: "You have no tasks scheduled for today yet. You can ask me to add one!",
            isUser: false,
          ));
        });
      } else {
        final listStr = tasks.map((t) => "• ${t.title}").join("\n");
        setState(() {
          _messages.add(_CommandMessage(
            text: "Here is your plan for today:\n$listStr",
            isUser: false,
          ));
        });
      }
      _scrollToBottom();
      return;
    }

    // 3. Check for "Mark ... as done"
    if (lower.startsWith('mark') && lower.contains('done')) {
      final taskDao = ref.read(taskDaoProvider);
      final tasks = await taskDao.watchTodayTasks().first;
      if (tasks.isNotEmpty) {
        final firstPending = tasks.firstWhere(
          (t) => t.actualCompletedDate == null,
          orElse: () => tasks.first,
        );
        await taskDao.toggleTaskCompletion(firstPending.id, true);
        setState(() {
          _messages.add(_CommandMessage(
            text: "Marked '${firstPending.title}' as done! Great work.",
            isUser: false,
          ));
        });
      } else {
        setState(() {
          _messages.add(const _CommandMessage(
            text: "No active tasks found to mark as done.",
            isUser: false,
          ));
        });
      }
      _scrollToBottom();
      return;
    }

    // 4. Default: Add study block / task
    var taskTitle = text;
    if (lower.startsWith('add study') || lower.startsWith('add task') || lower.startsWith('add')) {
      taskTitle = text.replaceFirst(RegExp(r'^add\s+(?:study\s+|task\s+)?', caseSensitive: false), '');
    }

    final taskDao = ref.read(taskDaoProvider);
    await taskDao.insertTask(
      TaskTableCompanion.insert(
        title: taskTitle.isNotEmpty ? taskTitle : text,
        plannedDate: drift.Value(DateTime.now()),
        priority: const drift.Value('medium'),
      ),
    );

    setState(() {
      _messages.add(_CommandMessage(
        text: "Added study block '$taskTitle' to your daily queue.",
        isUser: false,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _processReminderIntent(String text) async {
    final lower = text.toLowerCase();

    // Parse duration offset: e.g. "in 2 mins", "in 30 minutes", "in 1 hour"
    Duration offset = const Duration(minutes: 30);
    final minMatch = RegExp(r'in\s+(\d+)\s*(?:mins?|minutes?|m\b)', caseSensitive: false).firstMatch(lower);
    final hourMatch = RegExp(r'in\s+(\d+)\s*(?:hours?|hrs?|h\b)', caseSensitive: false).firstMatch(lower);

    if (minMatch != null) {
      final mins = int.tryParse(minMatch.group(1) ?? '30') ?? 30;
      offset = Duration(minutes: mins);
    } else if (hourMatch != null) {
      final hrs = int.tryParse(hourMatch.group(1) ?? '1') ?? 1;
      offset = Duration(hours: hrs);
    }

    // Parse reminder title
    String title = text;
    final remindToMatch = RegExp(r'remind\s+(?:me\s+)?(?:to\s+)?(.+?)(?:\s+in\s+\d+|\s+at\s+|$)', caseSensitive: false).firstMatch(text);
    if (remindToMatch != null) {
      title = remindToMatch.group(1)?.trim() ?? text;
    }
    if (title.isEmpty) title = 'Drink water';

    // Capitalize
    title = title[0].toUpperCase() + title.substring(1);

    final scheduledAt = DateTime.now().add(offset);
    final reminderDao = ref.read(reminderDaoProvider);

    final id = await reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: title,
        scheduledAt: scheduledAt,
        isActive: const drift.Value(true),
      ),
    );

    try {
      await NotificationService.instance.scheduleReminderNotification(
        id: id,
        title: title,
        scheduledAt: scheduledAt,
      );
    } catch (_) {}

    final timeStr = DateFormat('HH:mm').format(scheduledAt);

    setState(() {
      _messages.add(_CommandMessage(
        text: "Scheduled reminder: '$title' for today at $timeStr.",
        isUser: false,
        reminderId: id,
        reminderTitle: title,
        scheduledTime: scheduledAt,
      ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE26D5C).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFFE26D5C), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Command Center',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        'Plan My Day · Real Data & Notifications',
                        style: TextStyle(fontSize: 12, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: context.textMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1EFEA)),

          // Scrollable chat & suggestions
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Top Welcome Example Card (from video 00:05)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.divider.withValues(alpha: 0.8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Welcome to your Command Center!',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can talk naturally to organize your day. For example:\n'
                        '• "Add study java for 2 hours tomorrow at 9 AM"\n'
                        '• "Remind me in 30 minutes to review notes"\n'
                        '• "What do I have planned today?"\n'
                        '• "Mark Java as done"',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Messages stream
                ..._messages.map((msg) {
                  if (msg.isUser) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10, left: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0ECE4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          msg.text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    );
                  } else {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10, right: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.auto_awesome, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (msg.reminderId != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: context.bgBase,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: context.divider),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.orange),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        msg.reminderTitle ?? 'Reminder',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      color: context.textMuted,
                                      onPressed: () async {
                                        await ref.read(reminderDaoProvider).deleteReminder(msg.reminderId!);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Reminder removed')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                }),
              ],
            ),
          ),

          // Suggestion Chips (from video 00:05)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CommandChip(
                    label: 'What to Study',
                    icon: Icons.lightbulb_outline_rounded,
                    onTap: () => _handleInput('What do I have planned today?'),
                  ),
                  const SizedBox(width: 8),
                  _CommandChip(
                    label: '+ Add Study Block',
                    icon: Icons.add_circle_outline_rounded,
                    onTap: () => _handleInput('Add study Spring Boot for 1 hour'),
                  ),
                  const SizedBox(width: 8),
                  _CommandChip(
                    label: 'Remind in 30m',
                    icon: Icons.alarm_rounded,
                    onTap: () => _handleInput('Remind me in 30 minutes to review notes'),
                  ),
                ],
              ),
            ),
          ),

          // Input Bar (from video 00:08)
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + bottomInset),
            decoration: BoxDecoration(
              color: context.bgSurface,
              border: const Border(top: BorderSide(color: Color(0xFFF1EFEA))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _handleInput,
                    decoration: InputDecoration(
                      hintText: "Type an activity, reminder, or question...",
                      hintStyle: TextStyle(fontSize: 13, color: context.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: context.bgBase,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: context.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: context.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: context.accentSecondary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _handleInput(_textController.text),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.accentSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CommandChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.bgBase,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
