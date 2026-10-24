import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../providers/vault_providers.dart';

class VaultLockView extends ConsumerStatefulWidget {
  const VaultLockView({
    super.key,
    this.onUnlocked,
  });

  final VoidCallback? onUnlocked;

  @override
  ConsumerState<VaultLockView> createState() => _VaultLockViewState();
}

class _VaultLockViewState extends ConsumerState<VaultLockView> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isSettingUpPin = false;
  String? _confirmPin;
  bool _hasPin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatusAndPromptBiometrics();
  }

  Future<void> _checkStatusAndPromptBiometrics() async {
    final security = ref.read(vaultSecurityServiceProvider);
    final hasPin = await security.hasMasterPin();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _isSettingUpPin = !hasPin;
      _loading = false;
    });

    if (hasPin) {
      final canBiometrics = await security.canAuthenticateWithBiometrics();
      if (canBiometrics) {
        _triggerBiometrics();
      }
    }
  }

  Future<void> _triggerBiometrics() async {
    final security = ref.read(vaultSecurityServiceProvider);
    final success = await security.authenticateBiometrics(
      reason: 'Scan fingerprint or face to unlock Ascent Vault',
    );
    if (!mounted) return;
    if (success) {
      HapticFeedback.mediumImpact();
      ref.read(vaultSessionUnlockedProvider.notifier).unlock();
      widget.onUnlocked?.call();
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 6) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    if (_isSettingUpPin) {
      if (_enteredPin.length == 4) {
        if (_confirmPin == null) {
          // Move to confirm stage
          setState(() {
            _confirmPin = _enteredPin;
            _enteredPin = '';
          });
        } else {
          // Validate match
          if (_enteredPin == _confirmPin) {
            _savePin(_enteredPin);
          } else {
            HapticFeedback.heavyImpact();
            setState(() {
              _errorMessage = 'PINs did not match. Start over.';
              _enteredPin = '';
              _confirmPin = null;
            });
          }
        }
      }
    } else {
      if (_enteredPin.length >= 4) {
        _submitPinAttempt(_enteredPin);
      }
    }
  }

  Future<void> _savePin(String pin) async {
    final security = ref.read(vaultSecurityServiceProvider);
    await security.setMasterPin(pin);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ref.read(vaultSessionUnlockedProvider.notifier).unlock();
    widget.onUnlocked?.call();
  }

  Future<void> _submitPinAttempt(String pin) async {
    final security = ref.read(vaultSecurityServiceProvider);
    final verified = await security.verifyPin(pin);
    if (!mounted) return;
    if (verified) {
      HapticFeedback.mediumImpact();
      ref.read(vaultSessionUnlockedProvider.notifier).unlock();
      widget.onUnlocked?.call();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'Incorrect PIN';
        _enteredPin = '';
      });
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final headline = _isSettingUpPin
        ? (_confirmPin == null ? 'Set a 4-Digit Master PIN' : 'Confirm Your Master PIN')
        : 'Ascent Vault is Locked';

    final subtitle = _isSettingUpPin
        ? 'Protect your cards, IDs and sensitive documents'
        : 'Enter your Master PIN or use Biometrics';

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── SHIELD BADGE ───────────────────────────────────────────
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: g.clay.withValues(alpha: 0.12),
                  border: Border.all(color: g.clay.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 38,
                  color: g.clay,
                ),
              ),
              const SizedBox(height: AppSpace.s16),

              // ── HEADLINE & SUBTITLE ────────────────────────────────────
              Text(
                headline,
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                subtitle,
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: g.inkMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s24),

              // ── PIN DOTS INDICATOR ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? g.clay : Colors.transparent,
                      border: Border.all(
                        color: filled ? g.clay : g.inkMuted.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpace.s12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: AppSpace.s24),

              // ── KEYPAD ─────────────────────────────────────────────────
              _buildKeypad(context, g),

              const SizedBox(height: AppSpace.s16),

              // ── BIOMETRICS SHORTCUT ────────────────────────────────────
              if (_hasPin)
                TextButton.icon(
                  onPressed: _triggerBiometrics,
                  icon: const Icon(Icons.fingerprint_rounded, size: 22),
                  label: const Text('Unlock with Fingerprint / Face ID'),
                  style: TextButton.styleFrom(
                    foregroundColor: g.clay,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(BuildContext context, AscentGlass g) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 1; col <= 3; col++)
                  _buildDigitButton((row * 3 + col).toString(), g),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 76, height: 56),
            _buildDigitButton('0', g),
            SizedBox(
              width: 76,
              height: 56,
              child: IconButton(
                icon: Icon(Icons.backspace_outlined, color: g.inkMuted, size: 22),
                onPressed: _onBackspace,
                tooltip: 'Backspace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigitButton(String digit, AscentGlass g) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      width: 60,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onDigitPressed(digit),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: g.fill.withValues(alpha: 0.4),
              border: Border.all(color: g.line.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: g.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
