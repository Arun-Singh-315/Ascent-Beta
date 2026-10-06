import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';

const _kAuthLoggedInKey = 'ascent_is_authenticated_v1';
const _kAuthUsernameKey = 'ascent_auth_username_v1';

class AuthState {
  final bool isAuthenticated;
  final String username;

  const AuthState({
    required this.isAuthenticated,
    required this.username,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? username,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      username: username ?? this.username,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  SharedPreferences? _prefs;

  @override
  AuthState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final isAuth = _prefs?.getBool(_kAuthLoggedInKey) ?? false;
    final user = _prefs?.getString(_kAuthUsernameKey) ?? 'arn';
    return AuthState(isAuthenticated: isAuth, username: user);
  }

  Future<bool> login(String username, String password) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    // Standard credential check (arn / 1234)
    if (cleanUser == 'arn' && cleanPass == '1234') {
      await _prefs?.setBool(_kAuthLoggedInKey, true);
      await _prefs?.setString(_kAuthUsernameKey, 'arn');
      state = const AuthState(isAuthenticated: true, username: 'arn');
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _prefs?.setBool(_kAuthLoggedInKey, false);
    state = const AuthState(isAuthenticated: false, username: 'arn');
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
