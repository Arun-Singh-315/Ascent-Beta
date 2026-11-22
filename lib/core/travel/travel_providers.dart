import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../utils/uuid.dart';
import 'here_locator.dart';
import 'travel_service.dart';

final travelServiceProvider = Provider<TravelService>(
  (ref) => TravelService(ref.watch(databaseProvider)),
);

final hereLocatorProvider = Provider<HereLocator>(
  (ref) => const DeviceHereLocator(),
);

/// Ticks whenever anything in Travel changes. It counts up so each change
/// is a new value (a repeated `null` would look unchanged and skip rebuilds).
final _travelChangesProvider = StreamProvider<int>((ref) {
  var n = 0;
  return ref.watch(travelServiceProvider).changes().map((_) => ++n);
});

/// Every trip, newest first.
final tripsProvider = FutureProvider<List<TripView>>((ref) {
  ref.watch(_travelChangesProvider);
  return ref.watch(travelServiceProvider).trips();
});

final tripProvider = FutureProvider.family<TripView?, String>((ref, id) {
  ref.watch(_travelChangesProvider);
  return ref.watch(travelServiceProvider).trip(id);
});

/// The trip happening today, if any.
final liveTripProvider = Provider<TripView?>((ref) {
  final now = DateTime.now();
  return ref
      .watch(tripsProvider)
      .value
      ?.where((t) => t.isLive(now))
      .firstOrNull;
});

/// Recent visits, newest first.
final recentVisitsProvider = FutureProvider<List<VisitRow>>((ref) {
  ref.watch(_travelChangesProvider);
  return ref.watch(travelServiceProvider).visits(limit: 50);
});

final visitProvider = FutureProvider.family<VisitRow?, String>((ref, id) {
  ref.watch(_travelChangesProvider);
  return ref.watch(travelServiceProvider).visit(id);
});

final visitPhotosProvider = FutureProvider.family<List<VisitPhotoRow>, String>((
  ref,
  visitId,
) {
  ref.watch(_travelChangesProvider);
  return ref.watch(travelServiceProvider).photos(visitId: visitId);
});

final tripPhotosProvider = FutureProvider.family<List<VisitPhotoRow>, String>((
  ref,
  tripId,
) {
  ref.watch(_travelChangesProvider);
  return ref.watch(travelServiceProvider).photos(tripId: tripId);
});

final visitBillsProvider = FutureProvider.family<List<TripExpenseRow>, String>((
  ref,
  visitId,
) {
  ref.watch(_travelChangesProvider);
  return ref.watch(travelServiceProvider).billsFor(visitId);
});

/// Visits Home should ask about.
final visitPromptsProvider = FutureProvider<List<VisitPrompt>>((ref) {
  ref.watch(_travelChangesProvider);
  return ref.watch(travelServiceProvider).prompts();
});

/// Picks photos from the gallery and copies them into the app's private
/// folder, so they survive if the originals are deleted. Returns the copies.
Future<List<String>> pickVisitPhotos() async {
  final picked = await ImagePicker().pickMultiImage(
    imageQuality: 85,
    limit: 30,
  );
  if (picked.isEmpty) return const [];
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'travel_photos'));
  await dir.create(recursive: true);
  final out = <String>[];
  for (final x in picked) {
    final ext = p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path);
    final copy = await File(x.path).copy(p.join(dir.path, '${newUuid()}$ext'));
    out.add(copy.path);
  }
  return out;
}

/// Names visits captured offline once the phone can look them up.
Future<void> nameOfflineVisits(TravelService travel, HereLocator here) async {
  for (final v in await travel.unnamedVisits()) {
    if (v.lat == null || v.lon == null) continue;
    try {
      final guesses = await here.name(LocationFix(v.lat!, v.lon!));
      if (guesses.isEmpty) continue;
      await travel.editVisit(v.id, name: guesses.first.name);
    } catch (_) {
      return; // Still offline; try again next launch.
    }
  }
}
