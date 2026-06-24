import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../models/agent_earnings.dart';

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return AgentRepository(dio);
});

class AgentRepository {
  AgentRepository(this._dio);
  final Dio _dio;

  /// GET /agents/me/earnings
  Future<AgentEarnings> getEarnings() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/agents/me/earnings');
      return AgentEarnings.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
