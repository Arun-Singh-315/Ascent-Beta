import 'package:ascent/core/services/plan_generator.dart';
import 'package:ascent/features/plans/widgets/plan_generator_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("Riya's diet names map to meal goals", () {
    expect(mealGoalFrom('High-Protein Vitality'), MealGoal.protein);
    expect(mealGoalFrom('Strength & Muscle Building'), MealGoal.protein);
    expect(mealGoalFrom('Whole-Food Vegetarian'), MealGoal.veg);
    expect(mealGoalFrom('Clean Calorie-Conscious'), MealGoal.light);
    expect(mealGoalFrom('Balanced Nutrition'), MealGoal.balanced);
    expect(mealGoalFrom(null), MealGoal.balanced);
  });
}
