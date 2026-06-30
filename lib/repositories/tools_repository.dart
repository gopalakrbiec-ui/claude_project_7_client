import 'dart:io';
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

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class AiToolDef {
  const AiToolDef({
    required this.id,
    required this.name,
    required this.provider,
    required this.costPaise,
    required this.costDisplay,
    required this.needsPhoto,
    required this.needsPrompt,
    required this.needsTargetPhoto,
  });

  final String id;
  final String name;
  final String provider;
  final int costPaise;
  final String costDisplay;
  final bool needsPhoto;
  final bool needsPrompt;
  final bool needsTargetPhoto;

  factory AiToolDef.fromJson(Map<String, dynamic> json) => AiToolDef(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        provider: json['provider']?.toString() ?? '',
        costPaise: (json['cost_paise'] as num?)?.toInt() ?? 0,
        costDisplay: json['cost_display']?.toString() ??
            _formatPaise((json['cost_paise'] as num?)?.toInt() ?? 0),
        needsPhoto: json['needs_photo'] as bool? ?? true,
        needsPrompt: json['needs_prompt'] as bool? ?? false,
        needsTargetPhoto: json['needs_target_photo'] as bool? ?? false,
      );

  static String _formatPaise(int paise) {
    final r = paise / 100;
    return r == r.truncateToDouble() ? '₹${r.toInt()}' : '₹${r.toStringAsFixed(2)}';
  }
}

class ToolResult {
  const ToolResult({required this.resultUrl, required this.costDisplay});
  final String resultUrl;
  final String costDisplay;

  factory ToolResult.fromJson(Map<String, dynamic> json) => ToolResult(
        resultUrl: json['result_url']?.toString() ?? '',
        costDisplay: json['cost_display']?.toString() ??
            AiToolDef._formatPaise((json['cost_paise'] as num?)?.toInt() ?? 0),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class ToolsRepository {
  ToolsRepository(this._dio);
  final Dio _dio;

  Future<List<AiToolDef>> getTools() async {
    try {
      final response = await _dio.get<dynamic>('/tools');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(AiToolDef.fromJson)
            .toList();
      }
      if (data is Map && data['tools'] is List) {
        return (data['tools'] as List)
            .whereType<Map<String, dynamic>>()
            .map(AiToolDef.fromJson)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// Upload a photo and return the server-side key.
  Future<String> uploadPhoto(File photo) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(photo.path, filename: 'photo.jpg'),
      });
      final response =
          await _dio.post<Map<String, dynamic>>('/uploads/photo', data: formData);
      return response.data!['photo_key'] as String;
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// Run a tool. [extraFields] lets callers send tool-specific named params
  /// (e.g. hair_colour for Hair Salon) without hard-coding them here.
  Future<ToolResult> runTool(
    String toolId, {
    String? photoKey,
    String? targetPhotoKey,
    Map<String, String>? extraFields,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (photoKey != null) body['photo_key'] = photoKey;
      if (targetPhotoKey != null) body['target_photo_key'] = targetPhotoKey;
      if (extraFields != null) {
        for (final e in extraFields.entries) {
          if (e.value.isNotEmpty) body[e.key] = e.value;
        }
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/tools/$toolId',
        data: body,
      );
      return ToolResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
