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

/// Immediate response from POST /tools/{id} — job is queued.
class ToolJobResponse {
  const ToolJobResponse({required this.jobId, required this.costPaise});
  final String jobId;
  final int costPaise;

  factory ToolJobResponse.fromJson(Map<String, dynamic> json) => ToolJobResponse(
        jobId: json['job_id']?.toString() ?? '',
        costPaise: (json['cost_paise'] as num?)?.toInt() ?? 0,
      );
}

/// Polled status from GET /tools/status/{job_id}.
class ToolJobStatus {
  const ToolJobStatus({
    required this.jobId,
    required this.status,
    this.resultUrl,
    this.error,
    required this.costPaise,
  });

  final String jobId;
  final String status; // "processing" | "done" | "failed"
  final String? resultUrl;
  final String? error;
  final int costPaise;

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';

  String get costDisplay => AiToolDef._formatPaise(costPaise);

  factory ToolJobStatus.fromJson(Map<String, dynamic> json) => ToolJobStatus(
        jobId: json['job_id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'processing',
        resultUrl: json['result_url']?.toString(),
        error: json['error']?.toString(),
        costPaise: (json['cost_paise'] as num?)?.toInt() ?? 0,
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

  /// Submit a tool job. Returns immediately with a job_id; poll [getToolStatus].
  Future<ToolJobResponse> runTool(
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
      return ToolJobResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// Poll job status. Returns "processing" | "done" | "failed".
  Future<ToolJobStatus> getToolStatus(String jobId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/tools/status/$jobId');
      return ToolJobStatus.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
