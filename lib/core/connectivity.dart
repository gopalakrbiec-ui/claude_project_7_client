import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Reactive online/offline detection via connectivity_plus.
//
// isOnlineProvider is a synchronous bool derived from the stream — safe to
// watch in build() without an AsyncValue unwrap. The initial value defaults
// to true so the UI does not flash an offline banner before the first
// connectivity event arrives.
// ---------------------------------------------------------------------------

final _connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(_connectivityStreamProvider).valueOrNull;
  if (results == null) return true; // unknown → assume online
  return results.any((r) => r != ConnectivityResult.none);
});
