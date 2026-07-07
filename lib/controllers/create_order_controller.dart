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
// Photo slot — one entry in the multi-photo list
// ---------------------------------------------------------------------------
const _kMaxPhotos = 4;

class PhotoSlot {
  const PhotoSlot({this.file, this.key, this.uploading = false});
  final File? file;
  final String? key;
  final bool uploading;

  bool get isEmpty => file == null;
  bool get isReady => key != null;

  PhotoSlot copyWith({File? file, String? key, bool? uploading, bool clear = false}) {
    return PhotoSlot(
      file: clear ? null : (file ?? this.file),
      key: clear ? null : (key ?? this.key),
      uploading: uploading ?? this.uploading,
    );
  }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum CreateOrderStatus { idle, submitting, success, error }

class CreateOrderState {
  const CreateOrderState({
    required this.idempotencyKey,
    List<PhotoSlot>? photoSlots,
    this.userPrompt = '',
    this.aspectRatio = '1:1',
    this.customerPhone,
    this.status = CreateOrderStatus.idle,
    this.errorMessage,
    this.createdOrder,
    this.isInsufficientCredits = false,
    Set<String>? selectedTags,
  })  : photoSlots = photoSlots ?? const [PhotoSlot()],
        selectedTags = selectedTags ?? const {};

  final String idempotencyKey;
  /// 1–4 photo slots; always has at least one entry.
  final List<PhotoSlot> photoSlots;
  final String userPrompt;
  /// '1:1' | '9:16' | '16:9' | '4:3'
  final String aspectRatio;
  /// Agent-only: forwarded in input_payload.customer_phone.
  final String? customerPhone;
  final CreateOrderStatus status;
  final String? errorMessage;
  final Order? createdOrder;
  final bool isInsufficientCredits;
  /// Namespaced keyword tag keys, e.g. "location:beach".
  final Set<String> selectedTags;

  bool get isAnyUploading => photoSlots.any((s) => s.uploading);
  bool get isSubmitting => status == CreateOrderStatus.submitting;
  bool get isBusy => isAnyUploading || isSubmitting;
  bool get isSuccess => status == CreateOrderStatus.success;

  int get filledCount => photoSlots.where((s) => !s.isEmpty).length;
  bool get canAddSlot => photoSlots.length < _kMaxPhotos;

  /// All filled slots have been uploaded (have a key).
  bool get allPhotosReady =>
      photoSlots.where((s) => !s.isEmpty).every((s) => s.isReady);

  List<String> get uploadedKeys =>
      photoSlots.where((s) => s.isReady).map((s) => s.key!).toList();

  // Legacy compat — used by _GenerateButton label
  bool get isUploadingPhoto => isAnyUploading;

  CreateOrderState copyWith({
    String? idempotencyKey,
    List<PhotoSlot>? photoSlots,
    String? userPrompt,
    String? aspectRatio,
    String? customerPhone,
    bool clearCustomerPhone = false,
    CreateOrderStatus? status,
    String? errorMessage,
    bool clearError = false,
    Order? createdOrder,
    bool? isInsufficientCredits,
    Set<String>? selectedTags,
  }) {
    return CreateOrderState(
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      photoSlots: photoSlots ?? this.photoSlots,
      userPrompt: userPrompt ?? this.userPrompt,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      customerPhone:
          clearCustomerPhone ? null : (customerPhone ?? this.customerPhone),
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdOrder: createdOrder ?? this.createdOrder,
      isInsufficientCredits:
          isInsufficientCredits ?? this.isInsufficientCredits,
      selectedTags: selectedTags ?? this.selectedTags,
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

  void toggleTag(String tagKey) {
    final tags = Set<String>.from(state.selectedTags);
    if (tags.contains(tagKey)) {
      tags.remove(tagKey);
    } else {
      tags.add(tagKey);
    }
    state = state.copyWith(selectedTags: tags);
  }

  void setAspectRatio(String value) =>
      state = state.copyWith(aspectRatio: value);

  void setCustomerPhone(String value) => state = state.copyWith(
      customerPhone: value.trim().isEmpty ? null : value.trim());

  // -- Photo handling -------------------------------------------------------

  List<PhotoSlot> _updateSlot(int index, PhotoSlot updated) {
    final slots = List<PhotoSlot>.from(state.photoSlots);
    slots[index] = updated;
    return slots;
  }

  /// Upload photo at [index]. Adds a new slot if [index] == slots.length.
  Future<void> pickAndUploadPhoto(int index, File file) async {
    final slots = List<PhotoSlot>.from(state.photoSlots);
    if (index == slots.length && slots.length < _kMaxPhotos) {
      slots.add(PhotoSlot(file: file, uploading: true));
    } else {
      slots[index] = PhotoSlot(file: file, uploading: true);
    }
    state = state.copyWith(photoSlots: slots, clearError: true);

    try {
      final key = await ref.read(ordersRepositoryProvider).uploadPhoto(file);
      state = state.copyWith(
        photoSlots: _updateSlot(
          index < state.photoSlots.length ? index : state.photoSlots.length - 1,
          PhotoSlot(file: file, key: key),
        ),
      );
    } on ApiError catch (e) {
      dev.log('[CreateOrder] photo upload error: $e', name: 'order');
      _clearSlot(index, error: 'Photo upload failed. Please try again.');
    } catch (e) {
      _clearSlot(index, error: 'Photo upload failed: $e');
    }
  }

  void _clearSlot(int index, {String? error}) {
    final slots = List<PhotoSlot>.from(state.photoSlots);
    if (index < slots.length) {
      slots[index] = const PhotoSlot();
      // Remove trailing empty slots beyond slot 0
      while (slots.length > 1 && slots.last.isEmpty) {
        slots.removeLast();
      }
    }
    state = state.copyWith(
      photoSlots: slots,
      status: error != null ? CreateOrderStatus.error : null,
      errorMessage: error,
    );
  }

  void removePhoto(int index) {
    final slots = List<PhotoSlot>.from(state.photoSlots);
    slots.removeAt(index);
    if (slots.isEmpty) slots.add(const PhotoSlot());
    state = state.copyWith(photoSlots: slots, clearError: true);
  }

  void addPhotoSlot() {
    if (!state.canAddSlot) return;
    final slots = List<PhotoSlot>.from(state.photoSlots)..add(const PhotoSlot());
    state = state.copyWith(photoSlots: slots);
  }

  // Legacy single-photo compat — kept so existing callers compile
  Future<void> pickAndUploadPhoto0(File file) => pickAndUploadPhoto(0, file);
  void clearPhoto() => _clearSlot(0);

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
              userPhotoKeys: state.uploadedKeys,
              userPrompt: state.userPrompt.trim().isEmpty
                  ? null
                  : state.userPrompt.trim(),
              aspectRatio: state.aspectRatio,
              customerPhone: state.customerPhone,
              keywordTags: state.selectedTags.toList(),
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
    state = CreateOrderState(
      idempotencyKey: newKey,
      photoSlots: const [PhotoSlot()],
      selectedTags: const {},
    );
  }
}
