import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Root locations of the five main tabs, in tab-bar order (CLAUDE.md §4).
class AscentTabs {
  AscentTabs._();

  static const home = '/home';
  static const things = '/things';
  static const assistant = '/ai-assistant';
  static const mind = '/thought-wall';
  static const you = '/you';

  static const roots = [home, things, assistant, mind, you];

  /// The tab index whose root matches [location]'s path, or null.
  static int? indexOf(String location) {
    final path = Uri.tryParse(location)?.path;
    final index = roots.indexOf(path ?? '');
    return index < 0 ? null : index;
  }
}

/// Opens any in-app location the right way.
///
/// A tab root must be opened with `go` so the shell switches tabs; pushing it
/// would stack the page inside the current tab and leave the wrong tab
/// selected. Everything else is pushed so back returns to where the user was.
extension AscentRouterNavigation on GoRouter {
  void open(String location, {Object? extra}) {
    if (AscentTabs.indexOf(location) != null) {
      go(location, extra: extra);
    } else {
      push(location, extra: extra);
    }
  }
}

extension AscentContextNavigation on BuildContext {
  void open(String location, {Object? extra}) =>
      GoRouter.of(this).open(location, extra: extra);
}
