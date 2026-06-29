import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';

final toolsRepositoryProvider = Provider<ToolsRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return ToolsRepository(dio);
});

class ToolResult {
  const ToolResult({required this.resultUrl, required this.costPaise});
  final String resultUrl;
  final int costPaise;

  String get costDisplay {
    final r = costPaise / 100;
    return r == r.truncateToDouble() ? '₹${r.toInt()}' : '₹${r.toStringAsFixed(2)}';
  }

  factory ToolResult.fromJson(Map<String, dynamic> json) => ToolResult(
        resultUrl: json['result_url'] as String,
        costPaise: (json['cost_paise'] as num).toInt(),
      );
}

class ToolsRepository {
  ToolsRepository(this._dio);
  final Dio _dio;

  Future<ToolResult> faceSwap({
    required String sourcePhotoKey,
    required String targetImageUrl,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/tools/face-swap',
        data: {
          'source_photo_key': sourcePhotoKey,
          'target_image_url': targetImageUrl,
        },
      );
      return ToolResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  Future<ToolResult> restorePhoto(String photoKey) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/tools/restore',
        data: {'photo_key': photoKey},
      );
      return ToolResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  Future<ToolResult> removeBackground(String photoKey) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/tools/bg-remove',
        data: {'photo_key': photoKey},
      );
      return ToolResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  Future<ToolResult> upscale(String photoKey, {int scale = 4}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/tools/upscale',
        data: {'photo_key': photoKey, 'scale': scale},
      );
      return ToolResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
