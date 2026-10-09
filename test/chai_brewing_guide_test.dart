import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/features/chai_break/models/brewing_recipe.dart';

void main() {
  group('Chai & Coffee Brewing Recipe Logic Tests', () {
    test('Built-in recipes contain both Chai and Coffee selections', () {
      final chaiList = BuiltInBrewingRecipes.all
          .where((r) => r.category == BeverageCategory.chai)
          .toList();
      final coffeeList = BuiltInBrewingRecipes.all
          .where((r) => r.category == BeverageCategory.coffee)
          .toList();

      expect(chaiList.length, 4);
      expect(coffeeList.length, 4);

      expect(chaiList.any((r) => r.title.contains('Masala Chai')), isTrue);
      expect(chaiList.any((r) => r.title.contains('Adrak')), isTrue);
      expect(coffeeList.any((r) => r.title.contains('Filter Coffee')), isTrue);
      expect(coffeeList.any((r) => r.title.contains('Cold Brew')), isTrue);
    });

    test('Ingredient scaling multiplies correctly for 1, 2, 3, and 4 cups', () {
      final masalaChai = BuiltInBrewingRecipes.all
          .firstWhere((r) => r.id == 'kadak_masala_chai');
      final waterIngredient =
          masalaChai.ingredients.firstWhere((i) => i.name == 'Water');
      final teaIngredient =
          masalaChai.ingredients.firstWhere((i) => i.name == 'CTC Black Tea');

      // 1 cup
      expect(waterIngredient.scaledFormatted(1), '100 ml');
      expect(teaIngredient.scaledFormatted(1), '1.5 tsp');

      // 2 cups
      expect(waterIngredient.scaledFormatted(2), '200 ml');
      expect(teaIngredient.scaledFormatted(2), '3 tsp');

      // 3 cups
      expect(waterIngredient.scaledFormatted(3), '300 ml');
      expect(teaIngredient.scaledFormatted(3), '4.5 tsp');

      // 4 cups
      expect(waterIngredient.scaledFormatted(4), '400 ml');
      expect(teaIngredient.scaledFormatted(4), '6 tsp');
    });

    test('Recipe steps have positive durations and valid instructions', () {
      for (final recipe in BuiltInBrewingRecipes.all) {
        expect(recipe.steps.isNotEmpty, isTrue);
        expect(recipe.totalDurationSeconds, greaterThan(60));
        for (final step in recipe.steps) {
          expect(step.durationSeconds, greaterThan(0));
          expect(step.title.isNotEmpty, isTrue);
          expect(step.instruction.isNotEmpty, isTrue);
        }
      }
    });
  });
}
