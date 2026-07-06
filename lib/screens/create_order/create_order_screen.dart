import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/background_orders_controller.dart';
import '../../controllers/create_order_controller.dart';
import '../../controllers/credits_controller.dart';
import '../../controllers/templates_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/template.dart';
import '../../repositories/templates_repository.dart';
import '../../widgets/error_view.dart';
import '../../api/api_error.dart';
import '../../widgets/insufficient_credits_dialog.dart';

// ---------------------------------------------------------------------------
// Entry — resolves template then delegates to content widget
// ---------------------------------------------------------------------------
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
    final template =
        preloaded ?? ref.read(templatesRepositoryProvider).getCached(templateId);

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
  late final TextEditingController _promptController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _phoneController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(createOrderControllerProvider(widget.template.id));
      if (s.isSuccess) {
        ref
            .read(createOrderControllerProvider(widget.template.id).notifier)
            .startNewOrder();
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Template get _template => widget.template;

  @override
  Widget build(BuildContext context) {
    final ctrl = ref
        .read(createOrderControllerProvider(widget.template.id).notifier);
    final state = ref.watch(createOrderControllerProvider(widget.template.id));
    final balanceAsync = ref.watch(creditsControllerProvider);
    final canAfford =
        balanceAsync.valueOrNull?.canAfford(_template.basePricePaise) ?? true;
    final isAgent = ref.watch(isAgentProvider);
    final theme = Theme.of(context);

    ref.listen(createOrderControllerProvider(widget.template.id), (prev, next) {
      if (next.isSuccess && next.createdOrder != null) {
        final orderId = next.createdOrder!.id;
        ref.read(backgroundOrdersProvider.notifier).trackOrder(orderId);
        context.go('/home/order-status/$orderId');
      }
      // Show the rich Top Up dialog on 402 instead of a plain banner.
      if (next.isInsufficientCredits &&
          prev?.isInsufficientCredits != true) {
        InsufficientCreditsDialog.show(
          context,
          const InsufficientCreditsError(availablePaise: 0, requiredPaise: 0),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar with template preview ──────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: kSaffron,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _template.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_template.previewUrl != null)
                    CachedNetworkImage(
                      imageUrl: _template.previewUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) =>
                          Container(color: Colors.grey.shade300),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(gradient: kBrandGradient),
                    ),
                  // Dark scrim so title is legible
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(kSpaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Price row ───────────────────────────────────────────
                  _PriceRow(template: _template, canAfford: canAfford),
                  const SizedBox(height: kSpaceLg),

                  // ── Photos (1 mandatory, up to 4) ───────────────────────
                  _SectionLabel(
                    icon: Icons.face_retouching_natural,
                    label: 'Your Photo(s)',
                    required: true,
                  ),
                  const SizedBox(height: kSpaceXs),
                  Text(
                    state.filledCount == 0
                        ? 'Add at least 1 photo'
                        : '${state.filledCount} photo${state.filledCount > 1 ? 's' : ''} selected · up to 4',
                    style: TextStyle(
                      fontSize: 12,
                      color: state.filledCount == 0
                          ? Theme.of(context).colorScheme.error
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: kSpaceSm),
                  _MultiPhotoGrid(
                    slots: state.photoSlots,
                    canAddSlot: state.canAddSlot,
                    onPick: (index, file) => ctrl.pickAndUploadPhoto(index, file),
                    onRemove: ctrl.removePhoto,
                    onAddSlot: ctrl.addPhotoSlot,
                  ),
                  const SizedBox(height: kSpaceLg),

                  // ── Prompt ──────────────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.edit_note,
                    label: 'Add Details (optional)',
                    required: false,
                  ),
                  const SizedBox(height: kSpaceSm),
                  TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. Wedding on 25 Dec, add roses, blue background…',
                      filled: true,
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: ctrl.setPrompt,
                  ),
                  const SizedBox(height: kSpaceLg),

                  // ── Aspect ratio ────────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.crop,
                    label: 'Aspect Ratio',
                    required: false,
                  ),
                  const SizedBox(height: kSpaceSm),
                  _AspectRatioSelector(
                    selected: state.aspectRatio,
                    onChanged: ctrl.setAspectRatio,
                  ),
                  const SizedBox(height: kSpaceLg),

                  // ── Agent: customer phone ───────────────────────────────
                  if (isAgent) ...[
                    _SectionLabel(
                      icon: Icons.phone_outlined,
                      label: 'Customer Phone (optional)',
                      required: false,
                    ),
                    const SizedBox(height: kSpaceSm),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: '+91 98765 43210',
                        filled: true,
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: ctrl.setCustomerPhone,
                    ),
                    const SizedBox(height: kSpaceLg),
                  ],

                  // ── Insufficient credits ────────────────────────────────
                  if (balanceAsync.hasValue && !canAfford) ...[
                    _Banner(
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                      icon: Icons.info_outline,
                      message:
                          'Insufficient credits. Top up to create this poster.',
                    ),
                    const SizedBox(height: kSpaceMd),
                  ],

                  // ── Error ───────────────────────────────────────────────
                  if (state.errorMessage != null &&
                      !state.isInsufficientCredits) ...[
                    _Banner(
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                      icon: Icons.error_outline,
                      message: state.errorMessage!,
                    ),
                    const SizedBox(height: kSpaceMd),
                  ],

                  // ── Generate button ─────────────────────────────────────
                  _GenerateButton(
                    state: state,
                    onTap: () => ctrl.submit(_template.id),
                  ),

                  if (!canAfford && balanceAsync.hasValue) ...[
                    const SizedBox(height: kSpaceSm),
                    OutlinedButton(
                      onPressed: () => context.push('/home/topup'),
                      child: const Text('Top Up Credits'),
                    ),
                  ],

                  const SizedBox(height: kSpaceXl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.required,
  });
  final IconData icon;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: kSaffron),
        const SizedBox(width: kSpaceXs),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: const Color(0xFF1A1A1A),
          ),
        ),
        if (required) ...[
          const SizedBox(width: 2),
          Text('*', style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.template, required this.canAfford});
  final Template template;
  final bool canAfford;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd, vertical: kSpaceSm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Price', style: theme.textTheme.bodyMedium),
          Text(
            template.priceDisplay,
            style: theme.textTheme.titleMedium?.copyWith(
              color: canAfford ? kSaffron : theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-photo grid — 1 mandatory slot, up to 4
// ---------------------------------------------------------------------------
class _MultiPhotoGrid extends StatelessWidget {
  const _MultiPhotoGrid({
    required this.slots,
    required this.canAddSlot,
    required this.onPick,
    required this.onRemove,
    required this.onAddSlot,
  });

  final List<PhotoSlot> slots;
  final bool canAddSlot;
  final void Function(int index, File file) onPick;
  final void Function(int index) onRemove;
  final VoidCallback onAddSlot;

  @override
  Widget build(BuildContext context) {
    final slotSize =
        (MediaQuery.sizeOf(context).width - kSpaceMd * 2 - 10) / 2;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < slots.length; i++)
          _PhotoSlotTile(
            slot: slots[i],
            index: i,
            size: slotSize,
            onPick: (file) => onPick(i, file),
            onRemove: () => onRemove(i),
          ),
        if (canAddSlot)
          _AddSlotTile(size: slotSize, onTap: onAddSlot),
      ],
    );
  }
}

class _PhotoSlotTile extends StatelessWidget {
  const _PhotoSlotTile({
    required this.slot,
    required this.index,
    required this.size,
    required this.onPick,
    required this.onRemove,
  });

  final PhotoSlot slot;
  final int index;
  final double size;
  final void Function(File) onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (slot.file != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                slot.file!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
            if (slot.uploading)
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                ),
              )
            else ...[
              if (slot.isReady)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 11),
                        SizedBox(width: 3),
                        Text('Ready',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Photo ${index + 1}',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Empty slot — tap to pick
    return GestureDetector(
      onTap: () => _showSourceSheet(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: index == 0
                ? kSaffron.withValues(alpha: 0.8)
                : const Color(0xFFDDDDDD),
            width: index == 0 ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: index == 0 ? kBrandGradient : null,
                color: index == 0 ? null : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_a_photo,
                color: index == 0 ? Colors.white : Colors.grey.shade500,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              index == 0 ? 'Add Photo *' : 'Photo ${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: index == 0 ? kSaffron : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpaceSm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: kSpaceMd),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: kSaffron),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: kSaffron),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: kSpaceSm),
            ],
          ),
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked != null) onPick(File(picked.path));
  }
}

class _AddSlotTile extends StatelessWidget {
  const _AddSlotTile({required this.size, required this.onTap});
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kSaffron.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 32, color: kSaffron.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text(
              'Add Photo',
              style: TextStyle(
                  color: kSaffron.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _AspectRatioSelector extends StatelessWidget {
  const _AspectRatioSelector(
      {required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('1:1', Icons.crop_square, 'Square'),
    ('9:16', Icons.crop_portrait, 'Story'),
    ('16:9', Icons.crop_landscape, 'Wide'),
    ('4:3', Icons.crop_3_2, 'Standard'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final (value, icon, label) = opt;
        final isSelected = selected == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: kSpaceXs),
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: kSpaceSm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kSaffron.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? kSaffron : const Color(0xFFDDDDDD),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon,
                        size: 22,
                        color: isSelected ? kSaffron : Colors.grey.shade500),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            isSelected ? kSaffron : const Color(0xFF555555),
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.state, required this.onTap});
  final CreateOrderState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final noPhoto = state.filledCount == 0;
    final showSpinner = state.isBusy;
    final disabled = noPhoto || state.isBusy;
    final label = state.isAnyUploading
        ? 'Uploading photo…'
        : state.isSubmitting
            ? 'Generating…'
            : noPhoto
                ? 'Add at least 1 photo'
                : 'Generate Poster';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: disabled ? null : kBrandGradient,
        color: disabled ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: showSpinner
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: kSpaceSm),
                      Text(label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          )),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          color: disabled ? Colors.grey.shade600 : Colors.white,
                          size: 20),
                      const SizedBox(width: kSpaceSm),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: disabled ? 15 : 18,
                          fontWeight: FontWeight.w700,
                          color: disabled ? Colors.grey.shade600 : Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.message,
  });
  final Color color;
  final Color textColor;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpaceSm),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: kSpaceXs),
          Expanded(
            child: Text(message,
                style: TextStyle(color: textColor, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
