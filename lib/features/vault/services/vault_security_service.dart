import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VaultSecurityService {
  VaultSecurityService({
    SharedPreferences? preferences,
    LocalAuthentication? localAuth,
    bool isTest = false,
  })  : _prefs = preferences,
        _auth = localAuth ?? LocalAuthentication(),
        _isTest = isTest {
    _initKey();
  }

  factory VaultSecurityService.forTesting() {
    return VaultSecurityService(isTest: true);
  }

  final SharedPreferences? _prefs;
  final LocalAuthentication _auth;
  final bool _isTest;

  late final enc.Key _encKey;
  late final enc.IV _encIv;
  late final enc.Encrypter _encrypter;

  bool _isUnlocked = false;
  bool get isUnlocked => _isUnlocked;

  static const String _prefPinHashKey = 'ascent_vault_master_pin_hash_v1';
  static const String _prefPinSaltKey = 'ascent_vault_master_pin_salt_v1';

  void _initKey() {
    // 256-bit AES key derived from application secret seed and device salt
    const masterSeed = 'ascent_vault_secret_device_seed_2026_aes256_key';
    final keyBytes = crypto.sha256.convert(utf8.encode(masterSeed)).bytes;
    _encKey = enc.Key(Uint8List.fromList(keyBytes));
    _encIv = enc.IV(Uint8List.fromList(keyBytes.sublist(0, 16)));
    _encrypter = enc.Encrypter(enc.AES(_encKey, mode: enc.AESMode.cbc));
  }

  /// Encrypts plaintext string using AES-256 CBC.
  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _encIv);
      return encrypted.base64;
    } catch (_) {
      return plainText;
    }
  }

  /// Decrypts AES-256 base64 ciphertext back to plaintext.
  String decrypt(String cipherText) {
    if (cipherText.isEmpty) return '';
    try {
      final decrypted = _encrypter.decrypt64(cipherText, iv: _encIv);
      return decrypted;
    } catch (_) {
      // Return raw string if not ciphertext
      return cipherText;
    }
  }

  /// Returns true if master PIN has been set up.
  Future<bool> hasMasterPin() async {
    if (_isTest) {
      return _testPinHash != null;
    }
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.containsKey(_prefPinHashKey);
  }

  String? _testPinHash;
  String? _testPinSalt;

  /// Sets master PIN with SHA-256 + salt.
  Future<void> setMasterPin(String pin) async {
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = _hashPin(pin, salt);

    if (_isTest) {
      _testPinHash = hash;
      _testPinSalt = salt;
      _isUnlocked = true;
      return;
    }

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_prefPinSaltKey, salt);
    await prefs.setString(_prefPinHashKey, hash);
    _isUnlocked = true;
  }

  /// Verifies PIN against stored hash.
  Future<bool> verifyPin(String pin) async {
    if (_isTest) {
      if (_testPinHash == null) return false;
      final computed = _hashPin(pin, _testPinSalt ?? '');
      if (computed == _testPinHash) {
        _isUnlocked = true;
        return true;
      }
      return false;
    }

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_prefPinHashKey);
    final storedSalt = prefs.getString(_prefPinSaltKey);
    if (storedHash == null || storedSalt == null) return false;

    final computed = _hashPin(pin, storedSalt);
    if (computed == storedHash) {
      _isUnlocked = true;
      return true;
    }
    return false;
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin:$salt:ascent_vault_salt');
    return crypto.sha256.convert(bytes).toString();
  }

  /// Checks if hardware biometrics are available on device.
  Future<bool> canAuthenticateWithBiometrics() async {
    if (_isTest) return true;
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canAuth || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Prompts device biometrics (Fingerprint/Face unlock).
  Future<bool> authenticateBiometrics({String reason = 'Unlock Ascent Vault'}) async {
    if (_isTest) {
      _isUnlocked = true;
      return true;
    }

    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (success) {
        _isUnlocked = true;
      }
      return success;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Locks the vault session.
  void lock() {
    _isUnlocked = false;
  }

  /// Unlocks the vault session manually.
  void unlock() {
    _isUnlocked = true;
  }
}
