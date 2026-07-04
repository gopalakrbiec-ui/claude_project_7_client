import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/locale_controller.dart';
import '../../core/constants.dart';

class LanguageSelectScreen extends ConsumerWidget {
  const LanguageSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kSpaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo / app name
              Icon(Icons.auto_awesome, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: kSpaceMd),
              Text(
                'Savi Nenapu',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: kSpaceXl),
              Text(
                'Choose Your Language\nअपनी भाषा चुनें\nమీ భాషను ఎంచుకోండి',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: kSpaceXl),
              // Language options
              ...kSupportedLocales.map(
                (locale) => _LanguageTile(locale: locale),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final displayName =
        kLocaleDisplayNames[locale.languageCode] ?? locale.languageCode;
    final currentLocale = ref.watch(localeControllerProvider).valueOrNull;
    final isSelected = currentLocale?.languageCode == locale.languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpaceSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await ref.read(localeControllerProvider.notifier).setLocale(locale);
          // Router redirect fires automatically via RouterNotifier.
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpaceMd,
            vertical: kSpaceMd + 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 2.5 : 1.5,
            ),
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: kSpaceMd),
              Text(
                displayName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
