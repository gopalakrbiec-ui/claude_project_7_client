import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tool_job_controller.dart';

class BackgroundToolJobsState {
  const BackgroundToolJobsState({
    this.activeJobIds = const {},
    this.completedJobIds = const {},
  });

  final Set<String> activeJobIds;
  final Set<String> completedJobIds;

  bool get hasCompleted => completedJobIds.isNotEmpty;
  int get completedCount => completedJobIds.length;

  BackgroundToolJobsState copyWith({
    Set<String>? activeJobIds,
    Set<String>? completedJobIds,
  }) =>
      BackgroundToolJobsState(
        activeJobIds: activeJobIds ?? this.activeJobIds,
        completedJobIds: completedJobIds ?? this.completedJobIds,
      );
}

class BackgroundToolJobsController
    extends Notifier<BackgroundToolJobsState> {
  @override
  BackgroundToolJobsState build() => const BackgroundToolJobsState();

  void trackJob(String jobId) {
    if (state.activeJobIds.contains(jobId) ||
        state.completedJobIds.contains(jobId)) return;

    state = state.copyWith(
      activeJobIds: {...state.activeJobIds, jobId},
    );

    ref.listen(toolJobControllerProvider(jobId), (_, jobState) {
      if (jobState.phase == ToolJobPhase.done) {
        state = state.copyWith(
          activeJobIds: {...state.activeJobIds}..remove(jobId),
          completedJobIds: {...state.completedJobIds, jobId},
        );
      } else if (jobState.isTerminal) {
        state = state.copyWith(
          activeJobIds: {...state.activeJobIds}..remove(jobId),
        );
      }
    });
  }

  void clearCompleted() {
    state = state.copyWith(completedJobIds: {});
  }
}

final backgroundToolJobsProvider =
    NotifierProvider<BackgroundToolJobsController, BackgroundToolJobsState>(
  BackgroundToolJobsController.new,
);
