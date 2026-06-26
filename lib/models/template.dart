/// Mirror of GET /templates[] item schema.
/// Replace with generated model once `make gen-api` has run.
class Template {
  const Template({
    required this.id,
    required this.name,
    required this.language,
    required this.theme,
    required this.basePricePaise,
    required this.assetKeys,
  });

  final String id;
  final String name;
  final String language; // "en" | "hi" | "te"
  final String theme; // "floral", "wedding", "birthday", …
  /// Raw paise — use for logic (e.g. affordability check) only.
  final int basePricePaise;
  /// Ordered list of CDN asset keys / URLs for this template.
  final List<String> assetKeys;

  /// Pre-formatted display price — derived from basePricePaise by formatting
  /// here since the backend does NOT return a price_display for templates
  /// (only for orders). Use Rupee symbol + paise-to-rupee conversion for
  /// display; the backend is still the source of truth for the raw value.
  String get priceDisplay {
    final rupees = basePricePaise / 100;
    return rupees == rupees.truncateToDouble()
        ? '₹${rupees.toInt()}'
        : '₹${rupees.toStringAsFixed(2)}';
  }

  /// First asset key used as thumbnail. Returns null if list is empty.
  String? get thumbnailKey => assetKeys.isEmpty ? null : assetKeys.first;

  factory Template.fromJson(Map<String, dynamic> json) {
    // asset_keys may be an empty map {} (backend quirk) or a proper list [].
    final rawKeys = json['asset_keys'];
    final assetKeys = rawKeys is List
        ? rawKeys.map((e) => e.toString()).toList()
        : <String>[];

    return Template(
      // id may come as int or string depending on backend serialiser.
      id: json['id'].toString(),
      name: json['name'] as String,
      language: json['language'] as String,
      theme: json['theme'] as String,
      basePricePaise: json['base_price_paise'] as int,
      assetKeys: assetKeys,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Template && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
