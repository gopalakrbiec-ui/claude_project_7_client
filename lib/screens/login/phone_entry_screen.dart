import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_error.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants.dart';

// ---------------------------------------------------------------------------
// Phone normalisation (pure function — easy to unit-test)
// ---------------------------------------------------------------------------

/// Returns +91XXXXXXXXXX if valid Indian mobile, null otherwise.
String? normaliseIndianPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  // Strip country code prefix if already included.
  final local = switch (digits.length) {
    12 when digits.startsWith('91') => digits.substring(2),
    10 => digits,
    _ => null,
  };
  if (local == null) return null;
  // Indian mobile must start with 6–9.
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(local)) return null;
  return '+91$local';
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final List<String> _digits = [];
  bool _isLoading = false;
  String? _errorMessage;

  String get _display {
    final d = _digits.join();
    if (d.isEmpty) return '';
    if (d.length <= 5) return d;
    return '${d.substring(0, 5)} ${d.substring(5)}';
  }

  String? get _normalisedPhone =>
      _digits.length == 10 ? normaliseIndianPhone(_digits.join()) : null;

  void _onDigit(String d) {
    if (_digits.length >= 10) return;
    setState(() {
      _digits.add(d);
      _errorMessage = null;
    });
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _onSend() async {
    final phone = _normalisedPhone;
    if (phone == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (mounted) context.go('/login/otp', extra: {'phone': phone});
    } on ServerError catch (e) {
      setState(() => _errorMessage = e.message);
    } on NetworkError catch (_) {
      setState(() => _errorMessage =
          'No internet connection. Please check your network and retry.');
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _normalisedPhone != null && !_isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Display ──────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpaceLg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter your mobile number',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: kSpaceSm),
                      Text(
                        "We'll send a one-time password to verify",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: kSpaceXl),

                      // Phone display box
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpaceLg,
                          vertical: kSpaceMd,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _errorMessage != null
                                ? theme.colorScheme.error
                                : _digits.length == 10
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '+91 ',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _display.isEmpty ? '     ' : _display,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                  color: _display.isEmpty
                                      ? theme.colorScheme.outlineVariant
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            // Digit count indicator
                            Text(
                              '${_digits.length}/10',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: kSpaceSm),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Numeric keypad ────────────────────────────────────────────
            Container(
              color: theme.colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.fromLTRB(
                  kSpaceMd, kSpaceSm, kSpaceMd, kSpaceLg),
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    _KeypadRow(
                        keys: row.map((d) => _DigitKey(d, onTap: _onDigit)).toList()),
                  _KeypadRow(keys: [
                    const _EmptyKey(),
                    _DigitKey('0', onTap: _onDigit),
                    if (_isLoading)
                      const _ActionKey(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                    else if (canSend)
                      _ActionKey(
                        onTap: _onSend,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 28,
                        ),
                        filled: true,
                      )
                    else
                      _ActionKey(
                        onTap: _digits.isNotEmpty ? _onBackspace : null,
                        child: const Icon(Icons.backspace_outlined, size: 26),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Keypad building blocks
// ---------------------------------------------------------------------------

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({required this.keys});
  final List<Widget> keys;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys.map((k) => Expanded(child: k)).toList(),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey(this.digit, {required this.onTap});
  final String digit;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _KeyBase(
      onTap: () => onTap(digit),
      child: Text(
        digit,
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({this.onTap, required this.child, this.filled = false});
  final VoidCallback? onTap;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _KeyBase(
      onTap: onTap,
      fillColor: filled ? theme.colorScheme.primary : null,
      child: child,
    );
  }
}

class _EmptyKey extends StatelessWidget {
  const _EmptyKey();

  @override
  Widget build(BuildContext context) => const SizedBox(height: kMinTapTarget + 12);
}

class _KeyBase extends StatelessWidget {
  const _KeyBase({this.onTap, required this.child, this.fillColor});
  final VoidCallback? onTap;
  final Widget child;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: fillColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: kMinTapTarget + 12,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
