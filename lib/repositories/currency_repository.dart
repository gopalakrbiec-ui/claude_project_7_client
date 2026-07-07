import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';

class CurrencyInfo {
  const CurrencyInfo({
    required this.name,
    required this.symbol,
    required this.unitRatePaise,
  });

  final String name;
  final String symbol;

  /// How many paise equal 1 coin — currently always 100.
  final int unitRatePaise;

  /// Converts paise to coin count.
  int toCoin(int paise) => paise ~/ unitRatePaise;

  /// "12 🪙" format.
  String display(int paise) => '${toCoin(paise)} $symbol';

  factory CurrencyInfo.fromJson(Map<String, dynamic> json) => CurrencyInfo(
        name: json['name']?.toString() ?? 'Savi Coins',
        symbol: json['symbol']?.toString() ?? '🪙',
        unitRatePaise: (json['unit_rate_paise'] as num?)?.toInt() ?? 100,
      );

  static const fallback = CurrencyInfo(
    name: 'Savi Coins',
    symbol: '🪙',
    unitRatePaise: 100,
  );
}

/// Fetched once at app start; not autoDispose so it survives across screens.
final currencyInfoProvider = FutureProvider<CurrencyInfo>((ref) async {
  final storage = ref.read(tokenStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  try {
    final response =
        await dio.get<Map<String, dynamic>>('/credits/currency-info');
    return CurrencyInfo.fromJson(response.data!);
  } on DioException catch (e) {
    throw DioClient.handleDioError(e);
  }
});

/// Synchronous fallback: returns the cached value or [CurrencyInfo.fallback].
/// Use in widgets that already hold a loaded state; prefer watching the
/// provider directly in new code.
CurrencyInfo currencyOrFallback(AsyncValue<CurrencyInfo> async) =>
    async.valueOrNull ?? CurrencyInfo.fallback;
