import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/backup/backup_providers.dart';
import 'package:ascent/core/backup/backup_service.dart';
import 'package:ascent/core/cloud/cloud_gateway.dart';
import 'package:ascent/core/cloud/cloud_providers.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/settings/cloud_backup_section.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCloud implements CloudGateway {
  final files = <String, Uint8List>{};
  final _users = StreamController<CloudUser?>.broadcast();
  CloudUser? user;
  String? codeSentTo;
  bool failUpload = false;

  @override
  bool get available => true;
  @override
  CloudUser? get currentUser => user;
  @override
  Stream<CloudUser?> get userChanges => _users.stream;
  @override
  Future<void> sendCode(String email) async => codeSentTo = email;
  @override
  Future<CloudUser> verifyCode(String email, String code) async {
    if (code != '123456') {
      throw const CloudException('That code did not work.');
    }
    user = CloudUser(id: 'u1', email: email);
    _users.add(user);
    return user!;
  }

  @override
  Future<void> signOut() async {
    user = null;
    _users.add(null);
  }

  @override
  Future<void> uploadBackup(String name, Uint8List bytes) async {
    if (failUpload) throw const CloudException('Could not reach the cloud.');
    files[name] = bytes;
  }

  @override
  Future<List<CloudBackup>> listBackups() async {
    final names = files.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final n in names)
        CloudBackup(
          name: n,
          createdAt: DateTime.now(),
          bytes: files[n]!.length,
        ),
    ];
  }

  @override
  Future<Uint8List> downloadBackup(String name) async => files[name]!;
  @override
  Future<void> deleteBackup(String name) async => files.remove(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tmp;
  late AppDatabase db;
  late SharedPreferences prefs;
  late BackupService backups;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('ascent_cloud_');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    backups = BackupService(db, prefs, documents: () async => tmp);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('CloudBackupService', () {
    test(
      'uploads only an encrypted backup and refuses short passwords',
      () async {
        final cloud = FakeCloud()
          ..user = const CloudUser(id: 'u1', email: 'a@b.co');
        final service = CloudBackupService(cloud, backups);
        expect(() => service.upload('123'), throwsA(isA<CloudException>()));
        final saved = await service.upload('secret-pass');
        final bytes = cloud.files[saved.name]!;
        final copy = File('${tmp.path}/check${BackupService.extension}')
          ..writeAsBytesSync(bytes);
        expect(BackupService.isEncrypted(copy), isTrue);
        // The plain SQLite header never leaves the phone.
        expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
      },
    );

    test('keeps the newest ten cloud backups', () async {
      final cloud = FakeCloud()..user = const CloudUser(id: 'u1', email: null);
      for (var i = 0; i < 12; i++) {
        cloud.files['old-${i.toString().padLeft(2, '0')}'] = Uint8List(1);
      }
      final service = CloudBackupService(cloud, backups);
      await service.upload('secret-pass');
      expect(cloud.files.length, CloudBackupService.keep);
    });

    test(
      'download returns a restorable file; foreign files are refused',
      () async {
        final cloud = FakeCloud()
          ..user = const CloudUser(id: 'u1', email: null);
        final service = CloudBackupService(cloud, backups);
        final saved = await service.upload('secret-pass');
        final file = await service.download(saved.name);
        final (plain, summary) = await backups.open(
          file,
          password: 'secret-pass',
        );
        expect(summary.counts, isNotEmpty);
        await plain.delete();

        cloud.files['junk${BackupService.extension}'] = Uint8List.fromList(
          List.filled(64, 7),
        );
        expect(
          () => service.download('junk${BackupService.extension}'),
          throwsA(isA<CloudException>()),
        );
      },
    );
  });

  group('CloudBackupSection', () {
    Future<void> pump(
      WidgetTester t,
      CloudGateway cloud, {
      bool dark = false,
      double scale = 1,
      Size size = const Size(390, 900),
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            cloudGatewayProvider.overrideWithValue(cloud),
            backupServiceProvider.overrideWithValue(backups),
          ],
          child: MaterialApp(
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CloudBackupSection(onRestore: (_) async {}),
              ),
            ),
          ),
        ),
      );
      await t.pump();
    }

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 6; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('hidden when this build has no cloud', (t) async {
      await pump(t, const OfflineCloudGateway());
      expect(find.byKey(const ValueKey('cloud_section')), findsNothing);
    });

    testWidgets('sign in with an emailed code, then see the backup action', (
      t,
    ) async {
      final cloud = FakeCloud();
      await pump(t, cloud);
      await t.enterText(find.byKey(const ValueKey('cloud_email')), 'nope');
      await t.tap(find.byKey(const ValueKey('cloud_send_code')));
      await settle(t);
      expect(find.byKey(const ValueKey('cloud_error')), findsOneWidget);
      expect(cloud.codeSentTo, isNull);

      await t.enterText(
        find.byKey(const ValueKey('cloud_email')),
        'me@example.com',
      );
      await t.tap(find.byKey(const ValueKey('cloud_send_code')));
      await settle(t);
      expect(cloud.codeSentTo, 'me@example.com');

      await t.enterText(find.byKey(const ValueKey('cloud_code')), '000000');
      await t.tap(find.byKey(const ValueKey('cloud_verify')));
      await settle(t);
      expect(find.text('That code did not work.'), findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('cloud_code')), '123456');
      await t.tap(find.byKey(const ValueKey('cloud_verify')));
      await settle(t);
      expect(find.byKey(const ValueKey('cloud_upload')), findsOneWidget);
      expect(find.textContaining('me@example.com'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a failed upload says so and keeps the screen usable', (
      t,
    ) async {
      final cloud = FakeCloud()
        ..user = const CloudUser(id: 'u1', email: 'me@example.com')
        ..failUpload = true;
      await pump(t, cloud);
      await settle(t);
      await t.enterText(
        find.byKey(const ValueKey('cloud_password')),
        'secret-pass',
      );
      await t.tap(find.byKey(const ValueKey('cloud_upload')));
      // Making the encrypted backup is real file work; give it time.
      for (var i = 0; i < 40; i++) {
        await settle(t);
        if (find.text('Could not reach the cloud.').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text('Could not reach the cloud.'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    for (final dark in [false, true]) {
      testWidgets('fits 320 px at text scale 2 (dark=$dark)', (t) async {
        await pump(
          t,
          FakeCloud(),
          dark: dark,
          scale: 2,
          size: const Size(320, 1200),
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  });
}
