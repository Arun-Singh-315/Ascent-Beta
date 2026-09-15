import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import '../core/providers/settings_provider.dart';

/// Root application widget. Reads theme preference from [settingsProvider]
/// and builds a [MaterialApp.router] powered by [ascentRouter].
class AscentApp extends ConsumerWidget {
  const AscentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Ascent',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AscentTheme.light(),
      darkTheme: AscentTheme.dark(),
      themeMode: themeMode,

      // Router
      routerConfig: ascentRouter,
    );
  }
}
