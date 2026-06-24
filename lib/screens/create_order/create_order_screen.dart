import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../controllers/create_order_controller.dart';
import '../../controllers/credits_controller.dart';
import '../../controllers/templates_controller.dart';
import '../../core/constants.dart';
import '../../models/template.dart';
import '../../repositories/templates_repository.dart';
import '../../widgets/error_view.dart';

class CreateOrderScreen extends ConsumerWidget {
  const CreateOrderScreen({
    super.key,
    required this.templateId,
    this.preloaded,
  });

  final String templateId;
  final Template? preloaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = preloaded ??
        ref.read(templatesRepositoryProvider).getCached(templateId);

    if (template != null) {
      return _CreateOrderContent(template: template);
    }

    final templatesAsync = ref.watch(templatesControllerProvider);
    return templatesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Could not load template.',
          onRetry: () =>
              ref.read(templatesControllerProvider.notifier).refresh(),
        ),
      ),
      data: (templates) {
        final matches = templates.where((t) => t.id == templateId);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Template not found.')),
          );
        }
        return _CreateOrderContent(template: matches.first);
      },
    );
  }
}

// ---------------------------------------------------------------------------
class _CreateOrderContent extends ConsumerStatefulWidget {
  const _CreateOrderContent({required this.template});
  final Template template;

  @override
  ConsumerState<_CreateOrderContent> createState() =>
      _CreateOrderContentState();
}

class _CreateOrderContentState extends ConsumerState<_CreateOrderContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Template get _template => widget.template;

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.read(
        createOrderControllerProvider(widget.template.id).notifier);
    final state =
        ref.watch(createOrderControllerProvider(widget.template.id));
    final balanceAsync = ref.watch(creditsControllerProvider);
    final canAfford =
        balanceAsync.valueOrNull?.canAfford(_template.basePricePaise) ?? true;
    final theme = Theme.of(context);

    // Navigate to order-status once order is created.
    ref.listen(createOrderControllerProvider(widget.template.id),
        (prev, next) {
      if (next.isSuccess && next.createdOrder != null) {
        context.go(
          '/home/order-status/${next.createdOrder!.id}',
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(kSpaceLg),
          children: [
            // Price summary
            _PriceSummary(template: _template, canAfford: canAfford),
            const SizedBox(height: kSpaceLg),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name(s) *',
                hintText: 'e.g. Priya & Ravi',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a name';
                if (v.trim().length < 2) return 'Name must be at least 2 characters';
                return null;
              },
              onChanged: ctrl.setName,
            ),
            const SizedBox(height: kSpaceMd),

            // Event date picker
            _DateField(
              selected: state.eventDate,
              onChanged: ctrl.setEventDate,
            ),
            const SizedBox(height: kSpaceMd),

            // Media type selector
            _MediaTypeSelector(
              selected: state.mediaType,
              onChanged: ctrl.setMediaType,
            ),
            const SizedBox(height: kSpaceMd),

            // Photo picker
            _PhotoPicker(
              photo: state.photoFile,
              onPick: (file) => ctrl.setPhoto(file),
            ),
            const SizedBox(height: kSpaceLg),

            // Insufficient credits warning
            if (balanceAsync.hasValue && !canAfford) ...[
              _InsufficientCreditsWarning(theme: theme),
              const SizedBox(height: kSpaceMd),
            ],

            // Generic error
            if (state.errorMessage != null && !state.isInsufficientCredits) ...[
              _ErrorBanner(message: state.errorMessage!, theme: theme),
              const SizedBox(height: kSpaceMd),
            ],

            // Submit / insufficient-credits CTA
            if (!canAfford && balanceAsync.hasValue)
              OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Top Up Credits'),
              )
            else
              ElevatedButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => _submit(ctrl, state),
                child: state.isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Proceed to Payment'),
              ),

            const SizedBox(height: kSpaceLg),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(
    CreateOrderController ctrl,
    CreateOrderState state,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    if (state.eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event date')),
      );
      return;
    }
    await ctrl.submit(_template);
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({required this.template, required this.canAfford});
  final Template template;
  final bool canAfford;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(kSpaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(template.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(template.theme,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  )),
            ],
          ),
          Text(
            // priceDisplay comes from the model — client never computes price.
            template.priceDisplay,
            style: theme.textTheme.titleLarge?.copyWith(
              color: canAfford
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.selected, required this.onChanged});
  final DateTime? selected;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = selected == null
        ? 'Event Date *'
        : 'Event Date: ${_format(selected!)}';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selected ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          selected == null ? 'Tap to select date' : _format(selected!),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: selected == null ? theme.hintColor : null,
          ),
        ),
      ),
    );
  }

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _MediaTypeSelector extends StatelessWidget {
  const _MediaTypeSelector(
      {required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Format', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: kSpaceXs),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'image', label: Text('Image')),
            ButtonSegment(value: 'video', label: Text('Video')),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.onPick});
  final File? photo;
  final ValueChanged<File?> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo (optional)', style: theme.textTheme.labelLarge),
        const SizedBox(height: kSpaceXs),
        if (photo != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(photo!,
                height: 160, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: kSpaceXs),
          OutlinedButton.icon(
            onPressed: () => onPick(null),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove Photo'),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add Photo'),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked != null) onPick(File(picked.path));
  }
}

class _InsufficientCreditsWarning extends StatelessWidget {
  const _InsufficientCreditsWarning({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpaceSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: kSpaceXs),
          Expanded(
            child: Text(
              'Insufficient credits. Top up to create this design.',
              style: TextStyle(
                  color: theme.colorScheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.theme});
  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpaceSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}
