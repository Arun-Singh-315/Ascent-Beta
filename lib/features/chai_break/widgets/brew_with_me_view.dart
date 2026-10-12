import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
      _selectedRecipe = BuiltInBrewingRecipes.all.firstWhere((r) => r.category == cat);
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
    final filteredRecipes =
        BuiltInBrewingRecipes.all.where((r) => r.category == _selectedCategory).toList();

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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF26201A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE28B57).withValues(alpha: 0.25),
          width: 1.2,
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedRecipe.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE28B57).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selectedRecipe.totalDurationSeconds ~/ 60}m brew',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE28B57),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Row(
                children: [1, 2, 3, 4].map((cups) {
                  final isSelected = cups == _selectedCups;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: () => _onCupsChanged(cups),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE28B57)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFE28B57)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          '$cups',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.black : Colors.white,
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
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Ingredients list scaled
          Text(
            'PROPORTIONAL INGREDIENTS ($_selectedCups ${_selectedCups == 1 ? 'CUP' : 'CUPS'})',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: const Color(0xFFE28B57),
            ),
          ),
          const SizedBox(height: 10),

          ..._selectedRecipe.ingredients.map((ing) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE28B57),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ing.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    ing.scaledFormatted(_selectedCups),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE28B57),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1914),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE28B57).withValues(alpha: 0.4),
          width: 1.5,
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
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: const Color(0xFFE28B57),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                onPressed: _resetBrewing,
                tooltip: 'Exit guide',
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            currentStep.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            currentStep.instruction,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // Countdown display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              _formatSeconds(_stepSecondsRemaining),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: isCompleted ? const Color(0xFF10B981) : Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white60),
                onPressed: _currentStepIndex > 0 ? () => _goToStep(_currentStepIndex - 1) : null,
                tooltip: 'Previous step',
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _toggleStepTimer,
                icon: Icon(
                  _isStepTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(
                  _isStepTimerRunning ? 'Pause' : 'Resume',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE28B57),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white60),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF10B981),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE28B57).withValues(alpha: 0.22)
              : const Color(0xFF26201A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFE28B57) : Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFFE28B57) : Colors.white60,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE28B57).withValues(alpha: 0.18)
              : const Color(0xFF221D18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFE28B57) : Colors.white.withValues(alpha: 0.08),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFFE28B57) : Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${recipe.steps.length} steps • ${recipe.totalDurationSeconds ~/ 60}m',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
