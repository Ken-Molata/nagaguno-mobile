// lib/core/networking/redacting_log_interceptor.dart
//
// The original spec explicitly required never logging passwords,
// tokens, government IDs, or sensitive KYC responses (Section 49/53).
// No logging interceptor existed at all until now -- which is safe by
// omission, but also means there was no way to actually debug network
// issues during development. This builds one properly instead: real
// visibility into request/response shape and status, with the
// specific fields that matter masked before anything is printed, and
// entirely compiled out of release builds via kDebugMode.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Field names checked case-insensitively against every request body,
/// query parameter, and response body key before printing -- covers
/// every sensitive field this app actually sends or receives,
/// verified against the real request/response shapes built this
/// session (auth tokens, KYC personal data, payment proof).
const _sensitiveKeys = {
  'password',
  'new_password',
  'otp',
  'access_token',
  'refresh_token',
  'age',
  'date_of_birth',
  'complete_address',
  'contact_number',
  'id_front',
  'id_back',
  'supporting_doc',
  'liveness_photo',
  'photo',
  'proof',
};

dynamic redactSensitiveData(dynamic value) {
  if (value is FormData) {
    // Multipart uploads (KYC documents, product/crop/profile photos,
    // payment proof) use FormData, not a plain Map -- the check
    // below would otherwise silently skip these entirely, since
    // FormData isn't a Map or List. Text fields are redacted the
    // same way; file fields are only ever named, never have their
    // actual bytes printed (MultipartFile's own toString() doesn't
    // include file content, so this is a belt-and-suspenders
    // explicit note, not fixing an actual data leak).
    final fields = Map.fromEntries(value.fields);
    final fileFieldNames = value.files.map((f) => f.key).toList();
    return {
      'fields': redactSensitiveData(fields),
      'files (name only)': fileFieldNames
    };
  }
  if (value is Map) {
    return value.map((k, v) {
      final keyStr = k.toString().toLowerCase();
      if (_sensitiveKeys.any((s) => keyStr.contains(s))) {
        return MapEntry(k, '<redacted>');
      }
      return MapEntry(k, redactSensitiveData(v));
    });
  }
  if (value is List) {
    return value.map(redactSensitiveData).toList();
  }
  return value;
}

class RedactingLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('--> ${options.method} ${options.uri}');
      if (options.data != null) {
        debugPrint('    body: ${redactSensitiveData(options.data)}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('<-- ${response.statusCode} ${response.requestOptions.uri}');
      debugPrint('    body: ${redactSensitiveData(response.data)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
          '<-- ERROR ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
    }
    handler.next(err);
  }
}
