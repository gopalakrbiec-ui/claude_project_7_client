import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class KeywordTag {
  const KeywordTag({required this.key, required this.label});
  final String key;
  final String label;

  factory KeywordTag.fromJson(Map<String, dynamic> json) => KeywordTag(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );
}

class KeywordGroup {
  const KeywordGroup({
    required this.key,
    required this.label,
    required this.emoji,
    required this.tags,
  });

  final String key;
  final String label;
  final String emoji;
  final List<KeywordTag> tags;

  /// Orientation group tags set aspect_ratio, not keyword_tags.
  bool get isOrientation => key == 'orientation';

  factory KeywordGroup.fromJson(Map<String, dynamic> json) => KeywordGroup(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        emoji: json['emoji']?.toString() ?? '',
        tags: (json['tags'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(KeywordTag.fromJson)
                .toList() ??
            const [],
      );
}

// ---------------------------------------------------------------------------
// Provider — not autoDispose: fetched once per app session
// ---------------------------------------------------------------------------

final promptKeywordGroupsProvider = FutureProvider<List<KeywordGroup>>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return _fetch(dio);
});

Future<List<KeywordGroup>> _fetch(Dio dio) async {
  try {
    final response =
        await dio.get<Map<String, dynamic>>('/prompts/keyword-groups');
    final groups = response.data?['groups'] as List<dynamic>?;
    if (groups == null) return const [];
    return groups
        .whereType<Map<String, dynamic>>()
        .map(KeywordGroup.fromJson)
        .toList();
  } on DioException catch (e) {
    throw DioClient.handleDioError(e);
  }
}
