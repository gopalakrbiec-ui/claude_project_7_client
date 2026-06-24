import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants.dart';
import '../../widgets/loading_overlay.dart';

enum _LoginStep { phone, otp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _LoginStep _step = _LoginStep.phone;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .sendOtp(_phoneController.text.trim());
    if (mounted &&
        ref.read(authControllerProvider).hasError == false) {
      setState(() => _step = _LoginStep.otp);
    }
  }

  Future<void> _onVerify() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).verifyOtp(
          _phoneController.text.trim(),
          _otpController.text.trim(),
        );
    // Router redirect to /home fires automatically on auth state change.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final error = authState.hasError ? authState.error.toString() : null;
    final theme = Theme.of(context);

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kSpaceLg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.phone_android,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: kSpaceLg),
                    Text(
                      _step == _LoginStep.phone
                          ? 'Enter your mobile number'
                          : 'Enter the OTP',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: kSpaceSm),
                    Text(
                      _step == _LoginStep.phone
                          ? "We'll send a one-time password to verify"
                          : 'Sent to ${_phoneController.text}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: kSpaceXl),
                    if (_step == _LoginStep.phone) ...[
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixText: '+91 ',
                          hintText: '98765 43210',
                        ),
                        validator: (v) {
                          if (v == null || v.length < 10) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: kSpaceLg),
                      ElevatedButton(
                        onPressed: isLoading ? null : _onSendOtp,
                        child: const Text('Send OTP'),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'One-Time Password',
                          hintText: '6-digit code',
                        ),
                        validator: (v) {
                          if (v == null || v.length != 6) {
                            return 'Enter the 6-digit OTP';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: kSpaceLg),
                      ElevatedButton(
                        onPressed: isLoading ? null : _onVerify,
                        child: const Text('Verify & Login'),
                      ),
                      const SizedBox(height: kSpaceMd),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => setState(() {
                                  _step = _LoginStep.phone;
                                  _otpController.clear();
                                }),
                        child: const Text('Change number'),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: kSpaceMd),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
