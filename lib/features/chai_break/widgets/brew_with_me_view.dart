import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

        // Horizontal recipe selector cards
        SizedBox(
          height: 94,
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s18),
      nightDecoration: BoxDecoration(
        color: AppPalette.colorFF26201A,
        borderRadius: AppGeometry.roundedr20,
        border: Border.all(
          color: AppPalette.colorFFE28B57.withValues(alpha: 0.25),
          width: AppBorderScale.w1point2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedRecipe.title,
                      style: AppTypography.plusJakartaSans18W70045(
                        color: AppPalette.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedRecipe.subtitle,
                      style: AppTypography.plusJakartaSans12Regular57(
                        color: AppPalette.white60,
                      ),
                    ),
                  ],
                ),
              ),
              AppTag(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s10,
                  vertical: AppSpace.s6,
                ),
                nightDecoration: BoxDecoration(
                  color: AppPalette.colorFFE28B57.withValues(alpha: 0.15),
                  borderRadius: AppGeometry.roundedr10,
                ),
                child: Text(
                  '${_selectedRecipe.totalDurationSeconds ~/ 60}m brew',
                  style: AppTypography.jetBrainsMono12W70063(
                    color: AppPalette.colorFFE28B57,
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
                style: AppTypography.plusJakartaSans13W60083(
                  color: AppPalette.white70,
                ),
              ),
              const Spacer(),
              Row(
                children: [1, 2, 3, 4].map((cups) {
                  final isSelected = cups == _selectedCups;
                  return Padding(
                    padding: const EdgeInsets.only(left: AppSpace.s6),
                    child: AppTapArea(
                      onTap: () => _onCupsChanged(cups),
                      borderRadius: AppGeometry.roundedr8,
                      child: AppPill(
                        selected: isSelected,
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        nightDecoration: BoxDecoration(
                          color: isSelected
                              ? AppPalette.colorFFE28B57
                              : AppPalette.white.withValues(alpha: 0.06),
                          borderRadius: AppGeometry.roundedr8,
                          border: Border.all(
                            color: isSelected
                                ? AppPalette.colorFFE28B57
                                : AppPalette.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          '$cups',
                          style: AppTypography.jetBrainsMono13W70084(
                            color: context.surfaces.contentForeground(isSelected, isSelected
                                ? AppPalette.black
                                : AppPalette.white),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const AppDivider(color: AppPalette.white12, height: 1),
          const SizedBox(height: 16),

          // Ingredients list scaled
          Text(
            'PROPORTIONAL INGREDIENTS ($_selectedCups ${_selectedCups == 1 ? 'CUP' : 'CUPS'})',
            style: AppTypography.jetBrainsMono11W70085(
              color: AppPalette.colorFFE28B57,
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
                        decoration: const BoxDecoration(
                          color: AppPalette.colorFFE28B57,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ing.name,
                        style: AppTypography.plusJakartaSans13Regular18(
                          color: AppPalette.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    ing.scaledFormatted(_selectedCups),
                    style: AppTypography.jetBrainsMono13W60026(
                      color: AppPalette.white70,
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
            child: ElevatedButton.icon(
              onPressed: _startBrewing,
              icon: const Icon(Icons.soup_kitchen_rounded, size: 20),
              label: Text(
                'Start Guided Brew (${_selectedRecipe.steps.length} Steps)',
                style: AppTypography.plusJakartaSans14W70086(),
              ),
              style: context.surfaces.buttonStyle(
                ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.colorFFE28B57,
                  foregroundColor: AppPalette.black,
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppGeometry.roundedr14,
                  ),
                  elevation: 0,
                ),
                filled: true,
                icon: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStepCard() {
    final currentStep = _selectedRecipe.steps[_currentStepIndex];
    final totalSteps = _selectedRecipe.steps.length;
    final isLastStep = _currentStepIndex == totalSteps - 1;
    final isCompleted = isLastStep && _stepSecondsRemaining == 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s20),
      nightDecoration: BoxDecoration(
        color: AppPalette.colorFF1E1914,
        borderRadius: AppGeometry.roundedr22,
        border: Border.all(
          color: AppPalette.colorFFE28B57.withValues(alpha: 0.4),
          width: AppBorderScale.w1point5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP ${_currentStepIndex + 1} OF $totalSteps',
                style: AppTypography.jetBrainsMono11W70087(
                  color: AppPalette.colorFFE28B57,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppPalette.white54,
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
            style: AppTypography.plusJakartaSans20W70088(
              color: AppPalette.white,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            currentStep.instruction,
            textAlign: TextAlign.center,
            style: AppTypography.plusJakartaSans14Regular89(
              color: AppPalette.white70,
            ),
          ),

          const SizedBox(height: 20),

          // Countdown display
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s24,
              vertical: AppSpace.s12,
            ),
            nightDecoration: BoxDecoration(
              color: AppPalette.black.withValues(alpha: 0.3),
              borderRadius: AppGeometry.roundedr16,
              border: Border.all(color: AppPalette.white10),
            ),
            child: Text(
              _formatSeconds(_stepSecondsRemaining),
              style: AppTypography.jetBrainsMono42W70090(
                color: isCompleted
                    ? AppPalette.colorFF10B981
                    : AppPalette.white,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  color: AppPalette.white60,
                ),
                onPressed: _currentStepIndex > 0
                    ? () => _goToStep(_currentStepIndex - 1)
                    : null,
                tooltip: 'Previous step',
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _toggleStepTimer,
                icon: Icon(
                  _isStepTimerRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(
                  _isStepTimerRunning ? 'Pause' : 'Resume',
                  style: AppTypography.plusJakartaSansInheritedW70091(),
                ),
                style: context.surfaces.buttonStyle(
                  ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.colorFFE28B57,
                    foregroundColor: AppPalette.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppGeometry.roundedr20,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s20,
                      vertical: AppSpace.s10,
                    ),
                  ),
                  filled: true,
                  icon: false,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: AppPalette.white60,
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
              style: AppTypography.plusJakartaSans13W60083(
                color: AppPalette.colorFF10B981,
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
    return AppTapArea(
      onTap: onTap,
      borderRadius: AppGeometry.roundedr14,
      child: AppCard(
        selected: isSelected,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpace.s12,
          horizontal: AppSpace.s14,
        ),
        nightDecoration: BoxDecoration(
          color: isSelected
              ? AppPalette.colorFFE28B57.withValues(alpha: 0.22)
              : AppPalette.colorFF26201A,
          borderRadius: AppGeometry.roundedr14,
          border: Border.all(
            color: isSelected
                ? AppPalette.colorFFE28B57
                : AppPalette.white.withValues(alpha: 0.08),
            width: AppBorderScale.w1point2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppPalette.colorFFE28B57 : AppPalette.white60,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppStateTypography.stateType24(
                state0: isSelected,
                color: context.surfaces.contentForeground(isSelected, isSelected ? AppPalette.white : AppPalette.white70),
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
    return AppTapArea(
      onTap: onTap,
      borderRadius: AppGeometry.roundedr14,
      child: AppCard(
        selected: isSelected,
        width: 140,
        padding: const EdgeInsets.all(AppSpace.s12),
        nightDecoration: BoxDecoration(
          color: isSelected
              ? AppPalette.colorFFE28B57.withValues(alpha: 0.18)
              : AppPalette.colorFF221D18,
          borderRadius: AppGeometry.roundedr14,
          border: Border.all(
            color: isSelected
                ? AppPalette.colorFFE28B57
                : AppPalette.white.withValues(alpha: 0.08),
            width: isSelected ? 1.4 : 1,
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
              style: AppTypography.plusJakartaSans125W70093(
                color: context.surfaces.contentForeground(isSelected, isSelected ? AppPalette.colorFFE28B57 : AppPalette.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${recipe.steps.length} steps • ${recipe.totalDurationSeconds ~/ 60}m',
              style: AppTypography.jetBrainsMono10Regular8(
                color: context.surfaces.contentForeground(isSelected, AppPalette.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
