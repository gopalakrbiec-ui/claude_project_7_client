import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/constants.dart';
import '../models/template.dart';

// ---------------------------------------------------------------------------
// In-memory TTL cache
// ---------------------------------------------------------------------------
// Why this approach (not Riverpod keepAlive or hive/sqflite):
//   - keepAlive keeps the provider alive while it has listeners; navigating
//     away and back creates a new listener and rebuilds from scratch.
//   - Persistent storage (hive/sqflite) adds complexity and APK size for
//     data that changes frequently and doesn't need to survive process death.
//   - A simple in-memory map with a TTL gives "instant on re-entry" within
//     one app session, survives push/pop navigation cycles, and is free.
// Cache lives in the repository (not the controller) so multiple controllers
// can share it and the data doesn't reset on controller disposal.
// ---------------------------------------------------------------------------
class _CacheEntry {
  _CacheEntry(this.data) : cachedAt = DateTime.now();
  final List<Template> data;
  final DateTime cachedAt;

  bool get isStale =>
      DateTime.now().difference(cachedAt) > kTemplateCacheTtl;
}

class _CacheKey {
  const _CacheKey(this.language, this.theme);
  final String language;
  final String? theme;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      other.language == language &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(language, theme);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  final storage = ref.read(secureStorageProvider);
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

  final _cache = <_CacheKey, _CacheEntry>{};

  /// Fetches templates filtered by [language] and optionally [theme].
  /// Returns cached data if fresh; set [bypassCache] to force a network call.
  Future<List<Template>> getTemplates({
    required String language,
    String? theme,
    bool bypassCache = false,
  }) async {
    final key = _CacheKey(language, theme);
    final cached = _cache[key];

    if (!bypassCache && cached != null && !cached.isStale) {
      return cached.data;
    }

    try {
      final params = <String, String>{'language': language};
      if (theme != null) params['theme'] = theme;

      final response = await _dio.get<List<dynamic>>(
        '/templates',
        queryParameters: params,
      );

      final templates = (response.data ?? [])
          .map((e) => Template.fromJson(e as Map<String, dynamic>))
          .toList();

      _cache[key] = _CacheEntry(templates);
      return templates;
    } on DioException catch (e) {
      // On network error, return stale cache rather than showing an error
      // if we have anything at all — better UX on flaky connections.
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
