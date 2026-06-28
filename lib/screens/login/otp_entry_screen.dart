import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_error.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/otp_input_field.dart' show OtpInputField, OtpInputFieldState;

const _kResendCooldownSeconds = 60;

class OtpEntryScreen extends ConsumerStatefulWidget {
  const OtpEntryScreen({super.key, required this.normalisedPhone});
  final String normalisedPhone;

  @override
  ConsumerState<OtpEntryScreen> createState() => _OtpEntryScreenState();
}

class _OtpEntryScreenState extends ConsumerState<OtpEntryScreen> {
  final _otpKey = GlobalKey<OtpInputFieldState>();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  int _attemptsRemaining = 3; // shown to user on wrong-code errors

  int _resendSecondsLeft = _kResendCooldownSeconds;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpKey.currentState?.prefill('000000');
        // Auto-submit after a short delay so the tester can see the pre-fill.
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _onOtpCompleted('000000');
        });
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _kResendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSecondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendSecondsLeft = 0);
      } else {
        if (mounted) setState(() => _resendSecondsLeft--);
      }
    });
  }

  Future<void> _onOtpCompleted(String otp) async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(widget.normalisedPhone, otp);
      // Router redirect to /home fires automatically via RouterNotifier.
    } on ServerError catch (e) {
      _otpKey.currentState?.clear();
      if (e.statusCode == 429) {
        setState(() {
          _errorMessage = 'Too many attempts. Please try again later.';
          _attemptsRemaining = 0;
        });
      } else if (e.statusCode == 401) {
        setState(() {
          _errorMessage = 'OTP has expired. Please request a new one.';
        });
      } else {
        // 400: wrong code — track attempt count
        setState(() {
          _attemptsRemaining = (_attemptsRemaining - 1).clamp(0, 3);
          _errorMessage = _attemptsRemaining > 0
              ? 'Incorrect OTP. $_attemptsRemaining attempt${_attemptsRemaining == 1 ? '' : 's'} remaining.'
              : 'No attempts remaining. Please request a new OTP.';
        });
      }
    } on NetworkError catch (_) {
      setState(() => _errorMessage =
          'No internet connection. Check your network and try again.');
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _onResend() async {
    if (_resendSecondsLeft > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _attemptsRemaining = 3;
    });
    _otpKey.currentState?.clear();

    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestOtp(widget.normalisedPhone);
      _startResendTimer();
    } on ServerError catch (e) {
      setState(() => _errorMessage = e.message);
    } on NetworkError catch (_) {
      setState(() =>
          _errorMessage = 'No internet connection. Please try again.');
    } catch (_) {
      setState(() => _errorMessage = 'Could not resend OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Display as +91 XXXXX XXXXX
    final displayPhone = widget.normalisedPhone.length == 13
        ? '${widget.normalisedPhone.substring(0, 3)} '
            '${widget.normalisedPhone.substring(3, 8)} '
            '${widget.normalisedPhone.substring(8)}'
        : widget.normalisedPhone;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gradient hero — same visual language as phone entry
              Stack(
                children: [
                  Container(
                    height: 200,
                    decoration: const BoxDecoration(
                      gradient: kBrandGradient,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                  const Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mark_email_read_outlined,
                            size: 52, color: Colors.white),
                        SizedBox(height: 10),
                        Text(
                          'OTP Sent!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(kSpaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              const SizedBox(height: kSpaceLg),

              Text(
                'Enter the 6-digit code',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: kSpaceSm),
              Text(
                'Sent to $displayPhone',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: kSpaceXl),

              // Auto-advancing OTP boxes
              OtpInputField(
                key: _otpKey,
                onCompleted: _onOtpCompleted,
              ),

              const SizedBox(height: kSpaceMd),

              // Loading indicator
              if (_isVerifying)
                const Center(child: CircularProgressIndicator()),

              // Error message with attempt count
              if (_errorMessage != null) ...[
                const SizedBox(height: kSpaceMd),
                Container(
                  padding: const EdgeInsets.all(kSpaceMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],

              const SizedBox(height: kSpaceXl),

              // Resend timer / button
              if (_resendSecondsLeft > 0)
                Text(
                  'Resend OTP in ${_resendSecondsLeft}s',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                TextButton(
                  onPressed: _isResending ? null : _onResend,
                  child: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resend OTP'),
                ),

              const SizedBox(height: kSpaceLg),

              // Wrong number?
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Wrong number? Change it',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

