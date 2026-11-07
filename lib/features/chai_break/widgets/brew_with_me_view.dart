import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_card.dart';
import '../models/brewing_recipe.dart';

class BrewWithMeView extends StatefulWidget {
  const BrewWithMeView({super.key});

  @override
  State<BrewWithMeView> createState() => _BrewWithMeViewState();
}

class _BrewWithMeViewState extends State<BrewWithMeView> {
  BeverageCategory _selectedCategory = BeverageCategory.chai;
  late BrewingRecipe _selectedRecipe;
  int _selectedCups = 1;

  // Active brewing state
  bool _isBrewingActive = false;
  int _currentStepIndex = 0;
  int _stepSecondsRemaining = 0;
  bool _isStepTimerRunning = false;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _selectedRecipe = BuiltInBrewingRecipes.all.firstWhere(
      (r) => r.category == _selectedCategory,
    );
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  void _onCategoryChanged(BeverageCategory cat) {
    if (_selectedCategory == cat) return;
    HapticFeedback.selectionClick();
    _stepTimer?.cancel();
    setState(() {
      _selectedCategory = cat;
      _selectedRecipe = BuiltInBrewingRecipes.all.firstWhere(
        (r) => r.category == cat,
      );
      _isBrewingActive = false;
      _currentStepIndex = 0;
      _isStepTimerRunning = false;
    });
  }

  void _onRecipeSelected(BrewingRecipe recipe) {
    HapticFeedback.selectionClick();
    _stepTimer?.cancel();
    setState(() {
      _selectedRecipe = recipe;
      _isBrewingActive = false;
      _currentStepIndex = 0;
      _isStepTimerRunning = false;
    });
  }

  void _onCupsChanged(int cups) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCups = cups;
    });
  }

  void _startBrewing() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBrewingActive = true;
      _currentStepIndex = 0;
      _stepSecondsRemaining = _selectedRecipe.steps[0].durationSeconds;
      _isStepTimerRunning = true;
    });
    _runStepTimer();
  }

  void _runStepTimer() {
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isStepTimerRunning) return;

      if (_stepSecondsRemaining > 0) {
        setState(() {
          _stepSecondsRemaining--;
        });
      } else {
        HapticFeedback.heavyImpact();
        if (_currentStepIndex < _selectedRecipe.steps.length - 1) {
          // Advance to next step
          _goToStep(_currentStepIndex + 1);
        } else {
          // Finished
          timer.cancel();
          setState(() {
            _isStepTimerRunning = false;
          });
        }
      }
    });
  }

  void _toggleStepTimer() {
    HapticFeedback.lightImpact();
    setState(() {
      _isStepTimerRunning = !_isStepTimerRunning;
    });
  }

  void _goToStep(int newIndex) {
    if (newIndex < 0 || newIndex >= _selectedRecipe.steps.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentStepIndex = newIndex;
      _stepSecondsRemaining = _selectedRecipe.steps[newIndex].durationSeconds;
    });
  }

  void _resetBrewing() {
    _stepTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() {
      _isBrewingActive = false;
      _currentStepIndex = 0;
      _isStepTimerRunning = false;
    });
  }

  String _formatSeconds(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = BuiltInBrewingRecipes.all
        .where((r) => r.category == _selectedCategory)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Selector (Chai vs Coffee)
        Row(
          children: [
            Expanded(
              child: _CategoryButton(
                label: 'Artisanal Chai',
                icon: Icons.emoji_food_beverage_rounded,
                isSelected: _selectedCategory == BeverageCategory.chai,
                onTap: () => _onCategoryChanged(BeverageCategory.chai),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CategoryButton(
                label: 'Signature Coffee',
                icon: Icons.coffee_rounded,
                isSelected: _selectedCategory == BeverageCategory.coffee,
                onTap: () => _onCategoryChanged(BeverageCategory.coffee),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Horizontal recipe selector cards (spacious to prevent text clipping)
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: filteredRecipes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final recipe = filteredRecipes[index];
              final isSelected = recipe.id == _selectedRecipe.id;
              return _RecipeCard(
                recipe: recipe,
                isSelected: isSelected,
                onTap: () => _onRecipeSelected(recipe),
              );
            },
          ),
        ),

        const SizedBox(height: 18),

        // Active Guided Step Mode vs. Recipe Overview
        if (_isBrewingActive) ...[
          _buildActiveStepCard(),
        ] else ...[
          _buildRecipeOverviewCard(),
        ],
      ],
    );
  }

  Widget _buildRecipeOverviewCard() {
    final g = context.glass;
    final dark = g.isDark;

    return AscentCard(
      padding: const EdgeInsets.all(AppSpace.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedRecipe.title,
                      style: AscentTextStyles.cardTitle.copyWith(
                        color: g.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedRecipe.subtitle,
                      style: AscentTextStyles.captionMedium.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s10,
                  vertical: AppSpace.s6,
                ),
                decoration: BoxDecoration(
                  color: g.claySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: g.clay.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${_selectedRecipe.totalDurationSeconds ~/ 60}m brew',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.clay,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Cup selector
          Row(
            children: [
              Text(
                'How many cups?',
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: g.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [1, 2, 3, 4].map((cups) {
                  final isSelected = cups == _selectedCups;
                  return Padding(
                    padding: const EdgeInsets.only(left: AppSpace.s6),
                    child: GestureDetector(
                      onTap: () => _onCupsChanged(cups),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? g.clay
                              : (dark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? g.clay
                                : g.line.withValues(alpha: dark ? 0.35 : 0.2),
                            width: isSelected ? 1.4 : 0.8,
                          ),
                        ),
                        child: Text(
                          '$cups',
                          style: TextStyle(
                            color: isSelected ? Colors.white : g.ink,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(
            color: g.line.withValues(alpha: dark ? 0.35 : 0.2),
            height: 1,
          ),
          const SizedBox(height: 16),

          // Ingredients list scaled
          Text(
            'PROPORTIONAL INGREDIENTS ($_selectedCups ${_selectedCups == 1 ? 'CUP' : 'CUPS'})',
            style: AscentTextStyles.labelSmall.copyWith(
              color: g.clay,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          ..._selectedRecipe.ingredients.map((ing) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: g.clay,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ing.name,
                        style: AscentTextStyles.bodyMedium.copyWith(
                          color: g.ink,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    ing.scaledFormatted(_selectedCups),
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: g.inkSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Start Button
          SizedBox(
            width: double.infinity,
            child: AscentButton.primary(
              label: 'Start Guided Brew (${_selectedRecipe.steps.length} Steps)',
              icon: Icons.soup_kitchen_rounded,
              onPressed: _startBrewing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStepCard() {
    final g = context.glass;
    final dark = g.isDark;
    final currentStep = _selectedRecipe.steps[_currentStepIndex];
    final totalSteps = _selectedRecipe.steps.length;
    final isLastStep = _currentStepIndex == totalSteps - 1;
    final isCompleted = isLastStep && _stepSecondsRemaining == 0;

    return AscentCard(
      padding: const EdgeInsets.all(AppSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP ${_currentStepIndex + 1} OF $totalSteps',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: g.clay,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: g.inkMuted,
                  size: 20,
                ),
                onPressed: _resetBrewing,
                tooltip: 'Exit guide',
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            currentStep.title,
            textAlign: TextAlign.center,
            style: AscentTextStyles.cardTitle.copyWith(
              color: g.ink,
              fontWeight: FontWeight.w700,
              fontSize: 19,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            currentStep.instruction,
            textAlign: TextAlign.center,
            style: AscentTextStyles.bodyMedium.copyWith(
              color: g.inkSecondary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // Countdown display
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s24,
              vertical: AppSpace.s12,
            ),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: g.line.withValues(alpha: dark ? 0.35 : 0.2),
                width: 1,
              ),
            ),
            child: Text(
              _formatSeconds(_stepSecondsRemaining),
              style: TextStyle(
                color: isCompleted ? SharedControlColors.actionBlue : g.ink,
                fontSize: 38,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.skip_previous_rounded,
                  color: _currentStepIndex > 0 ? g.ink : g.inkMuted,
                ),
                onPressed: _currentStepIndex > 0
                    ? () => _goToStep(_currentStepIndex - 1)
                    : null,
                tooltip: 'Previous step',
              ),
              const SizedBox(width: 12),
              AscentButton.primary(
                label: _isStepTimerRunning ? 'Pause' : 'Resume',
                icon: _isStepTimerRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                expanded: false,
                onPressed: _toggleStepTimer,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: _currentStepIndex < totalSteps - 1 ? g.ink : g.inkMuted,
                ),
                onPressed: _currentStepIndex < totalSteps - 1
                    ? () => _goToStep(_currentStepIndex + 1)
                    : null,
                tooltip: 'Next step',
              ),
            ],
          ),

          if (isCompleted) ...[
            const SizedBox(height: 14),
            Text(
              '🎉 Brewing finished! Take a mindful sip and relax.',
              style: AscentTextStyles.bodyMedium.copyWith(
                color: g.clay,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = g.isDark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpace.s12,
          horizontal: AppSpace.s14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? g.claySoft
              : (dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? g.clay
                : g.line.withValues(alpha: dark ? 0.35 : 0.2),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? g.clay : g.inkMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AscentTextStyles.bodyMedium.copyWith(
                color: isSelected ? g.clay : g.ink,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final BrewingRecipe recipe;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = g.isDark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 160,
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(
          color: isSelected
              ? g.claySoft
              : (dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? g.clay
                : g.line.withValues(alpha: dark ? 0.35 : 0.2),
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              recipe.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AscentTextStyles.bodyMedium.copyWith(
                color: isSelected ? g.clay : g.ink,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${recipe.steps.length} steps · ${recipe.totalDurationSeconds ~/ 60}m',
              style: AscentTextStyles.captionMedium.copyWith(
                color: g.inkMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
