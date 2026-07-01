import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../core/constants.dart';
import '../repositories/tools_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum ToolJobPhase { polling, done, failed, timeout, networkError }

class ToolJobState {
  const ToolJobState({
    required this.phase,
    this.resultUrl,
    this.error,
    this.costPaise = 0,
    this.attemptCount = 0,
    this.currentDelay,
  });

  final ToolJobPhase phase;
  final String? resultUrl;
  final String? error;
  final int costPaise;
  final int attemptCount;
  final Duration? currentDelay;

  bool get isTerminal =>
      phase == ToolJobPhase.done ||
      phase == ToolJobPhase.failed ||
      phase == ToolJobPhase.timeout ||
      phase == ToolJobPhase.networkError;

  String get costDisplay {
    final r = costPaise / 100;
    return r == r.truncateToDouble()
        ? '₹${r.toInt()}'
        : '₹${r.toStringAsFixed(2)}';
  }

  ToolJobState copyWith({
    ToolJobPhase? phase,
    String? resultUrl,
    String? error,
    bool clearError = false,
    int? costPaise,
    int? attemptCount,
    Duration? currentDelay,
  }) =>
      ToolJobState(
        phase: phase ?? this.phase,
        resultUrl: resultUrl ?? this.resultUrl,
        error: clearError ? null : (error ?? this.error),
        costPaise: costPaise ?? this.costPaise,
        attemptCount: attemptCount ?? this.attemptCount,
        currentDelay: currentDelay ?? this.currentDelay,
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final toolJobControllerProvider =
    NotifierProvider.family<ToolJobController, ToolJobState, String>(
  ToolJobController.new,
);

// ---------------------------------------------------------------------------
// Controller — exponential-backoff polling of GET /tools/status/{jobId}
// ---------------------------------------------------------------------------
class ToolJobController extends FamilyNotifier<ToolJobState, String> {
  bool _cancelled = false;
  String get _jobId => arg;

  @override
  ToolJobState build(String jobId) {
    ref.onDispose(() => _cancelled = true);
    _startPolling(delay: kOrderPollInitialDelay);
    return const ToolJobState(phase: ToolJobPhase.polling);
  }

  void retry() {
    _cancelled = false;
    state = const ToolJobState(phase: ToolJobPhase.polling);
    _startPolling(delay: kOrderPollInitialDelay);
  }

  Future<void> _startPolling({required Duration delay}) async {
    for (var attempt = 0; attempt < kOrderPollMaxAttempts; attempt++) {
      await Future<void>.delayed(delay);
      if (_cancelled) return;

      state = state.copyWith(
        phase: ToolJobPhase.polling,
        attemptCount: attempt + 1,
        currentDelay: delay,
      );

      try {
        final status =
            await ref.read(toolsRepositoryProvider).getToolStatus(_jobId);
        if (_cancelled) return;

        if (status.isDone) {
          state = state.copyWith(
            phase: ToolJobPhase.done,
            resultUrl: status.resultUrl,
            costPaise: status.costPaise,
          );
          return;
        }
        if (status.isFailed) {
          state = state.copyWith(
            phase: ToolJobPhase.failed,
            error: status.error ?? 'AI processing failed. Please try again.',
            costPaise: status.costPaise,
          );
          return;
        }
        // still processing
        state = state.copyWith(costPaise: status.costPaise);
        delay = _backoff(delay);
      } on NetworkError {
        // reset to initial delay so a returning device retries quickly
        delay = kOrderPollInitialDelay;
      } on ServerError catch (e) {
        if (_cancelled) return;
        state = state.copyWith(
          phase: ToolJobPhase.networkError,
          error: e.message,
        );
        return;
      } catch (_) {
        // unexpected — keep retrying
      }
    }

    if (!_cancelled) {
      state = state.copyWith(phase: ToolJobPhase.timeout);
    }
  }

  Duration _backoff(Duration current) {
    final next =
        Duration(milliseconds: (current.inMilliseconds * 1.5).round());
    return next > kOrderPollMaxDelay ? kOrderPollMaxDelay : next;
  }
}
