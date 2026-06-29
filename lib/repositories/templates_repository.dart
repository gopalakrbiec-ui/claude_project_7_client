import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';
import '../core/constants.dart';
import '../models/template.dart';

// ---------------------------------------------------------------------------
// Cache entry
// ---------------------------------------------------------------------------
class _CacheEntry<T> {
  _CacheEntry(this.data) : cachedAt = DateTime.now();
  final T data;
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

  _CacheEntry<List<TemplateCategoryGroup>>? _groupedCache;
  final _flatCache = <String?, _CacheEntry<List<Template>>>{};

  /// Fetches templates grouped by category — primary API for the home screen.
  Future<List<TemplateCategoryGroup>> getGroupedTemplates({
    bool bypassCache = false,
  }) async {
    final cached = _groupedCache;
    if (!bypassCache && cached != null && !cached.isStale) {
      return cached.data;
    }

    try {
      final response = await _dio.get<List<dynamic>>('/templates/grouped');
      final groups = (response.data ?? [])
          .map((e) => TemplateCategoryGroup.fromJson(e as Map<String, dynamic>))
          .toList();
      _groupedCache = _CacheEntry(groups);
      // Also populate the flat cache so detail screens can find by id.
      _flatCache[null] = _CacheEntry(
        groups.expand((g) => g.templates).toList(),
      );
      return groups;
    } on DioException catch (e) {
      if (cached != null) return cached.data;
      throw DioClient.handleDioError(e);
    }
  }

  /// Flat list — used by the All Templates grid tab.
  Future<List<Template>> getTemplates({
    String? theme,
    bool bypassCache = false,
  }) async {
    // If we already have grouped data, derive flat list from it.
    if (!bypassCache && _groupedCache != null && !_groupedCache!.isStale) {
      final all = _groupedCache!.data.expand((g) => g.templates).toList();
      return theme == null ? all : all.where((t) => t.category == theme).toList();
    }

    final cached = _flatCache[theme];
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
      _flatCache[theme] = _CacheEntry(templates);
      return templates;
    } on DioException catch (e) {
      if (cached != null) return cached.data;
      throw DioClient.handleDioError(e);
    }
  }

  /// Looks up a single template by id from any cached data.
  Template? getCached(String id) {
    // Check grouped cache first.
    if (_groupedCache != null) {
      for (final group in _groupedCache!.data) {
        for (final t in group.templates) {
          if (t.id == id) return t;
        }
      }
    }
    for (final entry in _flatCache.values) {
      final match = entry.data.where((t) => t.id == id);
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }

  void invalidateAll() {
    _groupedCache = null;
    _flatCache.clear();
  }
}
