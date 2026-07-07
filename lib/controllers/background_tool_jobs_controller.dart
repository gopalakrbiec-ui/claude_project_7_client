import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_job_controller.dart';

// ---------------------------------------------------------------------------
// Job status enum
// ---------------------------------------------------------------------------
enum ToolJobStatus { active, done, failed }

// ---------------------------------------------------------------------------
// Persisted job model
// ---------------------------------------------------------------------------
class PersistedToolJob {
  const PersistedToolJob({
    required this.jobId,
    required this.toolName,
    required this.status,
    this.resultUrl,
    required this.costPaise,
    required this.isVideo,
    this.createdAt,
  });

  final String jobId;
  final String toolName;
  final ToolJobStatus status;
  final String? resultUrl;
  final int costPaise;
  final bool isVideo;
  /// Unix timestamp (seconds) when the job was submitted.
  final int? createdAt;

  String costCoins(String symbol) => '${costPaise ~/ 100} $symbol';

  PersistedToolJob copyWith({
    ToolJobStatus? status,
    String? resultUrl,
    int? costPaise,
  }) =>
      PersistedToolJob(
        jobId: jobId,
        toolName: toolName,
        status: status ?? this.status,
        resultUrl: resultUrl ?? this.resultUrl,
        costPaise: costPaise ?? this.costPaise,
        isVideo: isVideo,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'toolName': toolName,
        'status': status.name,
        'resultUrl': resultUrl,
        'costPaise': costPaise,
        'isVideo': isVideo,
        'createdAt': createdAt,
      };

  factory PersistedToolJob.fromJson(Map<String, dynamic> json) =>
      PersistedToolJob(
        jobId: json['jobId'] as String? ?? '',
        toolName: json['toolName'] as String? ?? 'AI Tool',
        status: ToolJobStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ToolJobStatus.active,
        ),
        resultUrl: json['resultUrl'] as String?,
        costPaise: (json['costPaise'] as num?)?.toInt() ?? 0,
        isVideo: json['isVideo'] as bool? ?? false,
        createdAt: (json['createdAt'] as num?)?.toInt(),
      );
}

// Backward-compat alias used in profile_screen
typedef CompletedToolJob = PersistedToolJob;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class BackgroundToolJobsState {
  const BackgroundToolJobsState({
    this.jobs = const [],
    this.hasUnseenCompleted = false,
  });

  final List<PersistedToolJob> jobs;
  final bool hasUnseenCompleted;

  // Badge visibility
  bool get hasCompleted => hasUnseenCompleted;

  // Kept for profile_screen backward compat — returns ALL jobs now
  List<PersistedToolJob> get completedJobs => jobs;

  BackgroundToolJobsState copyWith({
    List<PersistedToolJob>? jobs,
    bool? hasUnseenCompleted,
  }) =>
      BackgroundToolJobsState(
        jobs: jobs ?? this.jobs,
        hasUnseenCompleted: hasUnseenCompleted ?? this.hasUnseenCompleted,
      );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------
class BackgroundToolJobsController
    extends Notifier<BackgroundToolJobsState> {
  static const _kPrefsKey = 'bg_tool_jobs_v2';

  @override
  BackgroundToolJobsState build() {
    _loadAndResume();
    return const BackgroundToolJobsState();
  }

  // ---- persistence ----

  Future<void> _persist(List<PersistedToolJob> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    final list = jobs.map((j) => j.toJson()).toList();
    await prefs.setString(_kPrefsKey, jsonEncode(list));
  }

  Future<List<PersistedToolJob>> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PersistedToolJob.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadAndResume() async {
    final loaded = await _load();
    if (loaded.isEmpty) return;

    // Mark any lingering "active" jobs that had no running poll as failed —
    // unless we can restart polling for them.
    final restored = <PersistedToolJob>[];
    for (final job in loaded) {
      if (job.status == ToolJobStatus.active) {
        // Resume polling — provider is not autoDispose so it survives.
        ref.read(toolJobControllerProvider(job.jobId));
        restored.add(job);
        _listenForJob(job.jobId, job.toolName, job.isVideo);
      } else {
        restored.add(job);
      }
    }

    state = state.copyWith(jobs: restored);
  }

  // ---- public API ----

  void trackJob(
    String jobId, {
    required String toolName,
    bool isVideo = false,
  }) {
    final alreadyTracked = state.jobs.any((j) => j.jobId == jobId);
    if (alreadyTracked) return;

    final job = PersistedToolJob(
      jobId: jobId,
      toolName: toolName,
      status: ToolJobStatus.active,
      costPaise: 0,
      isVideo: isVideo,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    final updated = [job, ...state.jobs];
    state = state.copyWith(jobs: updated);
    _persist(updated);

    _listenForJob(jobId, toolName, isVideo);
  }

  void _listenForJob(String jobId, String toolName, bool isVideo) {
    ref.listen(toolJobControllerProvider(jobId), (_, jobState) {
      if (jobState.phase == ToolJobPhase.done) {
        _updateJob(
          jobId,
          status: ToolJobStatus.done,
          resultUrl: jobState.resultUrl,
          costPaise: jobState.costPaise,
        );
      } else if (jobState.phase == ToolJobPhase.failed ||
          jobState.phase == ToolJobPhase.timeout ||
          jobState.phase == ToolJobPhase.networkError) {
        _updateJob(jobId, status: ToolJobStatus.failed);
      }
    });
  }

  void _updateJob(
    String jobId, {
    required ToolJobStatus status,
    String? resultUrl,
    int? costPaise,
  }) {
    final updated = state.jobs.map((j) {
      if (j.jobId != jobId) return j;
      return j.copyWith(
        status: status,
        resultUrl: resultUrl,
        costPaise: costPaise,
      );
    }).toList();

    state = state.copyWith(
      jobs: updated,
      hasUnseenCompleted: status == ToolJobStatus.done ? true : state.hasUnseenCompleted,
    );
    _persist(updated);
  }

  /// Call when user returns from profile — clears the badge only, not history.
  void clearCompleted() {
    state = state.copyWith(hasUnseenCompleted: false);
  }
}

final backgroundToolJobsProvider =
    NotifierProvider<BackgroundToolJobsController, BackgroundToolJobsState>(
  BackgroundToolJobsController.new,
);
