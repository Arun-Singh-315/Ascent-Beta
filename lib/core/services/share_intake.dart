import 'dart:async';
import 'dart:io' show Platform;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../database/app_database.dart';
import '../providers/database_provider.dart';

/// Text shared to Ascent from another app ("Share → Ascent") becomes a
/// thought in Mindspace, and the app opens it there.
///
/// Android only for now (an intent filter in AndroidManifest.xml); iOS needs
/// a Share Extension target, which is not set up yet.
class ShareIntake {
  ShareIntake._();

  static StreamSubscription<List<SharedMediaFile>>? _sub;

  /// [container] returns the live provider container (it is replaced when
  /// the workspace restarts). [open] shows the saved thought.
  static Future<void> start({
    required ProviderContainer Function() container,
    required void Function(String location) open,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final intake = ReceiveSharingIntent.instance;
      _sub ??= intake.getMediaStream().listen(
        (items) => _save(items, container(), open),
        onError: (_) {},
      );
      final initial = await intake.getInitialMedia();
      if (initial.isNotEmpty) {
        await _save(initial, container(), open);
        await intake.reset();
      }
    } catch (e) {
      debugPrint('Share intake unavailable: $e');
    }
  }

  /// Saves shared text and links as one thought. Files and images are
  /// ignored for now.
  @visibleForTesting
  static Future<int?> save(
    List<SharedMediaFile> items,
    ThoughtDao dao,
  ) async {
    final text = items
        .where(
          (i) => i.type == SharedMediaType.text || i.type == SharedMediaType.url,
        )
        .map((i) => i.path.trim())
        .where((t) => t.isNotEmpty)
        .join('\n');
    if (text.isEmpty) return null;
    return dao.insertThought(
      ThoughtTableCompanion.insert(
        content: text.length > 5000 ? text.substring(0, 5000) : text,
        mood: const Value('thought'),
      ),
    );
  }

  static Future<void> _save(
    List<SharedMediaFile> items,
    ProviderContainer container,
    void Function(String location) open,
  ) async {
    try {
      final id = await save(items, container.read(thoughtDaoProvider));
      if (id != null) open('/thought-wall?thought=$id');
    } catch (e) {
      debugPrint('Could not save shared text: $e');
    }
  }
}
