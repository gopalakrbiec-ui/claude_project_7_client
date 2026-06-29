import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/token_storage.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(tokenStorageProvider).writeProfile(
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            country: _countryCtrl.text.trim(),
            state: _stateCtrl.text.trim(),
          );
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpaceLg, vertical: kSpaceXl),
                decoration: const BoxDecoration(
                  gradient: kBrandGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.person_add_outlined, size: 52, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tell us a bit about yourself',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(kSpaceLg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: kSpaceMd),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: _firstNameCtrl,
                              label: 'First Name',
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: kSpaceSm),
                          Expanded(
                            child: _Field(
                              controller: _lastNameCtrl,
                              label: 'Last Name',
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpaceMd),
                      _Field(
                        controller: _emailCtrl,
                        label: 'Email (optional)',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: kSpaceMd),
                      _Field(
                        controller: _cityCtrl,
                        label: 'City',
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: kSpaceMd),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: _stateCtrl,
                              label: 'State (optional)',
                            ),
                          ),
                          const SizedBox(width: kSpaceSm),
                          Expanded(
                            child: _Field(
                              controller: _countryCtrl,
                              label: 'Country',
                              initialValue: 'India',
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpaceLg),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Get Started'),
                      ),
                      const SizedBox(height: kSpaceMd),
                      TextButton(
                        onPressed: () => context.go('/home'),
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
    this.initialValue,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    if (initialValue != null && controller.text.isEmpty) {
      controller.text = initialValue!;
    }
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
