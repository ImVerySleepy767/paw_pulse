import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current connectivity state immediately, then updates on
/// every change. connectivity_plus tells us whether a network interface
/// (WiFi/mobile data) is connected — not whether there's real internet
/// access — which matches what the course package covers.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  yield await Connectivity().checkConnectivity();
  yield* Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.when(
    data: (results) => results.isNotEmpty && !results.contains(ConnectivityResult.none),
    loading: () => true, // assume online until the first check resolves
    error: (_, _) => true,
  );
});
