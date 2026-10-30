import 'package:flutter/cupertino.dart';
import '../../app/theme/shared_control_tokens.dart';

/// The app-wide switch. Use this directly, or AscentSwitchRow for settings.
/// Explicit colors keep the white thumb consistent on Android and iOS.
class AscentSwitch extends StatelessWidget {
  const AscentSwitch({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
    value: value,
    applyTheme: false,
    activeTrackColor: SharedControlColors.actionBlue,
    inactiveTrackColor: CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? SharedControlColors.switchTrackOffDark
        : SharedControlColors.switchTrackOffLight,
    thumbColor: SharedControlColors.switchThumb,
    onChanged: onChanged,
  );
}
