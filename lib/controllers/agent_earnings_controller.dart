import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent_earnings.dart';
import '../repositories/agent_repository.dart';

final agentEarningsControllerProvider =
    AsyncNotifierProvider<AgentEarningsController, AgentEarnings>(
        AgentEarningsController.new);

class AgentEarningsController extends AsyncNotifier<AgentEarnings> {
  @override
  Future<AgentEarnings> build() =>
      ref.read(agentRepositoryProvider).getEarnings();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(agentRepositoryProvider).getEarnings());
  }
}
