import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../home/widgets/home_schedule_sheet.dart';
import 'thought_action_ui.dart';

/// A temporary invitation; the same actions always remain in the note menu.
class ThoughtQuickActions extends StatefulWidget {
  const ThoughtQuickActions({
    super.key,
    required this.thought,
    required this.db,
  });
  final Thought thought;
  final AppDatabase db;
  @override
  State<ThoughtQuickActions> createState() => _ThoughtQuickActionsState();
}

class _ThoughtQuickActionsState extends State<ThoughtQuickActions> {
  Timer? _timer;
  bool _visible = true;
  bool _interacting = false;
  bool? _accessible;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accessible = MediaQuery.of(context).accessibleNavigation;
    if (_accessible != accessible) {
      _accessible = accessible;
      _arm();
    }
  }

  void _arm() {
    _timer?.cancel();
    if (_accessible != true && !_interacting) {
      _timer = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  Future<void> _plan() async {
    if (_interacting) return;
    _interacting = true;
    _timer?.cancel();
    await showHomeSchedule(context, widget.thought);
    if (mounted) {
      _interacting = false;
      _arm();
    }
  }

  Future<void> _act(String action) async {
    if (_interacting) return;
    _interacting = true;
    _timer?.cancel();
    await applyThoughtAction(context, widget.db, [widget.thought], action);
    if (mounted) {
      _interacting = false;
      _arm();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_visible
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: AppSpace.s8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              AppPill.action(
                avatar: const Icon(Icons.edit_calendar_outlined, size: 14),
                label: const Text('Plan'),
                onPressed: _plan,
              ),
              AppPill.action(
                avatar: const Icon(Icons.checklist_rounded, size: 14),
                label: const Text('Todo'),
                onPressed: () => _act('todo'),
              ),
              AppPill.action(
                avatar: const Icon(Icons.notifications_none_rounded, size: 14),
                label: const Text('Reminder'),
                onPressed: () => _act('reminder'),
              ),
              AppPill.action(
                avatar: const Icon(Icons.add_task_rounded, size: 14),
                label: const Text('Both'),
                onPressed: () => _act('both'),
              ),
            ],
          ),
        );
}

