import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final inspireRepositoryProvider = Provider<InspireRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return InspireRepository(dio);
});

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------
class InspirePhoto {
  const InspirePhoto({
    required this.id,
    required this.type,
    required this.thumbUrl,
    required this.previewUrl,
    required this.fullUrl,
    required this.author,
    required this.source,
  });

  final String id;
  final String type;
  final String thumbUrl;
  final String previewUrl;
  final String fullUrl;
  final String author;
  final String source;

  factory InspirePhoto.fromJson(Map<String, dynamic> json) => InspirePhoto(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'photo',
        thumbUrl: json['thumb_url']?.toString() ?? '',
        previewUrl: json['preview_url']?.toString() ?? '',
        fullUrl: json['full_url']?.toString() ?? '',
        author: json['author']?.toString() ?? '',
        source: json['source']?.toString() ?? '',
      );
}

class InspireResult {
  const InspireResult({
    required this.photos,
    required this.hasMore,
    required this.page,
  });

  final List<InspirePhoto> photos;
  final bool hasMore;
  final int page;
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------
class InspireRepository {
  InspireRepository(this._dio);
  final Dio _dio;

  Future<List<String>> getKeywords() async {
    try {
      final response = await _dio.get<dynamic>('/inspire/keywords');
      final data = response.data;
      if (data is Map && data['keywords'] is List) {
        return (data['keywords'] as List).map((e) => e.toString()).toList();
      }
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }
      return [];
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  Future<InspireResult> search({String query = '', int page = 1}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/inspire',
        queryParameters: {
          if (query.isNotEmpty) 'q': query,
          'page': page,
        },
      );
      final data = response.data;
      final List<dynamic> rawList =
          (data is Map ? data['results'] : data) as List<dynamic>? ?? [];
      final photos =
          rawList.map((e) => InspirePhoto.fromJson(e as Map<String, dynamic>)).toList();
      final hasMore = data is Map
          ? (data['has_more'] as bool? ?? photos.length >= 20)
          : photos.length >= 20;
      return InspireResult(photos: photos, hasMore: hasMore, page: page);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
