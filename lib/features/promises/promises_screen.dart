import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../shared/widgets/ascent_button.dart';
import 'models/promise_model.dart';
import 'providers/promise_providers.dart';
import 'widgets/promise_card.dart';
import 'widgets/promise_chat_composer.dart';

/// Full-featured Promise Overview screen in Ascent.
/// Allows viewing active, completed, and paused commitments,
/// launching the chat composer, and triggering direct actions.
class PromisesScreen extends ConsumerStatefulWidget {
  const PromisesScreen({super.key});

  @override
  ConsumerState<PromisesScreen> createState() => _PromisesScreenState();
}

class _PromisesScreenState extends ConsumerState<PromisesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  UnlockedPromiseIdsNotifier? _unlockedNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unlockedNotifier = ref.read(unlockedPromiseIdsProvider.notifier);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _unlockedNotifier?.lockAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlockedNotifier?.lockAll();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final unlockedIds = ref.watch(unlockedPromiseIdsProvider);
    final activeAsync = ref.watch(activePromisesStreamProvider);
    final completedAsync = ref.watch(completedPromisesStreamProvider);
    final pausedAsync = ref.watch(pausedPromisesStreamProvider);

    return Scaffold(
      backgroundColor: g.bg,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Navigation & Action header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: g.ink,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/');
                              }
                            },
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (unlockedIds.isNotEmpty) ...[
                                IconButton(
                                  key: const ValueKey('promises_lock_all_btn'),
                                  tooltip: 'Lock all commitments',
                                  icon: Icon(
                                    Icons.lock_rounded,
                                    color: g.clay,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    ref
                                        .read(
                                          unlockedPromiseIdsProvider.notifier,
                                        )
                                        .lockAll();
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                              AscentButton.outlined(
                                label: 'New Promise',
                                icon: Icons.auto_awesome_rounded,
                                compact: true,
                                expanded: false,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  PromiseChatComposer.show(context);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Promises',
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: g.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A personal commitment system built on self-trust, not guilt.',
                        style: TextStyle(color: g.inkMuted, fontSize: 13.5),
                      ),
                      activeAsync.when(
                        data: (activeList) => Container(
                          margin: const EdgeInsets.only(top: 14, bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: g.fill.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: g.line),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: g.inkSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  activeList.isEmpty
                                      ? 'Your sanctuary for personal pledges and sacred daily commitments.'
                                      : '${activeList.length} active commitment${activeList.length == 1 ? '' : 's'} building self-trust.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: g.inkSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 14),

                      // Filter tabs
                      Container(
                        height: MediaQuery.textScalerOf(context).scale(13) > 20
                            ? 64
                            : 40,
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable:
                              MediaQuery.textScalerOf(context).scale(13) > 20,
                          tabAlignment:
                              MediaQuery.textScalerOf(context).scale(13) > 20
                              ? TabAlignment.start
                              : TabAlignment.fill,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: g.ink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          labelColor: g.bg,
                          unselectedLabelColor: g.inkMuted,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(text: 'Active'),
                            Tab(text: 'Completed'),
                            Tab(text: 'Paused'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // 1. Active Tab
              _buildPromiseList(
                asyncValue: activeAsync,
                emptyTitle: 'No active commitments',
                emptySubtitle:
                    'Commitments you make to yourself will appear here.',
                showCreateAction: true,
                g: g,
              ),

              // 2. Completed Tab
              _buildPromiseList(
                asyncValue: completedAsync,
                emptyTitle: 'No completed promises yet',
                emptySubtitle:
                    'Every fulfilled commitment builds proof of your own reliability.',
                showCreateAction: false,
                g: g,
              ),

              // 3. Paused Tab
              _buildPromiseList(
                asyncValue: pausedAsync,
                emptyTitle: 'No paused promises',
                emptySubtitle:
                    'If a goal feels too demanding, you can pause it without guilt.',
                showCreateAction: false,
                g: g,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromiseList({
    required AsyncValue<List<PromiseModel>> asyncValue,
    required String emptyTitle,
    required String emptySubtitle,
    required bool showCreateAction,
    required AscentGlass g,
  }) {
    return asyncValue.when(
      data: (promises) {
        if (promises.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: g.ink.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.handshake_outlined,
                      size: 28,
                      color: g.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: g.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    emptySubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: g.inkMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (showCreateAction) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => PromiseChatComposer.show(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Make a promise'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: g.ink,
                        side: BorderSide(color: g.ink.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          itemCount: promises.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return PromiseCard(
              key: ValueKey('promise_card_${promises[index].id}'),
              promise: promises[index],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          'Unable to load promises.',
          style: TextStyle(color: g.inkMuted),
        ),
      ),
    );
  }
}
