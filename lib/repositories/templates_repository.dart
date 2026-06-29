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

  /// Fetches templates grouped by category.
  /// Tries GET /templates/grouped first; falls back to GET /templates + client-side grouping.
  Future<List<TemplateCategoryGroup>> getGroupedTemplates({
    bool bypassCache = false,
  }) async {
    final cached = _groupedCache;
    if (!bypassCache && cached != null && !cached.isStale) {
      return cached.data;
    }

    // Try grouped endpoint first.
    try {
      final response = await _dio.get<List<dynamic>>('/templates/grouped');
      final raw = response.data ?? [];
      if (raw.isNotEmpty) {
        final groups = raw
            .map((e) => TemplateCategoryGroup.fromJson(e as Map<String, dynamic>))
            .toList();
        _groupedCache = _CacheEntry(groups);
        _flatCache[null] = _CacheEntry(groups.expand((g) => g.templates).toList());
        return groups;
      }
    } on DioException catch (_) {
      // Fall through to flat-list fallback.
    }

    // Fallback: GET /templates and group client-side.
    return _getGroupedFromFlat(bypassCache: bypassCache, cached: cached);
  }

  Future<List<TemplateCategoryGroup>> _getGroupedFromFlat({
    required bool bypassCache,
    _CacheEntry<List<TemplateCategoryGroup>>? cached,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>('/templates');
      final templates = (response.data ?? [])
          .map((e) => Template.fromJson(e as Map<String, dynamic>))
          .toList();
      _flatCache[null] = _CacheEntry(templates);

      // Group by category, preserving insertion order.
      final grouped = <String, List<Template>>{};
      for (final t in templates) {
        (grouped[t.category] ??= []).add(t);
      }
      final groups = grouped.entries
          .map((e) => TemplateCategoryGroup(
                category: e.key,
                label: _categoryLabel(e.key),
                templates: e.value,
              ))
          .toList();
      _groupedCache = _CacheEntry(groups);
      return groups;
    } on DioException catch (e) {
      if (cached != null) return cached.data;
      throw DioClient.handleDioError(e);
    }
  }

  static String _categoryLabel(String category) {
    final labels = <String, String>{
      'wedding': 'Wedding',
      'bridal': 'Bridal',
      'floral': 'Floral',
      'royal': 'Royal',
      'garden': 'Garden',
      'birthday': 'Birthday',
      'business': 'Business',
      'bollywood': 'Bollywood',
      'cricket': 'Cricket',
      'festival': 'Festival',
    };
    return labels[category.toLowerCase()] ??
        category[0].toUpperCase() + category.substring(1);
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
