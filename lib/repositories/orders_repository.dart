import 'dart:developer' as dev;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';
import '../models/order.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return OrdersRepository(dio);
});

class CreateOrderParams {
  const CreateOrderParams({
    required this.templateId,
    required this.idempotencyKey,
    this.userPhotoKey,
    this.userPrompt,
    this.aspectRatio = '1:1',
    this.customerPhone,
  });

  final String templateId;
  final String idempotencyKey;
  final String? userPhotoKey;
  final String? userPrompt;
  final String aspectRatio;
  final String? customerPhone;
}

class OrdersRepository {
  OrdersRepository(this._dio);
  final Dio _dio;

  /// Uploads a user photo for face-swap generation.
  /// Returns the photo_key string to include in [createOrder].
  Future<String> uploadPhoto(File photo) async {
    dev.log('[OrdersRepo] POST /uploads/photo', name: 'order');
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          photo.path,
          filename: 'photo.jpg',
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/uploads/photo',
        data: formData,
      );
      dev.log('[OrdersRepo] upload response: ${response.data}', name: 'order');
      return response.data!['photo_key'] as String;
    } on DioException catch (e) {
      dev.log('[OrdersRepo] upload DioException: ${e.type} ${e.response?.statusCode}', name: 'order');
      throw DioClient.handleDioError(e);
    }
  }

  Future<Order> createOrder(CreateOrderParams params) async {
    dev.log('[OrdersRepo] POST /orders — templateId=${params.templateId} key=${params.idempotencyKey}', name: 'order');
    try {
      final response = await _dio.post<Map<String, dynamic>>('/orders', data: {
        'template_id': params.templateId,
        'idempotency_key': params.idempotencyKey,
        'input_payload': {
          if (params.userPhotoKey != null) 'user_photo_key': params.userPhotoKey,
          if (params.userPrompt != null && params.userPrompt!.isNotEmpty)
            'user_prompt': params.userPrompt,
          'aspect_ratio': params.aspectRatio,
          if (params.customerPhone != null && params.customerPhone!.isNotEmpty)
            'customer_phone': params.customerPhone,
        },
      });

      dev.log('[OrdersRepo] POST /orders response ${response.statusCode}: ${response.data}', name: 'order');
      return Order.fromJson(response.data!);
    } on DioException catch (e) {
      dev.log('[OrdersRepo] DioException: ${e.type} ${e.response?.statusCode} ${e.response?.data}', name: 'order');
      throw DioClient.handleDioError(e);
    }
  }

  Future<Order> getOrder(String orderId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/orders/$orderId');
      return Order.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// POST /orders/{id}/remove-watermark
  /// Backend debits credits and returns the clean (unwatermarked) URL.
  /// Throws ServerError(402) if the user has insufficient credits.
  Future<String> removeWatermark(String orderId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/orders/$orderId/remove-watermark',
      );
      return response.data!['clean_url'] as String;
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
