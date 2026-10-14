enum BeverageCategory { chai, coffee }

class IngredientItem {
  final String name;
  final double baseAmountPerCup;
  final String unit;

  const IngredientItem({
    required this.name,
    required this.baseAmountPerCup,
    required this.unit,
  });

  String scaledFormatted(int cups) {
    final amount = baseAmountPerCup * cups;
    if (amount == amount.roundToDouble()) {
      return '${amount.toInt()} $unit';
    }
    return '${amount.toStringAsFixed(1)} $unit';
  }
}

class BrewingStep {
  final String title;
  final String instruction;
  final int durationSeconds;

  const BrewingStep({
    required this.title,
    required this.instruction,
    required this.durationSeconds,
  });
}

class BrewingRecipe {
  final String id;
  final String title;
  final String subtitle;
  final BeverageCategory category;
  final String iconName;
  final List<IngredientItem> ingredients;
  final List<BrewingStep> steps;

  const BrewingRecipe({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.iconName,
    required this.ingredients,
    required this.steps,
  });

  int get totalDurationSeconds =>
      steps.fold(0, (sum, step) => sum + step.durationSeconds);
}

class BuiltInBrewingRecipes {
  static const List<BrewingRecipe> all = [
    // ── CHAI RECIPES ─────────────────────────────────────────────────────────
    BrewingRecipe(
      id: 'kadak_masala_chai',
      title: 'Kadak Masala Chai',
      subtitle: 'Ginger, clove, crushed cardamom & black pepper',
      category: BeverageCategory.chai,
      iconName: 'masala_chai',
      ingredients: [
        IngredientItem(name: 'Water', baseAmountPerCup: 100, unit: 'ml'),
        IngredientItem(name: 'Whole Milk', baseAmountPerCup: 100, unit: 'ml'),
        IngredientItem(
          name: 'CTC Black Tea',
          baseAmountPerCup: 1.5,
          unit: 'tsp',
        ),
        IngredientItem(
          name: 'Fresh Ginger (crushed)',
          baseAmountPerCup: 5,
          unit: 'g',
        ),
        IngredientItem(
          name: 'Green Cardamom (crushed)',
          baseAmountPerCup: 1,
          unit: 'pod',
        ),
        IngredientItem(name: 'Cloves', baseAmountPerCup: 1, unit: 'piece'),
        IngredientItem(name: 'Sugar', baseAmountPerCup: 1.5, unit: 'tsp'),
      ],
      steps: [
        BrewingStep(
          title: 'Spice Infusion',
          instruction:
              'Add water, crushed ginger, cardamom, and clove to saucepan. Bring to a rolling boil.',
          durationSeconds: 120,
        ),
        BrewingStep(
          title: 'Tea Leaves Brew',
          instruction:
              'Add black tea leaves. Boil on medium flame until rich dark caramel color emerges.',
          durationSeconds: 90,
        ),
        BrewingStep(
          title: 'Milk & Sugar Simmer',
          instruction:
              'Pour in milk and sugar. Bring to a boil, then simmer on low for two rises to develop body.',
          durationSeconds: 120,
        ),
        BrewingStep(
          title: 'Strain & Serve',
          instruction:
              'Strain through a fine sieve into your cup. Inhale the warm comforting aroma.',
          durationSeconds: 30,
        ),
      ],
    ),
    BrewingRecipe(
      id: 'adrak_tulsi_chai',
      title: 'Adrak Tulsi Chai',
      subtitle: 'Crushed ginger root & fresh holy basil soothe',
      category: BeverageCategory.chai,
      iconName: 'adrak_chai',
      ingredients: [
        IngredientItem(name: 'Water', baseAmountPerCup: 120, unit: 'ml'),
        IngredientItem(name: 'Milk', baseAmountPerCup: 80, unit: 'ml'),
        IngredientItem(name: 'Black Tea', baseAmountPerCup: 1.5, unit: 'tsp'),
        IngredientItem(
          name: 'Fresh Ginger (crushed)',
          baseAmountPerCup: 8,
          unit: 'g',
        ),
        IngredientItem(
          name: 'Tulsi Leaves',
          baseAmountPerCup: 4,
          unit: 'leaves',
        ),
        IngredientItem(
          name: 'Jaggery or Sugar',
          baseAmountPerCup: 1.5,
          unit: 'tsp',
        ),
      ],
      steps: [
        BrewingStep(
          title: 'Ginger & Tulsi Boil',
          instruction:
              'Boil water with crushed ginger root and hand-torn holy basil leaves.',
          durationSeconds: 120,
        ),
        BrewingStep(
          title: 'Tea Extraction',
          instruction:
              'Add tea leaves and simmer to extract invigorating ginger warmth.',
          durationSeconds: 60,
        ),
        BrewingStep(
          title: 'Milk Blend',
          instruction:
              'Add milk and sweetener. Bring to a rolling boil and simmer for 1 minute.',
          durationSeconds: 90,
        ),
        BrewingStep(
          title: 'Strain & Savor',
          instruction:
              'Filter hot chai into your cup. Feel the instant comfort.',
          durationSeconds: 30,
        ),
      ],
    ),
    BrewingRecipe(
      id: 'elaichi_chai',
      title: 'Elaichi (Cardamom) Chai',
      subtitle: 'Fragrant green cardamom pods in creamy milk',
      category: BeverageCategory.chai,
      iconName: 'elaichi_chai',
      ingredients: [
        IngredientItem(name: 'Water', baseAmountPerCup: 100, unit: 'ml'),
        IngredientItem(name: 'Milk', baseAmountPerCup: 100, unit: 'ml'),
        IngredientItem(name: 'Black Tea', baseAmountPerCup: 1.5, unit: 'tsp'),
        IngredientItem(
          name: 'Green Cardamom (crushed)',
          baseAmountPerCup: 2,
          unit: 'pods',
        ),
        IngredientItem(name: 'Sugar', baseAmountPerCup: 1, unit: 'tsp'),
      ],
      steps: [
        BrewingStep(
          title: 'Cardamom Bloom',
          instruction:
              'Crush cardamom pods with skins and boil in water to release fragrant oils.',
          durationSeconds: 90,
        ),
        BrewingStep(
          title: 'Tea Steep',
          instruction: 'Add black tea leaves and simmer gently on low heat.',
          durationSeconds: 60,
        ),
        BrewingStep(
          title: 'Creamy Simmer',
          instruction:
              'Add milk and sugar. Allow cardamom fragrance to permeate the milk.',
          durationSeconds: 120,
        ),
        BrewingStep(
          title: 'Strain & Pour',
          instruction:
              'Pour into your favorite cup and take a calm, deep breath.',
          durationSeconds: 30,
        ),
      ],
    ),
    BrewingRecipe(
      id: 'kashmiri_kahwa',
      title: 'Kashmiri Kahwa',
      subtitle: 'Saffron strands, cinnamon & slivered almonds',
      category: BeverageCategory.chai,
      iconName: 'kahwa',
      ingredients: [
        IngredientItem(name: 'Water', baseAmountPerCup: 200, unit: 'ml'),
        IngredientItem(
          name: 'Kashmiri Green Tea',
          baseAmountPerCup: 1,
          unit: 'tsp',
        ),
        IngredientItem(
          name: 'Saffron Strands',
          baseAmountPerCup: 4,
          unit: 'strands',
        ),
        IngredientItem(
          name: 'Cinnamon Stick',
          baseAmountPerCup: 0.5,
          unit: 'piece',
        ),
        IngredientItem(
          name: 'Almonds (slivered)',
          baseAmountPerCup: 1,
          unit: 'tbsp',
        ),
        IngredientItem(name: 'Honey', baseAmountPerCup: 1, unit: 'tsp'),
      ],
      steps: [
        BrewingStep(
          title: 'Saffron & Spice Brew',
          instruction:
              'Boil water with cinnamon stick and saffron strands until water turns golden.',
          durationSeconds: 150,
        ),
        BrewingStep(
          title: 'Green Tea Steep',
          instruction:
              'Turn off heat. Add green tea leaves, cover with lid to gently steep.',
          durationSeconds: 120,
        ),
        BrewingStep(
          title: 'Garnish & Sweeten',
          instruction:
              'Place slivered almonds in cup, add honey, and pour strained golden kahwa.',
          durationSeconds: 30,
        ),
      ],
    ),

    // ── COFFEE RECIPES ───────────────────────────────────────────────────────
    BrewingRecipe(
      id: 'filter_coffee',
      title: 'South Indian Filter Coffee',
      subtitle: 'Traditional chicory blend, thick decoction & foam',
      category: BeverageCategory.coffee,
      iconName: 'filter_coffee',
      ingredients: [
        IngredientItem(name: 'Water', baseAmountPerCup: 80, unit: 'ml'),
        IngredientItem(
          name: 'Chicory Coffee Blend',
          baseAmountPerCup: 2,
          unit: 'tbsp',
        ),
        IngredientItem(name: 'Whole Milk', baseAmountPerCup: 120, unit: 'ml'),
        IngredientItem(name: 'Sugar', baseAmountPerCup: 1.5, unit: 'tsp'),
      ],
      steps: [
        BrewingStep(
          title: 'Decoction Extraction',
          instruction:
              'Place coffee powder into filter, press lightly with disc, pour boiling water, and close.',
          durationSeconds: 180,
        ),
        BrewingStep(
          title: 'Milk Scald',
          instruction: 'Boil full-cream milk until frothy and piping hot.',
          durationSeconds: 90,
        ),
        BrewingStep(
          title: 'The Dabarah Metre Froth',
          instruction:
              'Pour thick decoction, hot milk, and sugar into dabarah tumbler. Pour back and forth at height to froth.',
          durationSeconds: 45,
        ),
      ],
    ),
    BrewingRecipe(
      id: 'classic_espresso',
      title: 'Classic Espresso / Americano',
      subtitle: 'Bold dark roast with rich velvety crema',
      category: BeverageCategory.coffee,
      iconName: 'espresso',
      ingredients: [
        IngredientItem(name: 'Hot Water', baseAmountPerCup: 150, unit: 'ml'),
        IngredientItem(
          name: 'Fine Ground Espresso',
          baseAmountPerCup: 1.5,
          unit: 'tbsp',
        ),
      ],
      steps: [
        BrewingStep(
          title: 'Preheat & Warm',
          instruction:
              'Rinse your cup with hot water to maintain optimal brewing temperature.',
          durationSeconds: 45,
        ),
        BrewingStep(
          title: 'Extract Espresso',
          instruction:
              'Extract concentrated espresso shot with thick golden crema.',
          durationSeconds: 45,
        ),
        BrewingStep(
          title: 'Water Top-Up',
          instruction:
              'Top with hot water for smooth Americano or enjoy straight as bold espresso.',
          durationSeconds: 30,
        ),
      ],
    ),
    BrewingRecipe(
      id: 'dalgona_coffee',
      title: 'Whipped Velvet Dalgona',
      subtitle: 'Whipped golden coffee cream over chilled or warm milk',
      category: BeverageCategory.coffee,
      iconName: 'dalgona',
      ingredients: [
        IngredientItem(
          name: 'Instant Coffee',
          baseAmountPerCup: 1,
          unit: 'tbsp',
        ),
        IngredientItem(name: 'Sugar', baseAmountPerCup: 1, unit: 'tbsp'),
        IngredientItem(name: 'Hot Water', baseAmountPerCup: 1, unit: 'tbsp'),
        IngredientItem(
          name: 'Milk (chilled or warm)',
          baseAmountPerCup: 180,
          unit: 'ml',
        ),
        IngredientItem(
          name: 'Ice Cubes (optional)',
          baseAmountPerCup: 3,
          unit: 'cubes',
        ),
      ],
      steps: [
        BrewingStep(
          title: 'Whip Velvet Cloud',
          instruction:
              'Whisk instant coffee, sugar, and hot water vigorously until thick, glossy foam peaks form.',
          durationSeconds: 180,
        ),
        BrewingStep(
          title: 'Glass Base',
          instruction: 'Fill glass with ice and pour milk 3/4 full.',
          durationSeconds: 30,
        ),
        BrewingStep(
          title: 'Crown & Stir',
          instruction:
              'Dollop the whipped golden foam over the milk. Stir gently to drink.',
          durationSeconds: 30,
        ),
      ],
    ),
    BrewingRecipe(
      id: 'cold_brew',
      title: 'Overnight Cold Brew',
      subtitle: 'Slow cold-steeped concentrate, zero acidity',
      category: BeverageCategory.coffee,
      iconName: 'cold_brew',
      ingredients: [
        IngredientItem(
          name: 'Coarse Coffee Grounds',
          baseAmountPerCup: 2,
          unit: 'tbsp',
        ),
        IngredientItem(
          name: 'Cold Filtered Water',
          baseAmountPerCup: 200,
          unit: 'ml',
        ),
        IngredientItem(name: 'Ice Cubes', baseAmountPerCup: 4, unit: 'cubes'),
        IngredientItem(
          name: 'Milk Splash (optional)',
          baseAmountPerCup: 30,
          unit: 'ml',
        ),
      ],
      steps: [
        BrewingStep(
          title: 'Filter Cold Brew',
          instruction:
              'Filter cold-steeped concentrate through fine strainer or french press.',
          durationSeconds: 60,
        ),
        BrewingStep(
          title: 'Pour Over Ice',
          instruction:
              'Fill glass with clear ice and pour filtered concentrate over ice.',
          durationSeconds: 30,
        ),
        BrewingStep(
          title: 'Milk Crown',
          instruction:
              'Add a splash of cold whole milk or oat milk if desired. Enjoy the crisp refreshment.',
          durationSeconds: 30,
        ),
      ],
    ),
  ];
}
