import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project, given at build time:
/// `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
///
/// The anon key is public by design (row-level security protects the data).
/// Secret keys (the assistant model's) never ship in the app; they live in
/// Supabase Edge Function secrets.
class CloudConfig {
  const CloudConfig({required this.url, required this.anonKey});

  static const fromEnvironment = CloudConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String url;
  final String anonKey;

  /// Online features exist only when a project is configured. Without one
  /// the app is fully offline and shows no cloud surfaces (no dead ends).
  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

/// The signed-in person, as far as the app needs to know.
class CloudUser {
  const CloudUser({required this.id, required this.email});
  final String id;
  final String? email;
}

/// One backup stored in the cloud.
class CloudBackup {
  const CloudBackup({
    required this.name,
    required this.createdAt,
    required this.bytes,
  });
  final String name;
  final DateTime createdAt;
  final int bytes;
}

/// A cloud request failed; [message] is shown to the person as is.
class CloudException implements Exception {
  const CloudException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Everything Ascent asks of its backend. The app talks only to this
/// interface, so it runs (and is tested) without a network.
abstract class CloudGateway {
  bool get available;
  CloudUser? get currentUser;
  Stream<CloudUser?> get userChanges;

  /// Emails a 6-digit sign-in code (creates the account on first use).
  Future<void> sendCode(String email);
  Future<CloudUser> verifyCode(String email, String code);
  Future<void> signOut();

  Future<void> uploadBackup(String name, Uint8List bytes);
  Future<List<CloudBackup>> listBackups();
  Future<Uint8List> downloadBackup(String name);
  Future<void> deleteBackup(String name);
}

/// No project configured: nothing online, nothing shown.
class OfflineCloudGateway implements CloudGateway {
  const OfflineCloudGateway();
  @override
  bool get available => false;
  @override
  CloudUser? get currentUser => null;
  @override
  Stream<CloudUser?> get userChanges => const Stream.empty();
  static const _off = CloudException('Cloud is not set up in this build.');
  @override
  Future<void> sendCode(String email) => Future.error(_off);
  @override
  Future<CloudUser> verifyCode(String email, String code) =>
      Future.error(_off);
  @override
  Future<void> signOut() async {}
  @override
  Future<void> uploadBackup(String name, Uint8List bytes) =>
      Future.error(_off);
  @override
  Future<List<CloudBackup>> listBackups() async => const [];
  @override
  Future<Uint8List> downloadBackup(String name) => Future.error(_off);
  @override
  Future<void> deleteBackup(String name) => Future.error(_off);
}

/// Supabase: email one-time codes for auth, a private Storage bucket
/// (`backups/<user id>/…`, locked to its owner by policy) for backups.
class SupabaseCloudGateway implements CloudGateway {
  SupabaseCloudGateway(this._client);
  final SupabaseClient _client;

  static const bucket = 'backups';

  @override
  bool get available => true;

  CloudUser? _map(User? u) =>
      u == null ? null : CloudUser(id: u.id, email: u.email);

  @override
  CloudUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<CloudUser?> get userChanges =>
      _client.auth.onAuthStateChange.map((s) => _map(s.session?.user));

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthException catch (e) {
      throw CloudException(_authMessage(e));
    } on StorageException catch (e) {
      throw CloudException(
        e.statusCode == '404'
            ? 'That backup is no longer in the cloud.'
            : 'The cloud could not finish that. Try again.',
      );
    } on CloudException {
      rethrow;
    } catch (_) {
      throw const CloudException(
        'Could not reach the cloud. Check your connection and try again.',
      );
    }
  }

  static String _authMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('expired') || m.contains('invalid')) {
      return 'That code did not work. Check it or send a new one.';
    }
    if (m.contains('rate') || e.statusCode == '429') {
      return 'Too many tries. Wait a minute and send a new code.';
    }
    return 'Sign-in failed. Try again.';
  }

  String get _folder {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const CloudException('Sign in first.');
    return id;
  }

  @override
  Future<void> sendCode(String email) =>
      _guard(() => _client.auth.signInWithOtp(email: email.trim()));

  @override
  Future<CloudUser> verifyCode(String email, String code) => _guard(() async {
    final res = await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.email,
    );
    final user = _map(res.user);
    if (user == null) {
      throw const CloudException('Sign-in failed. Try again.');
    }
    return user;
  });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<void> uploadBackup(String name, Uint8List bytes) => _guard(
    () => _client.storage
        .from(bucket)
        .uploadBinary(
          '$_folder/$name',
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
          ),
        ),
  );

  @override
  Future<List<CloudBackup>> listBackups() => _guard(() async {
    final files = await _client.storage
        .from(bucket)
        .list(
          path: _folder,
          searchOptions: const SearchOptions(
            limit: 100,
            sortBy: SortBy(column: 'created_at', order: 'desc'),
          ),
        );
    return [
      for (final f in files)
        if (f.name.isNotEmpty && !f.name.startsWith('.'))
          CloudBackup(
            name: f.name,
            createdAt:
                DateTime.tryParse(f.createdAt ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
            bytes: (f.metadata?['size'] as num?)?.toInt() ?? 0,
          ),
    ];
  });

  @override
  Future<Uint8List> downloadBackup(String name) =>
      _guard(() => _client.storage.from(bucket).download('$_folder/$name'));

  @override
  Future<void> deleteBackup(String name) =>
      _guard(() => _client.storage.from(bucket).remove(['$_folder/$name']));
}
