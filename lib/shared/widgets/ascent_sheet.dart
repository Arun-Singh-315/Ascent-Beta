import 'package:flutter/material.dart';
import '../../app/theme/glass_theme.dart';

Future<T?> showAscentSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool framed = true,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .4),
  constraints: BoxConstraints(
    maxWidth: 600,
    maxHeight: MediaQuery.sizeOf(context).height * .94,
  ),
  sheetAnimationStyle: AnimationStyle(
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 280,
    ),
    reverseDuration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
    ),
  ),
  builder: (ctx) => framed
      ? Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: AscentSheetSurface(
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AscentSheetHandle(),
                  Flexible(child: builder(ctx)),
                ],
              ),
            ),
          ),
        )
      : builder(ctx),
);

class AscentSheetSurface extends StatelessWidget {
  const AscentSheetSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: context.glass.elevated,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class AscentSheetHandle extends StatelessWidget {
  const AscentSheetHandle({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.glass.ink.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}
