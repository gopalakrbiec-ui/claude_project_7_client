import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/credits_balance.dart';
import '../repositories/credits_repository.dart';

final creditsControllerProvider =
    AsyncNotifierProvider<CreditsController, CreditsBalance>(
        CreditsController.new);

class CreditsController extends AsyncNotifier<CreditsBalance> {
  @override
  Future<CreditsBalance> build() =>
      ref.read(creditsRepositoryProvider).getBalance();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(creditsRepositoryProvider).getBalance());
  }
}
