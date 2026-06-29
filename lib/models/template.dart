/// Mirror of TemplateOut from GET /templates/grouped.
class Template {
  const Template({
    required this.id,
    required this.name,
    required this.language,
    required this.theme,
    required this.category,
    required this.basePricePaise,
    required this.assetKeys,
    required this.isFeatured,
    this.label,
    this.imageUrl,
    this.previewUrl,
  });

  final String id;
  final String name;
  final String language;
  final String theme;
  final String category;
  final bool isFeatured;

  /// Human-readable section header (e.g. "Cricket Glory"). Falls back to category.
  final String? label;

  /// Convenience CDN URL — same as assetKeys[0] per backend spec.
  final String? imageUrl;
  final String? previewUrl;

  final int basePricePaise;
  final List<String> assetKeys;

  String get priceDisplay {
    final rupees = basePricePaise / 100;
    return rupees == rupees.truncateToDouble()
        ? '₹${rupees.toInt()}'
        : '₹${rupees.toStringAsFixed(2)}';
  }

  /// Best available thumbnail: imageUrl → previewUrl → first assetKey.
  String? get thumbnailKey =>
      imageUrl ?? previewUrl ?? (assetKeys.isEmpty ? null : assetKeys.first);

  factory Template.fromJson(Map<String, dynamic> json) {
    final rawKeys = json['asset_keys'];
    final assetKeys = rawKeys is List
        ? rawKeys.map((e) => e.toString()).toList()
        : <String>[];

    return Template(
      id: json['id'].toString(),
      name: json['name'] as String,
      language: (json['language'] as String?) ?? '',
      theme: (json['theme'] as String?) ?? '',
      category: (json['category'] as String?) ?? (json['theme'] as String?) ?? '',
      isFeatured: (json['is_featured'] as bool?) ?? false,
      label: json['label'] as String?,
      imageUrl: json['image_url'] as String?,
      previewUrl: json['preview_url'] as String?,
      basePricePaise: (json['base_price_paise'] as num).toInt(),
      assetKeys: assetKeys,
    );
  }

  @override
  bool operator ==(Object other) => other is Template && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Mirror of TemplateCategoryGroup from GET /templates/grouped.
class TemplateCategoryGroup {
  const TemplateCategoryGroup({
    required this.category,
    required this.label,
    required this.templates,
  });

  final String category;
  final String label;
  final List<Template> templates;

  factory TemplateCategoryGroup.fromJson(Map<String, dynamic> json) {
    final rawTemplates = json['templates'] as List<dynamic>? ?? [];
    return TemplateCategoryGroup(
      category: json['category'] as String,
      label: json['label'] as String,
      templates: rawTemplates
          .map((e) => Template.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
