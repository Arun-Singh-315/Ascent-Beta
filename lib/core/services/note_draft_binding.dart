import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serializes draft writes so slower older writes cannot overwrite newer text.
class NoteDraftBinding with WidgetsBindingObserver {
  NoteDraftBinding(this.controller, this.preferences, String surface)
    : key = 'ascent_note_draft_$surface' {
    controller.text = preferences.getString(key) ?? '';
    controller.addListener(_save);
    WidgetsBinding.instance.addObserver(this);
  }
  final TextEditingController controller;
  final SharedPreferences preferences;
  final String key;
  Future<void> _pending = Future.value();
  String? _lastText;
  void _save() {
    final text = controller.text;
    if (text == _lastText) return;
    _lastText = text;
    _pending = _pending.catchError((_) {}).then((_) async {
      if (!await preferences.setString(key, text)) {
        throw StateError('Draft could not be saved');
      }
    });
    // The text remains in the field on failure; avoid an unhandled async error.
    unawaited(
      _pending.catchError((_) {
        if (_lastText == text) _lastText = null;
      }),
    );
  }

  Future<void> flush() => _pending;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _save();
  }

  void dispose() {
    controller.removeListener(_save);
    WidgetsBinding.instance.removeObserver(this);
  }
}
