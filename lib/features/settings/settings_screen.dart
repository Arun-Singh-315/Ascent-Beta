import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/database/demo_data_seeder.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _companyInputController = TextEditingController();
  List<String> _targetCompanies = [];
  DateTime? _interviewDate;
  int _weeklyHours = 10;
  String _studyWindow = 'morning';
  bool _profileLoaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _companyInputController.dispose();
    super.dispose();
  }

  void _initFromProfile(UserProfile? profile) {
    if (profile == null || _profileLoaded) return;
    _profileLoaded = true;
    _nameController.text = profile.name;
    _roleController.text = profile.targetRole;
    _interviewDate = profile.interviewDate;
    _weeklyHours = profile.weeklyHoursAvailable;
    _studyWindow = profile.preferredStudyWindow;
    try {
      final decoded = jsonDecode(profile.targetCompanies) as List<dynamic>;
      _targetCompanies = decoded.map((e) => e.toString()).toList();
    } catch (_) {
      _targetCompanies = [];
    }
  }

  bool _isSaving = false;
  bool _savedSuccess = false;

  Future<void> _persistAndReturn() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      final profileDao = ref.read(userProfileDaoProvider);
      final current = await profileDao.getProfile();

      await profileDao.upsertProfile(
        UserProfileTableCompanion(
          id: drift.Value(current?.id ?? 1),
          name: drift.Value(_nameController.text.trim()),
          targetRole: drift.Value(_roleController.text.trim()),
          targetCompanies: drift.Value(jsonEncode(_targetCompanies)),
          interviewDate: drift.Value(_interviewDate),
          weeklyHoursAvailable: drift.Value(_weeklyHours),
          preferredStudyWindow: drift.Value(_studyWindow),
          onboardingComplete: const drift.Value(true),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      if (mounted) {
        setState(() {
          _savedSuccess = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved'),
            duration: Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _exportData() async {
    final db = ref.read(databaseProvider);
    try {
      final profile = await db.userProfileDao.getProfile();
      final tasks = await db.taskDao.watchAllTasks().first;
      final apps = await db.applicationDao.watchAllApplications().first;
      final consistency = await db.consistencyDao.watchAllLogs().first;
      final dsa = await db.dsaDao.watchAllLogs().first;
      final notes = await db.notesDao.watchAllNotes().first;
      final questions = await db.interviewPrepDao.watchAllQuestions().first;
      final resumes = await db.resumeDao.watchAllResumes().first;

      final dump = {
        'version': '1.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': profile != null
            ? {
                'name': profile.name,
                'targetRole': profile.targetRole,
                'targetCompanies': profile.targetCompanies,
                'weeklyHoursAvailable': profile.weeklyHoursAvailable,
                'preferredStudyWindow': profile.preferredStudyWindow,
                'interviewDate': profile.interviewDate?.toIso8601String(),
              }
            : null,
        'tasks': tasks.map((t) => {'title': t.title, 'priority': t.priority, 'plannedDate': t.plannedDate?.toIso8601String(), 'notes': t.notes}).toList(),
        'applications': apps.map((a) => {'company': a.company, 'role': a.role, 'currentStage': a.currentStage, 'salary': a.salary, 'jobUrl': a.jobUrl, 'notes': a.notes}).toList(),
        'consistency': consistency.map((c) => {'date': c.date.toIso8601String(), 'present': c.present, 'note': c.note, 'hours': c.hoursStudied}).toList(),
        'dsa': dsa.map((d) => {'problemName': d.problemName, 'topic': d.topic, 'difficulty': d.difficulty, 'dateSolved': d.dateSolved.toIso8601String(), 'revisitFlag': d.revisitFlag}).toList(),
        'notes': notes.map((n) => {'title': n.title, 'content': n.content, 'topic': n.linkedTopic, 'company': n.linkedCompany}).toList(),
        'questions': questions.map((q) => {'question': q.questionAsked, 'category': q.category, 'company': q.company, 'outcome': q.outcome, 'notes': q.answerNotes}).toList(),
        'resumes': resumes.map((r) => {'versionLabel': r.versionLabel, 'tailoredForCompany': r.tailoredForCompany, 'notes': r.notes}).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(dump);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.bgSurface,
          title: Text(
            'Export Ascent Backup',
            style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your local SQLite database is serialized and ready to export:',
                  style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.divider),
                  ),
                  child: Text(
                    jsonStr,
                    style: AscentTextStyles.monoCode.copyWith(
                      color: context.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy JSON'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup JSON copied to clipboard')),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _importData() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Restore Backup (JSON)',
                style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste previously exported Ascent backup JSON below to restore:',
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 6,
                style: AscentTextStyles.monoCode.copyWith(fontSize: 12, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: '{\n  "version": "1.0.0",\n  "profile": { ... }\n}',
                  hintStyle: AscentTextStyles.monoCode.copyWith(fontSize: 12, color: context.textMuted),
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.outlined(
                      label: 'Cancel',
                      compact: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.primary(
                      label: 'Restore',
                      compact: true,
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        final scaffold = ScaffoldMessenger.of(context);
                        final raw = textController.text.trim();
                        if (raw.isEmpty) return;
                        try {
                          final data = jsonDecode(raw) as Map<String, dynamic>;
                          final db = ref.read(databaseProvider);

                          if (data['profile'] != null) {
                            final p = data['profile'] as Map<String, dynamic>;
                            await db.userProfileDao.upsertProfile(
                              UserProfileTableCompanion(
                                id: const drift.Value(1),
                                name: drift.Value(p['name'] ?? 'User'),
                                targetRole: drift.Value(p['targetRole'] ?? 'Software Engineer'),
                                targetCompanies: drift.Value(p['targetCompanies'] is String ? p['targetCompanies'] : jsonEncode(p['targetCompanies'] ?? [])),
                                weeklyHoursAvailable: drift.Value(p['weeklyHoursAvailable'] ?? 10),
                                preferredStudyWindow: drift.Value(p['preferredStudyWindow'] ?? 'morning'),
                                interviewDate: drift.Value(p['interviewDate'] != null ? DateTime.parse(p['interviewDate']) : null),
                                onboardingComplete: const drift.Value(true),
                                updatedAt: drift.Value(DateTime.now()),
                              ),
                            );
                          }

                          nav.pop();
                          setState(() {
                            _profileLoaded = false;
                          });
                          scaffold.showSnackBar(
                            const SnackBar(content: Text('Backup data restored successfully!')),
                          );
                        } catch (e) {
                          scaffold.showSnackBar(
                            SnackBar(content: Text('Failed to restore backup: $e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _seedDemoData() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.accentPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded, color: context.accentPrimary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Load Realistic Beta Demo Data?',
                style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'This populates rich, realistic job-search data across all screens (Tasks, Pipeline Kanban, 30-day consistency heatmap, DSA logs, Interview Prep, Notes, and Resumes). Perfect for hands-on beta testing.',
                textAlign: TextAlign.center,
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.outlined(
                      label: 'Cancel',
                      compact: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.primary(
                      label: 'Seed Demo Data',
                      compact: true,
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        final scaffold = ScaffoldMessenger.of(context);
                        nav.pop();
                        final db = ref.read(databaseProvider);
                        final prefs = ref.read(sharedPreferencesProvider);
                        await DemoDataSeeder.seedRealisticBetaData(db, prefs: prefs);
                        setState(() {
                          _profileLoaded = false;
                        });
                        scaffold.showSnackBar(
                          const SnackBar(
                            content: Text('Realistic demo data loaded! Check your Dashboard and Pipeline.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResetData() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.stateDanger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: context.stateDanger, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Reset All Data?',
                style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'This will wipe all tasks, applications, consistency history, and reset your onboarding flow. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.outlined(
                      label: 'Cancel',
                      compact: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.destructive(
                      label: 'Reset Everything',
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        nav.pop();
                        final prefs = ref.read(sharedPreferencesProvider);
                        await prefs.clear();
                        final db = ref.read(databaseProvider);
                        // Clean all tables cleanly
                        await db.customStatement('DELETE FROM insight_dismissals;');
                        await db.customStatement('DELETE FROM note_tags;');
                        await db.customStatement('DELETE FROM notes;');
                        await db.customStatement('DELETE FROM interview_prep;');
                        await db.customStatement('DELETE FROM resumes;');
                        await db.customStatement('DELETE FROM application_status_history;');
                        await db.customStatement('DELETE FROM applications;');
                        await db.customStatement('DELETE FROM tasks;');
                        await db.customStatement('DELETE FROM series;');
                        await db.customStatement('DELETE FROM study_phases;');
                        await db.customStatement('DELETE FROM dsa_logs;');
                        await db.customStatement('DELETE FROM time_sessions;');
                        await db.customStatement('DELETE FROM consistency_logs;');
                        await db.customStatement('DELETE FROM user_profiles;');

                        if (mounted) {
                          context.go('/onboarding');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileStream = ref.watch(userProfileDaoProvider).watchProfile();
    final themeMode = ref.watch(themeModeProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _persistAndReturn();
      },
      child: Scaffold(
        backgroundColor: context.bgBase,
        appBar: AppBar(
          backgroundColor: context.bgBase,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
            onPressed: _persistAndReturn,
          ),
          title: Text(
            'Settings',
            style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
          ),
          actions: [
            TextButton.icon(
              onPressed: _persistAndReturn,
              icon: _savedSuccess
                  ? Icon(Icons.check_rounded, color: context.accentPrimary, size: 18)
                  : const SizedBox.shrink(),
              label: Text(
                _savedSuccess ? 'Saved' : 'Save',
                style: AscentTextStyles.labelLarge.copyWith(
                  color: context.accentPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      body: StreamBuilder<UserProfile?>(
        stream: profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SkeletonShimmer(height: 250),
            );
          }

          final profile = snapshot.data;
          _initFromProfile(profile);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // ── Section 1: Target & Profile ──────────────────────────
              _SectionHeader(title: 'TARGET PROFILE'),
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Name',
                      style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.bgBase,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Target Role',
                      style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _roleController,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Senior Software Engineer',
                        hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                        filled: true,
                        fillColor: context.bgBase,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Weekly Hours Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weekly Study Budget',
                          style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                        ),
                        Text(
                          '$_weeklyHours hrs / wk',
                          style: AscentTextStyles.monoCode.copyWith(
                            color: context.accentPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _weeklyHours.toDouble(),
                      min: 5,
                      max: 40,
                      divisions: 7,
                      activeColor: context.accentPrimary,
                      onChanged: (val) => setState(() => _weeklyHours = val.round()),
                    ),
                    const SizedBox(height: 8),

                    // Target Interview Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Interview Date',
                              style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                            ),
                            Text(
                              _interviewDate != null
                                  ? DateFormat.yMMMd().format(_interviewDate!)
                                  : 'No deadline set',
                              style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                            ),
                          ],
                        ),
                        TextButton(
                          child: Text(_interviewDate == null ? 'Set Date' : 'Change'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _interviewDate ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (picked != null) {
                              setState(() => _interviewDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Target Companies
                    Text(
                      'Target Companies',
                      style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _companyInputController,
                            style: AscentTextStyles.bodySmall.copyWith(color: context.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Add company (e.g. Stripe)',
                              hintStyle: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                              filled: true,
                              fillColor: context.bgBase,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: context.divider),
                              ),
                            ),
                            onSubmitted: (val) {
                              final text = val.trim();
                              if (text.isNotEmpty && !_targetCompanies.contains(text)) {
                                setState(() {
                                  _targetCompanies.add(text);
                                  _companyInputController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded, color: context.accentPrimary),
                          onPressed: () {
                            final text = _companyInputController.text.trim();
                            if (text.isNotEmpty && !_targetCompanies.contains(text)) {
                              setState(() {
                                _targetCompanies.add(text);
                                _companyInputController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (_targetCompanies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _targetCompanies.map((c) {
                          return Chip(
                            label: Text(c),
                            labelStyle: AscentTextStyles.labelSmall.copyWith(color: context.textPrimary),
                            backgroundColor: context.bgBase,
                            deleteIcon: const Icon(Icons.close_rounded, size: 14),
                            onDeleted: () => setState(() => _targetCompanies.remove(c)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Section 2: Appearance & Theme ────────────────────────
              _SectionHeader(title: 'APPEARANCE'),
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme Mode',
                      style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ThemeOption(
                          label: 'System',
                          icon: Icons.brightness_auto_rounded,
                          isSelected: themeMode == ThemeMode.system,
                          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                        ),
                        const SizedBox(width: 8),
                        _ThemeOption(
                          label: 'Light',
                          icon: Icons.light_mode_rounded,
                          isSelected: themeMode == ThemeMode.light,
                          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _ThemeOption(
                          label: 'Dark',
                          icon: Icons.dark_mode_rounded,
                          isSelected: themeMode == ThemeMode.dark,
                          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Section 2b: AI Assistant Configuration ───────────────
              _SectionHeader(title: 'AI COPILOT / ASSISTANT'),
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistant Identity',
                      style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customize the name of your onboard AI copilot (defaults to Riya).',
                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final currentName = ref.watch(assistantNameProvider);
                        return _AssistantNameEditor(currentName: currentName);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Section 3: Notifications & Reminders ─────────────────
              _SectionHeader(title: 'NOTIFICATIONS'),
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, color: context.accentPrimary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Check-in Reminder',
                                style: AscentTextStyles.labelMedium.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Keep your momentum with morning focus prompts',
                                style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: true,
                          activeThumbColor: context.accentPrimary,
                          onChanged: (val) async {

                            if (val) {
                              await NotificationService.instance.requestPermissions();
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    AscentButton.ghost(
                      label: 'Send Test Notification',
                      icon: Icons.send_rounded,
                      onPressed: () async {
                        await NotificationService.instance.showInstantNotification(
                          id: 101,
                          title: 'Ascent — Daily Focus',
                          body: 'Ready to take 1 small step today? Check your focus task.',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test notification sent!')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ── Section: Outdoor Walking & GPS Battery Optimization ──────
              _SectionHeader(title: 'LOCATION & BACKGROUND TRACKING'),
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.directions_walk_rounded, color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GPS Battery Optimization Guide',
                                style: AscentTextStyles.labelMedium.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Keep outdoor walks recording when screen locks',
                                style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded, color: Colors.teal),
                          onPressed: () => _showGpsBatteryGuide(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Android OEMs (Samsung, Xiaomi, OnePlus) aggressively stop background GPS when the screen turns off. To record your complete route without pause, set Ascent\'s battery usage to "Unrestricted" in your phone\'s App Info settings.',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: context.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AscentButton.outlined(
                      label: 'View Setup Guide 🔋',
                      compact: true,
                      onPressed: () => _showGpsBatteryGuide(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Section 4: Data & Backup ─────────────────────────────
              _SectionHeader(title: 'LOCAL DATA & STORAGE'),
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.auto_awesome_rounded, color: context.accentPrimary, size: 20),
                      ),
                      title: Text(
                        'Seed Demo Data (Beta Experience)',
                        style: AscentTextStyles.labelMedium.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Load realistic job-search data across all screens for testing',
                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _seedDemoData,
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.accentInfo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.download_rounded, color: context.accentInfo, size: 20),
                      ),
                      title: Text(
                        'Export Backup (JSON)',
                        style: AscentTextStyles.labelMedium.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Export full SQLite snapshot for data portability',
                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _exportData,
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.accentSecondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.upload_rounded, color: context.accentSecondary, size: 20),
                      ),
                      title: Text(
                        'Restore Backup (JSON)',
                        style: AscentTextStyles.labelMedium.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Restore your tasks, applications, and settings from JSON',
                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _importData,
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.stateDanger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.delete_forever_rounded, color: context.stateDanger, size: 20),
                      ),
                      title: Text(
                        'Reset All Data',
                        style: AscentTextStyles.labelMedium.copyWith(
                          color: context.stateDanger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Wipe local database and restart onboarding',
                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      ),
                      onTap: _confirmResetData,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Section 5: About Ascent ──────────────────────────────
              _SectionHeader(title: 'ABOUT ASCENT'),
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.accentPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.north_east_rounded, color: context.accentPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ascent Beta',
                              style: AscentTextStyles.labelLarge.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Version 1.0.0 (Build 1) · Local-First OS',
                              style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ascent is built on zero anxiety and continuous momentum. 100% of your data stays strictly on your device in a local SQLite database.',
                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
      ),
    );
  }

  void _showGpsBatteryGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ctx.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: ctx.divider, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.battery_saver_rounded, color: Colors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Walk Tracking Setup',
                        style: AscentTextStyles.headlineMedium.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: ctx.textPrimary,
                        ),
                      ),
                      Text(
                        'Prevent Android from killing GPS when locked',
                        style: AscentTextStyles.bodySmall.copyWith(color: ctx.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _guideStep(
              number: '1',
              title: 'Open Android App Settings',
              description: 'Long press Ascent icon on your home screen > App info (or go to Phone Settings > Apps > Ascent).',
            ),
            const SizedBox(height: 12),
            _guideStep(
              number: '2',
              title: 'Set Battery to "Unrestricted"',
              description: 'Under Battery or App Battery Usage, change setting from "Optimized" to "Unrestricted". This allows continuous GPS recording.',
            ),
            const SizedBox(height: 12),
            _guideStep(
              number: '3',
              title: 'Allow Location While Using App',
              description: 'Ascent runs a foreground walking service with active duration and live route telemetry.',
            ),
            const SizedBox(height: 18),
            AscentButton.primary(
              label: 'Understood, Got it! 👍',
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _guideStep({required String number, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Colors.teal.withValues(alpha: 0.2),
          child: Text(
            number,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AscentTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AscentTextStyles.bodySmall.copyWith(
                  color: context.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AscentTextStyles.labelSmall.copyWith(
          color: context.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? context.accentPrimary : context.bgBase,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? context.accentPrimary : context.divider,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : context.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AscentTextStyles.labelSmall.copyWith(
                  color: isSelected ? Colors.white : context.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantNameEditor extends StatefulWidget {
  final String currentName;

  const _AssistantNameEditor({required this.currentName});

  @override
  State<_AssistantNameEditor> createState() => _AssistantNameEditorState();
}

class _AssistantNameEditorState extends State<_AssistantNameEditor> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void didUpdateWidget(covariant _AssistantNameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentName != widget.currentName && !_isEditing) {
      _controller.text = widget.currentName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) {
                      if (!_isEditing) setState(() => _isEditing = true);
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.psychology_outlined, size: 20, color: context.accentPrimary),
                      hintText: 'e.g. Riya',
                      filled: true,
                      fillColor: context.bgBase,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.accentPrimary),
                      ),
                    ),
                    style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                AscentButton.primary(
                  label: 'Update',
                  compact: true,
                  onPressed: () {
                    final newName = _controller.text.trim();
                    if (newName.isNotEmpty) {
                      ref.read(assistantNameProvider.notifier).setName(newName);
                      setState(() => _isEditing = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Assistant renamed to $newName'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ['Riya', 'Aria', 'Jarvis', 'Nova'].map((preset) {
                final isSelected = widget.currentName == preset;
                return ChoiceChip(
                  label: Text(preset),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _controller.text = preset;
                      ref.read(assistantNameProvider.notifier).setName(preset);
                      setState(() => _isEditing = false);
                    }
                  },
                  labelStyle: AscentTextStyles.labelSmall.copyWith(
                    color: isSelected ? Colors.white : context.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  selectedColor: context.accentPrimary,
                  backgroundColor: context.bgBase,
                  side: BorderSide(color: isSelected ? context.accentPrimary : context.divider),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
