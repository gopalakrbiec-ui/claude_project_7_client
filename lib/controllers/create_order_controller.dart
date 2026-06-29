import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../api/api_error.dart';
import '../models/order.dart';
import '../repositories/orders_repository.dart';

// ---------------------------------------------------------------------------
// UUID provider — injectable so tests can supply a deterministic value.
// ---------------------------------------------------------------------------
final uuidProvider = Provider<Uuid>((_) => const Uuid());

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum CreateOrderStatus { idle, uploadingPhoto, submitting, success, error }

class CreateOrderState {
  const CreateOrderState({
    required this.idempotencyKey,
    this.userPhotoFile,
    this.userPhotoKey,
    this.userPrompt = '',
    this.aspectRatio = '1:1',
    this.customerPhone,
    this.status = CreateOrderStatus.idle,
    this.errorMessage,
    this.createdOrder,
    this.isInsufficientCredits = false,
  });

  final String idempotencyKey;
  /// Local file selected from camera/gallery.
  final File? userPhotoFile;
  /// Server-side key returned after upload. Sent with createOrder.
  final String? userPhotoKey;
  final String userPrompt;
  /// '1:1' | '9:16' | '16:9' | '4:3'
  final String aspectRatio;
  /// Agent-only: forwarded in input_payload.customer_phone.
  final String? customerPhone;
  final CreateOrderStatus status;
  final String? errorMessage;
  final Order? createdOrder;
  final bool isInsufficientCredits;

  bool get isUploadingPhoto => status == CreateOrderStatus.uploadingPhoto;
  bool get isSubmitting => status == CreateOrderStatus.submitting;
  bool get isBusy => isUploadingPhoto || isSubmitting;
  bool get isSuccess => status == CreateOrderStatus.success;

  CreateOrderState copyWith({
    String? idempotencyKey,
    File? userPhotoFile,
    bool clearPhoto = false,
    String? userPhotoKey,
    bool clearPhotoKey = false,
    String? userPrompt,
    String? aspectRatio,
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
      userPhotoFile: clearPhoto ? null : (userPhotoFile ?? this.userPhotoFile),
      userPhotoKey: clearPhotoKey ? null : (userPhotoKey ?? this.userPhotoKey),
      userPrompt: userPrompt ?? this.userPrompt,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      customerPhone:
          clearCustomerPhone ? null : (customerPhone ?? this.customerPhone),
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
// ---------------------------------------------------------------------------
final createOrderControllerProvider = NotifierProvider.family<
    CreateOrderController, CreateOrderState, String>(
  CreateOrderController.new,
);

class CreateOrderController
    extends FamilyNotifier<CreateOrderState, String> {
  @override
  CreateOrderState build(String templateId) {
    final key = ref.read(uuidProvider).v4();
    return CreateOrderState(idempotencyKey: key);
  }

  // -- Field setters --------------------------------------------------------

  void setPrompt(String value) =>
      state = state.copyWith(userPrompt: value, clearError: true);

  void setAspectRatio(String value) =>
      state = state.copyWith(aspectRatio: value);

  void setCustomerPhone(String value) => state = state.copyWith(
      customerPhone: value.trim().isEmpty ? null : value.trim());

  // -- Photo handling -------------------------------------------------------

  /// Picks a photo file and immediately uploads it to the server.
  /// Sets userPhotoFile for local preview; sets userPhotoKey on success.
  Future<void> pickAndUploadPhoto(File file) async {
    state = state.copyWith(
      userPhotoFile: file,
      clearPhotoKey: true,
      status: CreateOrderStatus.uploadingPhoto,
      clearError: true,
    );
    try {
      final key =
          await ref.read(ordersRepositoryProvider).uploadPhoto(file);
      state = state.copyWith(
        userPhotoKey: key,
        status: CreateOrderStatus.idle,
      );
    } on ApiError catch (e) {
      dev.log('[CreateOrder] photo upload error: $e', name: 'order');
      state = state.copyWith(
        clearPhoto: true,
        clearPhotoKey: true,
        status: CreateOrderStatus.error,
        errorMessage: 'Photo upload failed. Please try again.',
      );
    } catch (e) {
      state = state.copyWith(
        clearPhoto: true,
        clearPhotoKey: true,
        status: CreateOrderStatus.error,
        errorMessage: 'Photo upload failed: $e',
      );
    }
  }

  void clearPhoto() =>
      state = state.copyWith(clearPhoto: true, clearPhotoKey: true, clearError: true);

  // -- Submit ---------------------------------------------------------------

  Future<void> submit(String templateId) async {
    if (state.isBusy) return;

    final key = state.idempotencyKey;
    dev.log('[CreateOrder] submit start — template=$templateId key=$key', name: 'order');

    state = state.copyWith(
      status: CreateOrderStatus.submitting,
      clearError: true,
      isInsufficientCredits: false,
    );

    try {
      final order = await ref.read(ordersRepositoryProvider).createOrder(
            CreateOrderParams(
              templateId: templateId,
              idempotencyKey: key,
              userPhotoKey: state.userPhotoKey,
              userPrompt: state.userPrompt.trim().isEmpty
                  ? null
                  : state.userPrompt.trim(),
              aspectRatio: state.aspectRatio,
              customerPhone: state.customerPhone,
            ),
          );
      dev.log('[CreateOrder] success — orderId=${order.id}', name: 'order');
      state = state.copyWith(
        status: CreateOrderStatus.success,
        createdOrder: order,
      );
    } on InsufficientCreditsError catch (_) {
      dev.log('[CreateOrder] InsufficientCreditsError', name: 'order');
      state = state.copyWith(
        status: CreateOrderStatus.error,
        isInsufficientCredits: true,
      );
    } on ServerError catch (e) {
      dev.log('[CreateOrder] ServerError ${e.statusCode}: ${e.message}', name: 'order');
      state = state.copyWith(
        status: CreateOrderStatus.error,
        errorMessage: e.message,
      );
    } on NetworkError {
      dev.log('[CreateOrder] NetworkError', name: 'order');
      state = state.copyWith(
        status: CreateOrderStatus.error,
        errorMessage: 'No internet connection. Please retry.',
      );
    } on ApiError catch (e) {
      dev.log('[CreateOrder] ApiError: $e', name: 'order');
      state = state.copyWith(
        status: CreateOrderStatus.error,
        errorMessage: e.toString(),
      );
    } catch (e, st) {
      dev.log('[CreateOrder] unexpected error: $e\n$st', name: 'order', error: e);
      state = state.copyWith(
        status: CreateOrderStatus.error,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  void resetError() =>
      state = state.copyWith(status: CreateOrderStatus.idle, clearError: true);

  void startNewOrder() {
    final newKey = ref.read(uuidProvider).v4();
    state = CreateOrderState(idempotencyKey: newKey);
  }
}
