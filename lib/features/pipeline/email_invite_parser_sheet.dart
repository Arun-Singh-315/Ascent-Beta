import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/enums.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';

class EmailInviteParserSheet extends ConsumerStatefulWidget {
  const EmailInviteParserSheet({super.key});

  @override
  ConsumerState<EmailInviteParserSheet> createState() => _EmailInviteParserSheetState();
}

class _EmailInviteParserSheetState extends ConsumerState<EmailInviteParserSheet> {
  final _emailTextController = TextEditingController();
  bool _parsed = false;
  bool _isProcessing = false;

  // Extracted details
  String _extractedCompany = '';
  String _extractedRole = '';
  ApplicationStage _extractedStage = ApplicationStage.interview;
  DateTime? _extractedDateTime;
  String? _extractedMeetingUrl;
  String _extractedNotes = '';

  // Options
  bool _addToPipeline = true;
  bool _scheduleReminder = true;
  bool _createPrepTask = true;

  @override
  void dispose() {
    _emailTextController.dispose();
    super.dispose();
  }

  void _loadSampleEmail() {
    _emailTextController.text =
        'Hi Candidate,\n\n'
        'Thank you for your interest in Stripe! We were very impressed by your background and would like to invite you for a 45-minute Technical Interview for the Senior Software Engineer role.\n\n'
        'Date: Next Monday, 3:00 PM\n'
        'Meeting Link: https://meet.google.com/xyz-abcd-efg\n\n'
        'Please be prepared to write code in a collaborative editor. We will focus on data structures, algorithmic problem solving, and API design.\n\n'
        'Best regards,\nStripe Recruiting Team';
    _analyzeEmail();
  }

  void _analyzeEmail() {
    final raw = _emailTextController.text.trim();
    if (raw.isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    final textLower = raw.toLowerCase();

    // 1. Company Detection
    final knownCompanies = [
      'Stripe', 'Google', 'Meta', 'Amazon', 'Apple', 'Microsoft', 'Netflix',
      'Uber', 'Airbnb', 'Salesforce', 'Adobe', 'Oracle', 'Spotify', 'Twitter',
      'X', 'LinkedIn', 'Atlassian', 'Datadog', 'Coinbase', 'Robinhood',
      'Palantir', 'Snowflake', 'Figma', 'Notion', 'DoorDash', 'Instacart',
      'Swiggy', 'Zomato', 'Flipkart', 'Razorpay', 'Cred', 'PhonePe'
    ];

    String detectedCompany = 'Target Company';
    for (final c in knownCompanies) {
      if (textLower.contains(c.toLowerCase())) {
        detectedCompany = c;
        break;
      }
    }
    if (detectedCompany == 'Target Company') {
      final fromMatch = RegExp(r'@([a-zA-Z0-9\-]+)\.com').firstMatch(raw);
      if (fromMatch != null) {
        detectedCompany = fromMatch.group(1)!.toUpperCase();
      }
    }

    // 2. Role Detection
    String detectedRole = 'Software Engineer';
    if (textLower.contains('senior') && textLower.contains('engineer')) {
      detectedRole = 'Senior Software Engineer';
    } else if (textLower.contains('backend')) {
      detectedRole = 'Backend Engineer';
    } else if (textLower.contains('frontend')) {
      detectedRole = 'Frontend Engineer';
    } else if (textLower.contains('full stack') || textLower.contains('fullstack')) {
      detectedRole = 'Full Stack Engineer';
    } else if (textLower.contains('mobile') || textLower.contains('flutter') || textLower.contains('android')) {
      detectedRole = 'Mobile Engineer';
    } else if (textLower.contains('product manager') || textLower.contains('pm')) {
      detectedRole = 'Product Manager';
    }

    // 3. Stage Detection
    ApplicationStage detectedStage = ApplicationStage.interview;
    if (textLower.contains('online assessment') ||
        textLower.contains('hackerrank') ||
        textLower.contains('codesignal') ||
        textLower.contains('coding challenge') ||
        textLower.contains('oa')) {
      detectedStage = ApplicationStage.oaScreen;
    } else if (textLower.contains('offer') && !textLower.contains('thank you for applying')) {
      detectedStage = ApplicationStage.offer;
    } else if (textLower.contains('unfortunately') || textLower.contains('other candidates')) {
      detectedStage = ApplicationStage.rejected;
    } else if (textLower.contains('recruiter screen') || textLower.contains('phone screen')) {
      detectedStage = ApplicationStage.applied;
    }

    // 4. Meeting Link Detection
    final urlRegex = RegExp(r'(https?:\/\/(?:[a-zA-Z0-9\-]+\.)*(?:meet\.google\.com|zoom\.us|teams\.microsoft\.com|hackerrank\.com|codesignal\.com)[^\s]*)');
    final matchUrl = urlRegex.firstMatch(raw);
    String? detectedUrl = matchUrl?.group(0);

    // 5. Scheduled Time Detection (Fallback to 3 days from now if not exact)
    DateTime scheduled = DateTime.now().add(const Duration(days: 3, hours: 2));
    if (textLower.contains('tomorrow')) {
      scheduled = DateTime.now().add(const Duration(days: 1, hours: 2));
    } else if (textLower.contains('next monday')) {
      int daysUntilMon = (DateTime.monday - DateTime.now().weekday + 7) % 7;
      if (daysUntilMon == 0) daysUntilMon = 7;
      scheduled = DateTime.now().add(Duration(days: daysUntilMon));
    }
    scheduled = DateTime(scheduled.year, scheduled.month, scheduled.day, 15, 0);

    setState(() {
      _isProcessing = false;
      _parsed = true;
      _extractedCompany = detectedCompany;
      _extractedRole = detectedRole;
      _extractedStage = detectedStage;
      _extractedDateTime = scheduled;
      _extractedMeetingUrl = detectedUrl;
      _extractedNotes = 'Parsed from email invite. ${detectedUrl != null ? 'Meeting link: $detectedUrl' : ''}';
    });
  }

  Future<void> _commitAll() async {
    final db = ref.read(databaseProvider);
    HapticFeedback.mediumImpact();

    // 1. Add to Pipeline Kanban
    if (_addToPipeline) {
      await db.applicationDao.insertApplication(
        ApplicationTableCompanion.insert(
          company: _extractedCompany,
          role: _extractedRole,
          currentStage: drift.Value(_stageToString(_extractedStage)),
          jobUrl: drift.Value(_extractedMeetingUrl),
          nextActionDate: drift.Value(_extractedDateTime),
          notes: drift.Value(_extractedNotes),
        ),
      );
    }

    // 2. Schedule Reminder Notification
    if (_scheduleReminder && _extractedDateTime != null) {
      final remId = await db.reminderDao.insertReminder(
        ReminderTableCompanion(
          title: drift.Value('$_extractedCompany Interview: $_extractedRole'),
          scheduledAt: drift.Value(_extractedDateTime!),
          isActive: const drift.Value(true),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      await NotificationService.instance.scheduleReminderNotification(
        id: remId,
        title: 'Interview: $_extractedCompany',
        scheduledAt: _extractedDateTime!,
      );
    }

    // 3. Create Prep Task
    if (_createPrepTask) {
      final taskDate = _extractedDateTime != null
          ? DateTime(_extractedDateTime!.year, _extractedDateTime!.month, _extractedDateTime!.day)
          : DateTime.now();

      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Prepare for $_extractedCompany interview ($_extractedRole)',
          priority: const drift.Value('high'),
          plannedDate: drift.Value(taskDate),
          notes: drift.Value('Review core concepts and system design questions for $_extractedCompany.'),
        ),
      );
    }

    ref.invalidate(allRemindersProvider);
    ref.invalidate(nextUpcomingReminderProvider);
    ref.invalidate(nextUpcomingInterviewProvider);
    ref.invalidate(todayFocusTaskProvider);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced $_extractedCompany invite to Pipeline & Reminders! 🚀'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _stageToString(ApplicationStage stage) {
    switch (stage) {
      case ApplicationStage.wishlist:
        return 'Wishlist';
      case ApplicationStage.applied:
        return 'Applied';
      case ApplicationStage.oaScreen:
        return 'OA / Screening';
      case ApplicationStage.interview:
        return 'Interview';
      case ApplicationStage.offer:
        return 'Offer';
      case ApplicationStage.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.mark_email_read_outlined, color: context.accentPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Email & Invite Summarizer',
                        style: AscentTextStyles.displaySmall.copyWith(
                          color: context.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Paste recruiter emails or interview invites to auto-sync',
                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _loadSampleEmail,
                  child: const Text('Try Sample'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (!_parsed) ...[
              TextField(
                controller: _emailTextController,
                maxLines: 6,
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Paste interview email, OA invite, or recruiter update here...',
                  hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              AscentButton.primary(
                label: 'Analyze & Extract Details ✨',
                expanded: true,
                loading: _isProcessing,
                onPressed: _analyzeEmail,
              ),
            ] else ...[
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _extractedCompany,
                          style: AscentTextStyles.headlineMedium.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.accentPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.accentSecondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _stageToString(_extractedStage),
                            style: TextStyle(
                              color: context.accentSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _extractedRole,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Divider(height: 20),
                    if (_extractedDateTime != null)
                      Row(
                        children: [
                          Icon(Icons.event_available_rounded, size: 16, color: context.accentPrimary),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEE, MMM d • h:mm a').format(_extractedDateTime!),
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (_extractedMeetingUrl != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.video_camera_front_outlined, size: 16, color: context.accentInfo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _extractedMeetingUrl!,
                              style: AscentTextStyles.monoCode.copyWith(fontSize: 11, color: context.accentInfo),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _addToPipeline,
                onChanged: (val) => setState(() => _addToPipeline = val ?? true),
                title: const Text('Add to Kanban Pipeline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _scheduleReminder,
                onChanged: (val) => setState(() => _scheduleReminder = val ?? true),
                title: const Text('Schedule Push Reminder Notification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _createPrepTask,
                onChanged: (val) => setState(() => _createPrepTask = val ?? true),
                title: const Text('Create Study / Prep Task on Task Board', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.outlined(
                      label: 'Re-paste',
                      compact: true,
                      onPressed: () => setState(() => _parsed = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AscentButton.primary(
                      label: 'Sync to Ascent (1-Tap) 🚀',
                      compact: true,
                      onPressed: _commitAll,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
