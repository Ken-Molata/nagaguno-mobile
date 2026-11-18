// lib/core/connectivity/connectivity_provider.dart
//
// The original spec's Section 66 explicitly required offline/poor-
// connection handling, distinct from a generic server error --
// nothing in this app addressed this at all until now. This is a
// real, proportionate first step (detection + a clear banner), not
// full offline-first caching/queuing, which would be a much larger,
// separate undertaking.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true = has some form of connection (does NOT guarantee the
/// connection actually reaches the internet/backend, only that the
/// device has an active network interface -- a real, honest
/// limitation of connectivity_plus itself, not something this
/// provider can improve on without adding real request-based
/// reachability pinging, which is a separate, heavier concern).
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  // onConnectivityChanged only fires on CHANGES, not an initial value
  // -- without checking the current state first, this provider would
  // sit in a loading state indefinitely until the network actually
  // changed at least once after app launch. Caught before shipping,
  // not discovered as a real "banner never appears on cold start" bug.
  final initial = await Connectivity().checkConnectivity();
  yield !initial.contains(ConnectivityResult.none);

  yield* Connectivity().onConnectivityChanged.map(
        (results) => !results.contains(ConnectivityResult.none),
      );
});
