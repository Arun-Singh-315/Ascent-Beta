import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import 'drop_thought_sheet.dart';

/// Formats thought content cleanly for WhatsApp, messages, and external sharing.
String formatThoughtForShare(Thought thought) {
  final buffer = StringBuffer();
  if (thought.promptQuestion != null &&
      thought.promptQuestion!.trim().isNotEmpty) {
    buffer.writeln('💭 Prompt: ${thought.promptQuestion!.trim()}\n');
  }
  buffer.writeln('"${thought.content.trim()}"');
  buffer.writeln('\n— Mind Space · Ascent');
  return buffer.toString();
}

/// Formats multiple selected thoughts cleanly for WhatsApp and messaging apps.
String formatMultipleThoughtsForShare(List<Thought> thoughts) {
  if (thoughts.isEmpty) return '';
  if (thoughts.length == 1) {
    return formatThoughtForShare(thoughts.first);
  }

  final buffer = StringBuffer();
  buffer.writeln('✦ MIND SPACE REFLECTIONS ✦');
  buffer.writeln('Ascent · Notes to Myself\n');

  for (int i = 0; i < thoughts.length; i++) {
    final t = thoughts[i];
    buffer.writeln('── [Note ${i + 1}/${thoughts.length}] ──');
    if (t.promptQuestion != null && t.promptQuestion!.trim().isNotEmpty) {
      buffer.writeln('💭 Prompt: ${t.promptQuestion!.trim()}');
    }
    buffer.writeln('"${t.content.trim()}"');
    buffer.writeln();
  }
  buffer.writeln('— Shared from Mind Space · Ascent');
  return buffer.toString().trim();
}

/// Triggers system share sheet to share thought directly to WhatsApp or any installed app.
Future<void> shareThought(Thought thought) async {
  HapticFeedback.lightImpact();
  final text = formatThoughtForShare(thought);
  await SharePlus.instance.share(
    ShareParams(text: text, subject: 'Mind Space Reflection'),
  );
}

/// Triggers system share sheet to batch-share thoughts directly to WhatsApp or any installed app.
Future<void> shareMultipleThoughts(List<Thought> thoughts) async {
  if (thoughts.isEmpty) return;
  HapticFeedback.lightImpact();
  final text = formatMultipleThoughtsForShare(thoughts);
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: 'Mind Space Reflections (${thoughts.length} notes)',
    ),
  );
}

/// Thought Wall / Mind Space Screen ("Me to Me")
/// An aesthetic spatial wall for unfiltered self-talk, sparks of inspiration,
/// daily wins, and letters to your future self.
class ThoughtWallScreen extends ConsumerStatefulWidget {
  const ThoughtWallScreen({super.key});

  @override
  ConsumerState<ThoughtWallScreen> createState() => _ThoughtWallScreenState();
}

class _ThoughtWallScreenState extends ConsumerState<ThoughtWallScreen> {
  String _viewToggle = 'today'; // 'today', 'history'
  String _categoryFilter =
      'all'; // 'all', 'me_to_me', 'thought', 'idea', 'win', 'pinned'
  final String _activeFilter = 'all';
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = <int>{};

  final Map<String, (String, IconData)> _filterMeta = const {
    'all': ('All Thoughts', Icons.bubble_chart_rounded),
    'me_to_me': ('Me to Me', Icons.psychology_alt_rounded),
    'thought': ('Raw Thoughts', Icons.insights_rounded),
    'idea': ('Sparks', Icons.lightbulb_rounded),
    'win': ('Wins', Icons.emoji_events_rounded),
    'future': ('Future Me', Icons.schedule_send_rounded),
    'promise': ('Promises', Icons.handshake_rounded),
    'pinned': ('Pinned', Icons.push_pin_rounded),
    'archived': ('Archived', Icons.archive_outlined),
  };

  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _promiseDaysController = TextEditingController(
    text: '30',
  );
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _composerMood = 'me_to_me';
  bool _hasInputText = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (_hasInputText != hasText) {
      setState(() => _hasInputText = hasText);
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _promiseDaysController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'me_to_me':
        return const Color(0xFF6366F1);
      case 'idea':
        return const Color(0xFFD97706);
      case 'win':
        return const Color(0xFF16A34A);
      case 'future':
        return const Color(0xFFEA580C);
      case 'promise':
        return const Color(0xFF7C3AED);
      case 'thought':
      default:
        return const Color(0xFF0284C7);
    }
  }

  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'me_to_me':
        return Icons.psychology_alt_rounded;
      case 'idea':
        return Icons.lightbulb_rounded;
      case 'win':
        return Icons.emoji_events_rounded;
      case 'future':
        return Icons.schedule_send_rounded;
      case 'promise':
        return Icons.handshake_rounded;
      case 'thought':
      default:
        return Icons.insights_rounded;
    }
  }

  String _getComposerHint() {
    final effectiveMood =
        _activeFilter != 'all' &&
            _activeFilter != 'pinned' &&
            _activeFilter != 'archived'
        ? _activeFilter
        : _composerMood;
    switch (effectiveMood) {
      case 'me_to_me':
        return 'Message to myself...';
      case 'idea':
        return 'Capture a spark or idea...';
      case 'win':
        return 'Celebrate a win today...';
      case 'future':
        return 'Note for my future self...';
      case 'promise':
        return 'Write a promise you want to keep...';
      case 'thought':
      default:
        return 'Raw unfiltered thought...';
    }
  }

  PopupMenuItem<String> _buildMoodMenuItem(
    String key,
    String label,
    IconData icon,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: key,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Text(label, style: AscentTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _submitThought() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    HapticFeedback.mediumImpact();

    final mood =
        _activeFilter != 'all' &&
            _activeFilter != 'pinned' &&
            _activeFilter != 'archived'
        ? _activeFilter
        : _composerMood;

    final moodColor = _getMoodColor(mood);
    final colorHex = '#${moodColor.toARGB32().toRadixString(16)}';

    final validityDays = int.tryParse(_promiseDaysController.text.trim());
    if (mood == 'promise' &&
        (validityDays == null || validityDays < 1 || validityDays > 365)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promise duration must be between 1 and 365 days.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (mood == 'promise') {
        await ref
            .read(promiseServiceProvider)
            .create(content: text, validityDays: validityDays!);
      } else {
        await ref
            .read(thoughtDaoProvider)
            .insertThought(
              ThoughtTableCompanion.insert(
                content: text,
                mood: drift.Value(mood),
                colorHex: drift.Value(colorHex),
                isPinned: const drift.Value(false),
              ),
            );
      }
      _inputController.clear();
      if (mood == 'promise') {
        _promiseDaysController.text = '30';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mood == 'promise'
                ? 'Promise added to Today with $validityDays daily reminders.'
                : 'Added to your Thought Wall.',
          ),
        ),
      );

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSelectionBottomBar(
    BuildContext context,
    AscentGlass g,
    List<Thought> allThoughts,
  ) {
    final selectedList = allThoughts
        .where((t) => _selectedIds.contains(t.id))
        .toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: g.fill,
        border: Border(top: BorderSide(color: g.edge, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.close_rounded, color: g.inkMuted),
              onPressed: _exitSelectionMode,
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedIds.length} Selected',
              style: AscentTextStyles.bodyMedium.copyWith(
                color: g.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share to WhatsApp'),
              onPressed: selectedList.isEmpty
                  ? null
                  : () => shareMultipleThoughts(selectedList),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppComposer(BuildContext context, AscentGlass g) {
    final activeMood =
        _activeFilter != 'all' &&
            _activeFilter != 'pinned' &&
            _activeFilter != 'archived'
        ? _activeFilter
        : _composerMood;
    final moodColor = _getMoodColor(activeMood);
    final moodIcon = _getMoodIcon(activeMood);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: g.bg,
        border: Border(
          top: BorderSide(color: g.edge.withValues(alpha: 0.5), width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeMood == 'promise')
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: moodColor,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Remind me daily for',
                      style: AscentTextStyles.captionMedium.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 62,
                      child: TextField(
                        controller: _promiseDaysController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        textAlign: TextAlign.center,
                        style: AscentTextStyles.labelMedium.copyWith(
                          color: g.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          suffixText: 'd',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 7,
                          ),
                          filled: true,
                          fillColor: context.bgSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '1–365 days',
                      style: AscentTextStyles.captionMedium.copyWith(
                        color: g.inkMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Category/Mood Picker
                PopupMenuButton<String>(
                  tooltip: 'Category: $activeMood',
                  initialValue: activeMood,
                  onSelected: (val) {
                    HapticFeedback.lightImpact();
                    setState(() => _composerMood = val);
                  },
                  color: context.bgSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: g.edge),
                  ),
                  itemBuilder: (context) => [
                    _buildMoodMenuItem(
                      'me_to_me',
                      'Me to Me',
                      Icons.psychology_alt_rounded,
                      const Color(0xFF6366F1),
                    ),
                    _buildMoodMenuItem(
                      'thought',
                      'Raw Thought',
                      Icons.insights_rounded,
                      const Color(0xFF0284C7),
                    ),
                    _buildMoodMenuItem(
                      'idea',
                      'Spark / Idea',
                      Icons.lightbulb_rounded,
                      const Color(0xFFD97706),
                    ),
                    _buildMoodMenuItem(
                      'win',
                      'Daily Win',
                      Icons.emoji_events_rounded,
                      const Color(0xFF16A34A),
                    ),
                    _buildMoodMenuItem(
                      'future',
                      'Future Me',
                      Icons.schedule_send_rounded,
                      const Color(0xFFEA580C),
                    ),
                    _buildMoodMenuItem(
                      'promise',
                      'Promise',
                      Icons.handshake_rounded,
                      const Color(0xFF7C3AED),
                    ),
                  ],
                  child: Container(
                    height: 40,
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: moodColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: moodColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(moodIcon, size: 19, color: moodColor),
                  ),
                ),
                const SizedBox(width: 8),
                // Text Input Pill (Clean WhatsApp / Telegram single pill with zero inner borders)
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: context.bgSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: g.edge.withValues(alpha: 0.6),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: g.ink,
                            ),
                            cursorColor: g.clay,
                            decoration: InputDecoration(
                              hintText: _getComposerHint(),
                              hintStyle: AscentTextStyles.bodyMedium.copyWith(
                                color: g.inkMuted.withValues(alpha: 0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4, bottom: 2),
                          child: IconButton(
                            icon: Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: g.inkMuted,
                            ),
                            tooltip: 'Guided Reflection Prompts',
                            splashRadius: 18,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              DropThoughtSheet.show(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Floating Send Button
                GestureDetector(
                  onTap: _hasInputText && !_isSubmitting
                      ? _submitThought
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 42,
                    width: activeMood == 'promise' ? 118 : 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasInputText ? g.clay : g.fill,
                      border: Border.all(
                        color: _hasInputText ? g.clay : g.edge,
                      ),
                      boxShadow: _hasInputText
                          ? [
                              BoxShadow(
                                color: g.clay.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: activeMood == 'promise'
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.handshake_rounded,
                                size: 17,
                                color: _hasInputText
                                    ? Colors.white
                                    : g.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Add Promise',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: _hasInputText
                                      ? Colors.white
                                      : g.inkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Icon(
                            _isSubmitting
                                ? Icons.hourglass_top_rounded
                                : Icons.send_rounded,
                            size: 18,
                            color: _hasInputText
                                ? Colors.white
                                : g.inkMuted.withValues(alpha: 0.35),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(int id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll(List<Thought> thoughts) {
    HapticFeedback.lightImpact();
    setState(() {
      final allIds = thoughts.map((t) => t.id).toSet();
      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(allIds);
        _isSelectionMode = true;
      }
    });
  }

  Widget _buildViewSegment(String key, String label, IconData icon, dynamic g) {
    final isSelected = _viewToggle == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _viewToggle = key);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? g.clay : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : g.inkMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : g.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(allThoughtsStreamProvider);
    final archivedAsync = ref.watch(archivedThoughtsStreamProvider);

    final g = context.glass;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: AscentScaffold(
        title: _isSelectionMode
            ? '${_selectedIds.length} Selected'
            : 'Thought Wall',
        subtitle: _isSelectionMode
            ? 'Select thoughts to share to WhatsApp'
            : 'Mind space • Me to Me talk',
        glow2: g.slate,
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: g.ink),
                tooltip: 'Exit selection',
                onPressed: _exitSelectionMode,
              )
            : null,
        onBack: _isSelectionMode ? _exitSelectionMode : null,
        actions: _isSelectionMode
            ? [
                activeAsync.maybeWhen(
                  data: (activeList) {
                    final archivedList = archivedAsync.value ?? [];
                    final allThoughts = [...activeList, ...archivedList];
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);
                    final filtered = allThoughts.where((t) {
                      if (_categoryFilter == 'pinned' && !t.isPinned) {
                        return false;
                      }
                      if (_categoryFilter == 'archived') return t.isArchived;
                      if (_categoryFilter != 'all' &&
                          _categoryFilter != 'pinned' &&
                          t.mood != _categoryFilter) {
                        return false;
                      }
                      if (_viewToggle == 'today') {
                        return !t.isArchived &&
                            t.createdAt.isAfter(
                              todayStart.subtract(const Duration(seconds: 1)),
                            );
                      } else {
                        return t.isArchived || t.createdAt.isBefore(todayStart);
                      }
                    }).toList();

                    final isAllSelected =
                        filtered.isNotEmpty &&
                        _selectedIds.length >= filtered.length;

                    return IconButton(
                      icon: Icon(
                        isAllSelected
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        color: g.clay,
                      ),
                      tooltip: isAllSelected ? 'Deselect All' : 'Select All',
                      onPressed: () => _toggleSelectAll(filtered),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                IconButton(
                  icon: Icon(Icons.share_rounded, color: g.clay),
                  tooltip: 'Share to WhatsApp',
                  onPressed: () {
                    final activeList = activeAsync.value ?? [];
                    final archivedList = archivedAsync.value ?? [];
                    final allThoughts = [...activeList, ...archivedList];
                    final selectedList = allThoughts
                        .where((t) => _selectedIds.contains(t.id))
                        .toList();
                    shareMultipleThoughts(selectedList);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: g.inkMuted),
                  tooltip: 'Exit Selection',
                  onPressed: _exitSelectionMode,
                ),
              ]
            : [
                TextButton.icon(
                  icon: const Icon(Icons.handshake_rounded, size: 17),
                  label: const Text('Add Promise'),
                  onPressed: () =>
                      DropThoughtSheet.show(context, initialMood: 'promise'),
                ),
              ],
        body: Column(
          children: [
            // Segmented 2-Way Toggle: Today | History & Archive
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.divider.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                children: [
                  _buildViewSegment('today', "Today", Icons.today_rounded, g),
                  _buildViewSegment(
                    'history',
                    "History & Archive",
                    Icons.history_rounded,
                    g,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Sub-bar: Category Selector & Title that fits directly on screen (NO horizontal swipe)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
              child: Row(
                children: [
                  Text(
                    _viewToggle == 'today'
                        ? 'TODAY\'S REFLECTIONS'
                        : 'PAST & ARCHIVED',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.textMuted,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Category filter',
                    initialValue: _categoryFilter,
                    onSelected: (val) {
                      HapticFeedback.lightImpact();
                      setState(() => _categoryFilter = val);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _filterMeta[_categoryFilter]?.$2 ??
                                Icons.filter_alt_outlined,
                            size: 13,
                            color: _categoryFilter != 'all'
                                ? g.clay
                                : context.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _categoryFilter == 'all'
                                ? 'All Moods'
                                : (_filterMeta[_categoryFilter]?.$1 ??
                                      'Filter'),
                            style: AscentTextStyles.captionMedium.copyWith(
                              color: _categoryFilter != 'all'
                                  ? g.clay
                                  : context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: context.textMuted,
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'all',
                        child: Text('All Moods'),
                      ),
                      const PopupMenuItem(
                        value: 'me_to_me',
                        child: Text('Me to Me'),
                      ),
                      const PopupMenuItem(
                        value: 'thought',
                        child: Text('Raw Thoughts'),
                      ),
                      const PopupMenuItem(
                        value: 'idea',
                        child: Text('Sparks / Ideas'),
                      ),
                      const PopupMenuItem(
                        value: 'win',
                        child: Text('Daily Wins'),
                      ),
                      const PopupMenuItem(
                        value: 'promise',
                        child: Text('Promises'),
                      ),
                      const PopupMenuItem(
                        value: 'pinned',
                        child: Text('Pinned Only'),
                      ),
                      const PopupMenuItem(
                        value: 'archived',
                        child: Text('Archived Only'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Main Wall Content
            Expanded(
              child: activeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) =>
                    Center(child: Text('Error loading wall: $err')),
                data: (activeList) {
                  final archivedList = archivedAsync.value ?? [];
                  final allThoughts = [...activeList, ...archivedList];
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);

                  final filtered = allThoughts.where((t) {
                    if (_categoryFilter == 'pinned' && !t.isPinned) {
                      return false;
                    }
                    if (_categoryFilter == 'archived') return t.isArchived;
                    if (_categoryFilter != 'all' &&
                        _categoryFilter != 'pinned' &&
                        t.mood != _categoryFilter) {
                      return false;
                    }

                    if (_viewToggle == 'today') {
                      return !t.isArchived &&
                          t.createdAt.isAfter(
                            todayStart.subtract(const Duration(seconds: 1)),
                          );
                    } else {
                      return t.isArchived || t.createdAt.isBefore(todayStart);
                    }
                  }).toList();

                  if (filtered.isEmpty) {
                    return EmptyState(
                      title: _categoryFilter == 'archived'
                          ? 'No archived reflections'
                          : (_viewToggle == 'today'
                                ? 'No thoughts logged today'
                                : 'No past or archived reflections'),
                      subtitle: _categoryFilter == 'archived'
                          ? 'Reflections you archive from the wall will be safely stored here.'
                          : 'Drop an unfiltered reflection, spark of idea, or note to yourself.',
                      icon: _categoryFilter == 'archived'
                          ? Icons.archive_outlined
                          : Icons.bubble_chart_rounded,
                      actionLabel: 'Drop a Thought',
                      onAction: () => DropThoughtSheet.show(context),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final thought = filtered[index];
                      return ThoughtCardBubble(
                        thought: thought,
                        index: index,
                        isSelected: _selectedIds.contains(thought.id),
                        isSelectionMode: _isSelectionMode,
                        onToggleSelect: () => _toggleSelection(thought.id),
                        onLongPress: () => _enterSelectionMode(thought.id),
                      );
                    },
                  );
                },
              ),
            ),
            // WhatsApp Messenger Composer or Selection Bar
            _isSelectionMode
                ? _buildSelectionBottomBar(context, g, [
                    ...(activeAsync.value ?? []),
                    ...(archivedAsync.value ?? []),
                  ])
                : _buildWhatsAppComposer(context, g),
          ],
        ),
      ),
    );
  }
}

class ThoughtCardBubble extends ConsumerWidget {
  final Thought thought;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const ThoughtCardBubble({
    super.key,
    required this.thought,
    required this.index,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggleSelect,
    this.onLongPress,
  });

  IconData _moodIcon(String mood) {
    switch (mood) {
      case 'me_to_me':
        return Icons.psychology_alt_rounded;
      case 'idea':
        return Icons.lightbulb_rounded;
      case 'win':
        return Icons.emoji_events_rounded;
      case 'future':
        return Icons.schedule_send_rounded;
      case 'promise':
        return Icons.handshake_rounded;
      case 'thought':
      default:
        return Icons.insights_rounded;
    }
  }

  String _moodLabel(String mood) {
    switch (mood) {
      case 'me_to_me':
        return 'Me to Me';
      case 'idea':
        return 'Idea';
      case 'win':
        return 'Daily Win';
      case 'future':
        return 'Future Self';
      case 'promise':
        return 'Promise';
      case 'thought':
      default:
        return 'Raw Thought';
    }
  }

  Color _moodColor(String mood) {
    switch (mood) {
      case 'me_to_me':
        return const Color(0xFF6366F1); // Refined Indigo
      case 'idea':
        return const Color(0xFFD97706); // Warm Amber
      case 'win':
        return const Color(0xFF16A34A); // Sage Green
      case 'future':
        return const Color(0xFFEA580C); // Terracotta
      case 'promise':
        return const Color(0xFF7C3AED);
      case 'thought':
      default:
        return const Color(0xFF0284C7); // Sky Deep
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodColor = _moodColor(thought.mood);
    final icon = _moodIcon(thought.mood);
    final label = _moodLabel(thought.mood);
    final timeStr = DateFormat('MMM d • h:mm a').format(thought.createdAt);
    final g = context.glass;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 14,
          left: (index % 2 == 1) ? 38.0 : 4.0,
          right: (index % 2 == 0) ? 38.0 : 4.0,
        ),
        child: Dismissible(
          key: ValueKey('thought_${thought.id}'),
          direction: isSelectionMode
              ? DismissDirection.none
              : DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            final thoughtDao = ref.read(thoughtDaoProvider);
            if (direction == DismissDirection.startToEnd) {
              // Archive / Unarchive
              HapticFeedback.mediumImpact();
              if (thought.isArchived) {
                await thoughtDao.unarchiveThought(thought.id);
              } else {
                await thoughtDao.archiveThought(thought.id);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      thought.isArchived
                          ? 'Thought unarchived'
                          : 'Thought archived',
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: context.accentPrimary,
                      onPressed: () async {
                        if (thought.isArchived) {
                          await thoughtDao.archiveThought(thought.id);
                        } else {
                          await thoughtDao.unarchiveThought(thought.id);
                        }
                      },
                    ),
                  ),
                );
              }
              return true;
            } else {
              // Delete
              HapticFeedback.mediumImpact();
              final backup = thought;
              await thoughtDao.deleteThought(thought.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Thought removed'),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: context.accentPrimary,
                      onPressed: () async {
                        await thoughtDao.insertThought(
                          backup.toCompanion(true),
                        );
                      },
                    ),
                  ),
                );
              }
              return true;
            }
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  thought.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  thought.isArchived ? 'Unarchive' : 'Archive',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ],
            ),
          ),
          child: InkWell(
            onTap: isSelectionMode ? onToggleSelect : null,
            onLongPress: isSelectionMode ? onToggleSelect : onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onDoubleTap: isSelectionMode
                  ? onToggleSelect
                  : thought.mood == 'promise'
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      await ref
                          .read(thoughtDaoProvider)
                          .toggleCompleted(thought.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              thought.isCompleted
                                  ? 'Thought marked active'
                                  : 'Thought marked done ✓',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? g.clay.withValues(alpha: 0.22)
                      : (context.isDark ? g.fill : Colors.transparent),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular((index % 2 == 0) ? 4 : 18),
                    bottomRight: Radius.circular((index % 2 == 1) ? 4 : 18),
                  ),
                  border: Border.all(
                    color: isSelected
                        ? g.clay
                        : (thought.isPinned
                              ? (context.isDark
                                    ? Colors.amber.shade400
                                    : Colors.amber.shade700)
                              : (context.isDark
                                    ? g.edge
                                    : Colors.black.withValues(alpha: 0.85))),
                    width: isSelected ? 1.8 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isDark ? 0.30 : 0.06,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top meta header: mood on left, timestamp & action menu on right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isSelectionMode) ...[
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isSelected ? g.clay : g.inkMuted,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: moodColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 11, color: moodColor),
                              const SizedBox(width: 4),
                              Text(
                                label,
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: moodColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Top timestamp
                        Text(
                          timeStr,
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: context.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Right actions (quick unarchive & popup menu)
                        if (thought.isArchived) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.unarchive_outlined,
                              size: 16,
                              color: Colors.amber,
                            ),
                            tooltip: 'Unarchive thought',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(thoughtDaoProvider)
                                  .unarchiveThought(thought.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Thought restored to wall'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 2),
                        ],
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                            color: context.textMuted,
                          ),
                          color: context.bgSurface,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          onSelected: (action) async {
                            if (action == 'share') {
                              await shareThought(thought);
                            } else if (action == 'toggle_done') {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(thoughtDaoProvider)
                                  .toggleCompleted(thought.id);
                            } else if (action == 'convert_task') {
                              HapticFeedback.mediumImpact();
                              final taskDao = ref.read(taskDaoProvider);
                              await taskDao.insertTask(
                                TaskTableCompanion.insert(
                                  title: thought.content.trim(),
                                  plannedDate: drift.Value(DateTime.now()),
                                  notes: drift.Value(
                                    'thought_id:${thought.id}${thought.promptQuestion != null ? ' • ${thought.promptQuestion}' : ''}',
                                  ),
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Added to Today tasks!'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else if (action == 'archive') {
                              HapticFeedback.lightImpact();
                              final dao = ref.read(thoughtDaoProvider);
                              if (thought.isArchived) {
                                await dao.unarchiveThought(thought.id);
                              } else {
                                await dao.archiveThought(thought.id);
                              }
                            } else if (action == 'pin') {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(thoughtDaoProvider)
                                  .togglePin(thought.id);
                            } else if (action == 'copy') {
                              HapticFeedback.lightImpact();
                              await Clipboard.setData(
                                ClipboardData(text: thought.content),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied to clipboard!'),
                                  ),
                                );
                              }
                            } else if (action == 'edit') {
                              HapticFeedback.lightImpact();
                              DropThoughtSheet.show(
                                context,
                                existingThought: thought,
                              );
                            } else if (action == 'open_todo') {
                              context.push('/today');
                            } else if (action == 'track_challenge') {
                              context.push('/momentum', extra: thought);
                            } else if (action == 'delete') {
                              HapticFeedback.mediumImpact();
                              await ref
                                  .read(thoughtDaoProvider)
                                  .deleteThought(thought.id);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit thought'),
                                ],
                              ),
                            ),
                            if (thought.mood != 'promise')
                              PopupMenuItem(
                                value: 'toggle_done',
                                child: Row(
                                  children: [
                                    Icon(
                                      thought.isCompleted
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.check_circle_rounded,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      thought.isCompleted
                                          ? 'Mark as undone'
                                          : 'Mark as done',
                                    ),
                                  ],
                                ),
                              )
                            else
                              const PopupMenuItem(
                                value: 'open_todo',
                                child: Row(
                                  children: [
                                    Icon(Icons.open_in_new_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('View linked Todo'),
                                  ],
                                ),
                              ),
                            if (thought.mood == 'promise')
                              const PopupMenuItem(
                                value: 'track_challenge',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text('Track with Challenge'),
                                  ],
                                ),
                              ),
                            if (thought.mood != 'promise')
                              const PopupMenuItem(
                                value: 'convert_task',
                                child: Row(
                                  children: [
                                    Icon(Icons.add_task_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Convert to Today Task'),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(
                                    thought.isArchived
                                        ? Icons.unarchive_outlined
                                        : Icons.archive_outlined,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    thought.isArchived
                                        ? 'Unarchive'
                                        : 'Archive thought',
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text('Share (WhatsApp & apps)'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pin',
                              child: Text(
                                thought.isPinned ? 'Unpin' : 'Pin to top',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'copy',
                              child: Text('Copy text'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete thought',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Status badges row (if completed, pinned, or archived)
                    if (thought.isCompleted ||
                        thought.isPinned ||
                        thought.isArchived) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (thought.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.accentPrimary.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '✓ Done',
                                style: TextStyle(
                                  color: context.accentPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (thought.isPinned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.accentPrimary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.push_pin_rounded,
                                    size: 9,
                                    color: context.accentPrimary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'PINNED',
                                    style: AscentTextStyles.labelSmall.copyWith(
                                      color: context.accentPrimary,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (thought.isArchived)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.archive_outlined,
                                    size: 9,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'ARCHIVED',
                                    style: AscentTextStyles.labelSmall.copyWith(
                                      color: Colors.amber,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Optional prompt question banner
                    if (thought.promptQuestion != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: moodColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: moodColor.withValues(alpha: 0.5),
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              size: 13,
                              color: moodColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                thought.promptQuestion!,
                                style: AscentTextStyles.bodySmall.copyWith(
                                  color: context.textMuted,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Content
                    Text(
                      thought.content,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: thought.isCompleted
                            ? context.textMuted
                            : context.textPrimary,
                        decoration: thought.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        height: 1.45,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
