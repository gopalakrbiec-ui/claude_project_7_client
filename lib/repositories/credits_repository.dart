import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';
import '../models/credits_balance.dart';

final creditsRepositoryProvider = Provider<CreditsRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return CreditsRepository(dio);
});

class CreditsRepository {
  CreditsRepository(this._dio);
  final Dio _dio;

  /// GET /credits/balance
  /// The backend returns balance_rupees already formatted — display that.
  /// Use balance_paise only for comparison logic (e.g. can the user afford a template?).
  Future<CreditsBalance> getBalance() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/credits/balance');
      return CreditsBalance.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
