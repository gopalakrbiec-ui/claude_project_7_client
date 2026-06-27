import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final local = switch (digits.length) {
    12 when digits.startsWith('91') => digits.substring(2),
    10 => digits,
    _ => null,
  };
  if (local == null) return null;
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
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  String? get _normalisedPhone => normaliseIndianPhone(_controller.text);
  bool get _canSend => _normalisedPhone != null && !_isLoading;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: kDebugMode ? '8618991478' : '',
    );
    _controller.addListener(() => setState(() => _errorMessage = null));
    // Open keyboard automatically (except in debug where number is pre-filled).
    if (!kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final phone = _normalisedPhone;
    if (phone == null) return;
    _focusNode.unfocus();

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
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Gradient hero ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            height: size.height * 0.36,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B23), Color(0xFFC21860)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App icon-style camera+heart badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Yaadein',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Memories made beautiful',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Form area ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter your mobile number',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "We'll send a one-time password to verify",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Phone field
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      fontSize: 26,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _canSend ? _onSend() : null,
                    decoration: InputDecoration(
                      prefixText: '+91  ',
                      prefixStyle: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                      ),
                      hintText: '00000 00000',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.outlineVariant,
                        letterSpacing: 3,
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFFFF6B23), width: 2.5),
                      ),
                      errorText: _errorMessage,
                      errorMaxLines: 3,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Send OTP button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _canSend ? _onSend : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B23),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            theme.colorScheme.outlineVariant.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send OTP',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'By continuing you agree to our Terms of Service.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
