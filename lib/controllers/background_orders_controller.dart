import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'order_status_controller.dart';

class BackgroundOrdersState {
  const BackgroundOrdersState({
    this.activeOrderIds = const {},
    this.completedOrderIds = const {},
  });

  final Set<String> activeOrderIds;
  final Set<String> completedOrderIds;

  bool get hasCompleted => completedOrderIds.isNotEmpty;
  int get completedCount => completedOrderIds.length;

  BackgroundOrdersState copyWith({
    Set<String>? activeOrderIds,
    Set<String>? completedOrderIds,
  }) =>
      BackgroundOrdersState(
        activeOrderIds: activeOrderIds ?? this.activeOrderIds,
        completedOrderIds: completedOrderIds ?? this.completedOrderIds,
      );
}

class BackgroundOrdersController extends Notifier<BackgroundOrdersState> {
  @override
  BackgroundOrdersState build() => const BackgroundOrdersState();

  void trackOrder(String orderId) {
    if (state.activeOrderIds.contains(orderId) ||
        state.completedOrderIds.contains(orderId)) return;

    state = state.copyWith(
      activeOrderIds: {...state.activeOrderIds, orderId},
    );

    ref.listen(orderStatusControllerProvider(orderId), (_, orderState) {
      if (orderState.phase == OrderPhase.done) {
        state = state.copyWith(
          activeOrderIds: {...state.activeOrderIds}..remove(orderId),
          completedOrderIds: {...state.completedOrderIds, orderId},
        );
      } else if (orderState.isTerminal) {
        state = state.copyWith(
          activeOrderIds: {...state.activeOrderIds}..remove(orderId),
        );
      }
    });
  }

  void clearCompleted() {
    state = state.copyWith(completedOrderIds: {});
  }
}

final backgroundOrdersProvider =
    NotifierProvider<BackgroundOrdersController, BackgroundOrdersState>(
  BackgroundOrdersController.new,
);
