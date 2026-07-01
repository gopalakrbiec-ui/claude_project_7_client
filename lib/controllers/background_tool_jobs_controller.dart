import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tool_job_controller.dart';

class CompletedToolJob {
  const CompletedToolJob({
    required this.jobId,
    required this.toolName,
    this.resultUrl,
    required this.costDisplay,
    required this.isVideo,
  });

  final String jobId;
  final String toolName;
  final String? resultUrl;
  final String costDisplay;
  final bool isVideo;
}

class BackgroundToolJobsState {
  const BackgroundToolJobsState({
    this.activeJobIds = const {},
    this.completedJobs = const [],
  });

  final Set<String> activeJobIds;
  final List<CompletedToolJob> completedJobs;

  bool get hasCompleted => completedJobs.isNotEmpty;
  int get completedCount => completedJobs.length;

  Set<String> get completedJobIds => completedJobs.map((j) => j.jobId).toSet();

  BackgroundToolJobsState copyWith({
    Set<String>? activeJobIds,
    List<CompletedToolJob>? completedJobs,
  }) =>
      BackgroundToolJobsState(
        activeJobIds: activeJobIds ?? this.activeJobIds,
        completedJobs: completedJobs ?? this.completedJobs,
      );
}

class BackgroundToolJobsController
    extends Notifier<BackgroundToolJobsState> {
  @override
  BackgroundToolJobsState build() => const BackgroundToolJobsState();

  void trackJob(String jobId, {required String toolName, bool isVideo = false}) {
    final alreadyTracked = state.activeJobIds.contains(jobId) ||
        state.completedJobs.any((j) => j.jobId == jobId);
    if (alreadyTracked) return;

    state = state.copyWith(
      activeJobIds: {...state.activeJobIds, jobId},
    );

    ref.listen(toolJobControllerProvider(jobId), (_, jobState) {
      if (jobState.phase == ToolJobPhase.done) {
        final completed = CompletedToolJob(
          jobId: jobId,
          toolName: toolName,
          resultUrl: jobState.resultUrl,
          costDisplay: jobState.costDisplay,
          isVideo: isVideo,
        );
        state = state.copyWith(
          activeJobIds: {...state.activeJobIds}..remove(jobId),
          completedJobs: [completed, ...state.completedJobs],
        );
      } else if (jobState.isTerminal) {
        state = state.copyWith(
          activeJobIds: {...state.activeJobIds}..remove(jobId),
        );
      }
    });
  }

  void clearCompleted() {
    state = state.copyWith(completedJobs: []);
  }
}

final backgroundToolJobsProvider =
    NotifierProvider<BackgroundToolJobsController, BackgroundToolJobsState>(
  BackgroundToolJobsController.new,
);
