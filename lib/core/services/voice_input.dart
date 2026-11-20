import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictation. The microphone permission is asked the first time the user taps
/// the mic, never before (CLAUDE.md §1.3). When speech isn't available (no
/// permission, no recogniser, offline without an on-device model) [start]
/// returns false and typing keeps working.
abstract class VoiceInput {
  /// Starts listening. [onText] receives the words heard so far; [onDone] is
  /// called once when listening stops for any reason.
  Future<bool> start({
    required void Function(String words) onText,
    required void Function() onDone,
  });

  Future<void> stop();
}

class SpeechVoiceInput implements VoiceInput {
  final SpeechToText _speech = SpeechToText();
  bool? _ready;
  void Function()? _onDone;

  void _finish() {
    final done = _onDone;
    _onDone = null;
    done?.call();
  }

  @override
  Future<bool> start({
    required void Function(String words) onText,
    required void Function() onDone,
  }) async {
    try {
      _ready ??= await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            _finish();
          }
        },
        onError: (_) => _finish(),
      );
      if (_ready != true) {
        // Let a later tap retry, e.g. after granting the permission.
        _ready = null;
        return false;
      }
      _onDone = onDone;
      await _speech.listen(
        onResult: (r) => onText(r.recognizedWords),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(minutes: 1),
        ),
      );
      return true;
    } catch (_) {
      _ready = null;
      _finish();
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _finish();
  }
}

/// Overridden in tests with a fake.
final voiceInputProvider = Provider<VoiceInput>((ref) => SpeechVoiceInput());
