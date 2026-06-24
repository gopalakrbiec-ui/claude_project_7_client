import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../models/order.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final storage = ref.read(secureStorageProvider);
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
    required this.name,
    required this.eventDate,
    required this.theme,
    required this.language,
    required this.mediaType,
    this.photoFile,
    this.customerPhone,
  });

  final String templateId;
  final String idempotencyKey;
  final String name;
  final String eventDate; // ISO-8601 date string e.g. "2025-12-25"
  final String theme;
  final String language;
  final String mediaType; // "image" | "video"
  final File? photoFile;
  /// Agent-only: forwarded in input_payload.customer_phone.
  /// Backend infers the agent role from the JWT; this is purely metadata.
  final String? customerPhone;
}

class OrdersRepository {
  OrdersRepository(this._dio);
  final Dio _dio;

  Future<Order> createOrder(CreateOrderParams params) async {
    try {
      FormData? formData;
      if (params.photoFile != null) {
        formData = FormData.fromMap({
          'template_id': params.templateId,
          'idempotency_key': params.idempotencyKey,
          'input_payload[name]': params.name,
          'input_payload[event_date]': params.eventDate,
          'input_payload[theme]': params.theme,
          'input_payload[language]': params.language,
          'input_payload[media_type]': params.mediaType,
          'photo': await MultipartFile.fromFile(
            params.photoFile!.path,
            filename: 'photo.jpg',
          ),
        });
      }

      final response = await (formData != null
          ? _dio.post<Map<String, dynamic>>('/orders', data: formData)
          : _dio.post<Map<String, dynamic>>('/orders', data: {
              'template_id': params.templateId,
              'idempotency_key': params.idempotencyKey,
              'input_payload': {
                'name': params.name,
                'event_date': params.eventDate,
                'theme': params.theme,
                'language': params.language,
                'media_type': params.mediaType,
                if (params.customerPhone != null &&
                    params.customerPhone!.isNotEmpty)
                  'customer_phone': params.customerPhone,
              },
            }));

      return Order.fromJson(response.data!);
    } on DioException catch (e) {
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
