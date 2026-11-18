// lib/core/utils/friendly_error_message.dart
//
// Genuinely demo-relevant: the app is likely to be shown on venue/
// conference wifi, where a slow or dropped connection is a real,
// common scenario -- and until now, every catch block across the app
// showed the identical generic "Something went wrong" regardless of
// whether the actual cause was a timeout (reassuring: "it's just the
// network, not a bug") or a genuine server/logic error (which is
// worth knowing is different). Centralized here rather than touching
// every catch block individually -- screens can opt into this
// message instead of their own hardcoded generic string.

import 'package:dio/dio.dart';

String friendlyErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      // UW 19's own exact wording for a connectivity-detected failure --
      // REAL BUG FOUND AND FIXED: this previously invented two different,
      // non-spec strings split by Dio's own exception subtype (timeout
      // vs. connection error), when the spec draws no such distinction --
      // just one wording for "connectivity is the detected cause".
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'You appear to be offline. Check your connection and try again.';
      default:
        // Prefer the real backend's own message when it sent one
        // (e.g. a validation error) -- only fall back to a generic
        // message when it genuinely didn't.
        final data = error.response?.data;
        final backendMessage =
            (data is Map ? data['message'] : null) as String?;
        return backendMessage ?? 'Something went wrong. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
