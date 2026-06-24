import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../api/api_error.dart';
import '../controllers/locale_controller.dart';
import '../core/image_compress.dart';
import '../models/order.dart';
import '../models/template.dart';
import '../repositories/orders_repository.dart';

// ---------------------------------------------------------------------------
// UUID provider — injectable so tests can supply a deterministic value.
// ---------------------------------------------------------------------------
final uuidProvider = Provider<Uuid>((_) => const Uuid());

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum CreateOrderStatus { idle, submitting, success, error }

class CreateOrderState {
  const CreateOrderState({
    required this.idempotencyKey,
    this.name = '',
    this.eventDate,
    this.mediaType = 'image',
    this.photoFile,
    this.customerPhone,
    this.status = CreateOrderStatus.idle,
    this.errorMessage,
    this.createdOrder,
    this.isInsufficientCredits = false,
  });

  final String idempotencyKey;
  final String name;
  final DateTime? eventDate;
  final String mediaType;
  final File? photoFile;
  /// Agent-only: the customer's phone number, sent in input_payload.
  /// Null (and hidden from the form) for consumer accounts.
  final String? customerPhone;
  final CreateOrderStatus status;
  final String? errorMessage;
  final Order? createdOrder;
  final bool isInsufficientCredits;

  bool get isSubmitting => status == CreateOrderStatus.submitting;
  bool get isSuccess => status == CreateOrderStatus.success;

  CreateOrderState copyWith({
    String? idempotencyKey,
    String? name,
    DateTime? eventDate,
    bool clearEventDate = false,
    String? mediaType,
    File? photoFile,
    bool clearPhoto = false,
    String? customerPhone,
    bool clearCustomerPhone = false,
    CreateOrderStatus? status,
    String? errorMessage,
    bool clearError = false,
    Order? createdOrder,
    bool? isInsufficientCredits,
  }) {
    return CreateOrderState(
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      name: name ?? this.name,
      eventDate: clearEventDate ? null : (eventDate ?? this.eventDate),
      mediaType: mediaType ?? this.mediaType,
      photoFile: clearPhoto ? null : (photoFile ?? this.photoFile),
      customerPhone: clearCustomerPhone
          ? null
          : (customerPhone ?? this.customerPhone),
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdOrder: createdOrder ?? this.createdOrder,
      isInsufficientCredits:
          isInsufficientCredits ?? this.isInsufficientCredits,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller (family-keyed by templateId)
// ---------------------------------------------------------------------------
// IDEMPOTENCY: The UUID is generated ONCE in build() and stored in state.
// submit() sends state.idempotencyKey on every attempt — same key on retries.
// A new controller instance (new templateId) gets a fresh key automatically.
// ---------------------------------------------------------------------------
final createOrderControllerProvider = NotifierProvider.family<
    CreateOrderController, CreateOrderState, String>(
  CreateOrderController.new,
);

class CreateOrderController
    extends FamilyNotifier<CreateOrderState, String> {
  @override
  CreateOrderState build(String templateId) {
    // Key is generated exactly once here — never inside submit().
    final key = ref.read(uuidProvider).v4();
    return CreateOrderState(idempotencyKey: key);
  }

  // -- Field setters --------------------------------------------------------

  void setName(String value) =>
      state = state.copyWith(name: value, clearError: true);

  void setEventDate(DateTime? value) =>
      state = value == null
          ? state.copyWith(clearEventDate: true)
          : state.copyWith(eventDate: value);

  void setMediaType(String value) =>
      state = state.copyWith(mediaType: value);

  void setPhoto(File? file) =>
      state = file == null
          ? state.copyWith(clearPhoto: true)
          : state.copyWith(photoFile: file);

  void setCustomerPhone(String value) => state = state.copyWith(
      customerPhone: value.trim().isEmpty ? null : value.trim());

  // -- Submit ---------------------------------------------------------------

  Future<void> submit(Template template) async {
    if (state.isSubmitting) return;

    final language =
        ref.read(localeControllerProvider).valueOrNull?.languageCode ?? 'en';

    File? compressedPhoto;
    if (state.photoFile != null) {
      compressedPhoto = await ref
          .read(imageCompressorProvider)
          .compress(state.photoFile!);
    }

    state = state.copyWith(
      status: CreateOrderStatus.submitting,
      clearError: true,
      isInsufficientCredits: false,
    );

    try {
      final order = await ref.read(ordersRepositoryProvider).createOrder(
            CreateOrderParams(
              templateId: template.id,
              idempotencyKey: state.idempotencyKey, // REUSED on retry
              name: state.name.trim(),
              eventDate: _formatDate(state.eventDate),
              theme: template.theme,
              language: language,
              mediaType: state.mediaType,
              photoFile: compressedPhoto,
              customerPhone: state.customerPhone,
            ),
          );

      state = state.copyWith(
        status: CreateOrderStatus.success,
        createdOrder: order,
      );
    } on ServerError catch (e) {
      if (e.isInsufficientCredits) {
        state = state.copyWith(
          status: CreateOrderStatus.error,
          isInsufficientCredits: true,
        );
      } else {
        state = state.copyWith(
          status: CreateOrderStatus.error,
          errorMessage: e.message,
        );
      }
    } on NetworkError {
      state = state.copyWith(
        status: CreateOrderStatus.error,
        errorMessage: 'No internet connection. Please retry.',
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        status: CreateOrderStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Resets to idle so the user can fix the form and retry.
  /// The idempotency key is PRESERVED — same attempt.
  void resetError() =>
      state = state.copyWith(status: CreateOrderStatus.idle, clearError: true);

  /// Called when user consciously starts a new order (e.g. after success).
  /// Generates a fresh idempotency key.
  void startNewOrder() {
    final newKey = ref.read(uuidProvider).v4();
    state = CreateOrderState(idempotencyKey: newKey);
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
