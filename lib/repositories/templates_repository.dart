import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';
import '../core/constants.dart';
import '../models/template.dart';

// ---------------------------------------------------------------------------
// In-memory TTL cache
// ---------------------------------------------------------------------------
class _CacheEntry {
  _CacheEntry(this.data) : cachedAt = DateTime.now();
  final List<Template> data;
  final DateTime cachedAt;

  bool get isStale =>
      DateTime.now().difference(cachedAt) > kTemplateCacheTtl;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return TemplatesRepository(dio);
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------
class TemplatesRepository {
  TemplatesRepository(this._dio);
  final Dio _dio;

  // Keyed by optional theme filter — language is no longer sent to the API.
  final _cache = <String?, _CacheEntry>{};

  /// Fetches all templates, optionally filtered by [theme].
  /// Returns cached data if fresh; set [bypassCache] to force a network call.
  Future<List<Template>> getTemplates({
    String? theme,
    bool bypassCache = false,
  }) async {
    final cached = _cache[theme];

    if (!bypassCache && cached != null && !cached.isStale) {
      return cached.data;
    }

    try {
      final params = <String, String>{};
      if (theme != null) params['theme'] = theme;

      final response = await _dio.get<List<dynamic>>(
        '/templates',
        queryParameters: params.isEmpty ? null : params,
      );

      final templates = (response.data ?? [])
          .map((e) => Template.fromJson(e as Map<String, dynamic>))
          .toList();

      _cache[theme] = _CacheEntry(templates);
      return templates;
    } on DioException catch (e) {
      // On network error, return stale cache rather than showing an error.
      if (cached != null) return cached.data;
      throw DioClient.handleDioError(e);
    }
  }

  /// Returns a single template from cache, or null if not cached.
  Template? getCached(String id) {
    for (final entry in _cache.values) {
      final match = entry.data.where((t) => t.id == id);
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }

  void invalidateAll() => _cache.clear();
}
