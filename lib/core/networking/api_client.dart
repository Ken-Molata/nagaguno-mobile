// lib/core/networking/api_client.dart
//
// Mirrors the real web app's AuthContext.jsx interceptor pattern
// (verified this session): a single access token held in memory,
// refreshed via a coalesced, single-flight request when any call gets
// a 401 — so N simultaneous 401s trigger exactly one refresh call, not
// N of them.
//
// Differs from the web version in exactly one necessary way: the web
// app relies on an httpOnly cookie for the refresh token; a native
// mobile client has no equivalent, so the refresh token is captured
// explicitly from the login/register response body and sent explicitly
// in the refresh request body instead. This required a real backend
// change (see the session notes) — the backend now returns
// `refresh_token` in the JSON body on register/login/adminLogin/
// googleAuth, and already accepted it as a body fallback on /refresh.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';
import 'redacting_log_interceptor.dart';

class AuthTokenHolder {
  AuthTokenHolder._();
  static final AuthTokenHolder instance = AuthTokenHolder._();

  String? _accessToken;

  String? get accessToken => _accessToken;

  void setAccessToken(String? token) => _accessToken = token;

  void clear() => _accessToken = null;
}

/// Fired when a refresh attempt fails outright (refresh token itself is
/// invalid/expired/revoked) — the app-level auth state should react to
/// this by navigating to the login screen. Kept as a simple callback
/// rather than a Riverpod dependency here, so this file has no
/// circular dependency on the app's provider tree.
typedef OnSessionExpired = void Function();

class ApiClient {
  ApiClient({OnSessionExpired? onSessionExpired})
      : _onSessionExpired = onSessionExpired ?? (() {}) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_buildAuthInterceptor());
    // Registered unconditionally -- the interceptor itself checks
    // kDebugMode internally and is a silent no-op in release builds,
    // so there's no risk of this logging anything in production.
    _dio.interceptors.add(RedactingLogInterceptor());
  }

  late final Dio _dio;
  // Mutable, not final -- this is what actually breaks the real
  // circular-dependency bug found this session: apiClientProvider
  // was previously defined inside auth_controller.dart specifically
  // so it could wire this callback to authControllerProvider at
  // CONSTRUCTION time, which created a genuine top-level type-
  // inference cycle (apiClientProvider -> authControllerProvider ->
  // authRepositoryProvider -> apiClientProvider), breaking `flutter
  // analyze` outright with a top_level_cycle error, and leaving
  // apiClientProvider undefined everywhere else that correctly
  // expected to find it in THIS file. Now this field can be set
  // AFTER both providers already exist independently -- see
  // authSessionWiringProvider in auth_controller.dart.
  OnSessionExpired _onSessionExpired;
  set onSessionExpired(OnSessionExpired callback) =>
      _onSessionExpired = callback;

  // Single-flight refresh lock: if a refresh is already in progress,
  // concurrent requests await this same Future instead of each
  // starting their own refresh call.
  Completer<String?>? _refreshCompleter;

  Dio get dio => _dio;

  static const _noAuthPaths = [
    ApiEndpoints.register,
    ApiEndpoints.login,
    ApiEndpoints.adminLogin,
    ApiEndpoints.googleAuth,
    ApiEndpoints.forgotPassword,
    ApiEndpoints.resetPassword,
    ApiEndpoints.refresh,
  ];

  InterceptorsWrapper _buildAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!_noAuthPaths.contains(options.path)) {
          final token = AuthTokenHolder.instance.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        final isAuthError = error.response?.statusCode == 401;
        final isNoAuthPath = _noAuthPaths.contains(error.requestOptions.path);

        if (!isAuthError || isNoAuthPath) {
          return handler.next(error);
        }

        final newAccessToken = await _refreshAccessToken();

        if (newAccessToken == null) {
          // Refresh itself failed — the session is genuinely over. The
          // cleanup and _onSessionExpired() call happen exactly once,
          // inside _refreshAccessToken itself (see its comment): every
          // request that piggybacked on the same failed refresh lands
          // here too, and each used to independently re-run this
          // block, firing _onSessionExpired() (which forceLogout()s,
          // triggering GoRouter's redirect) once per piggybacked
          // request instead of once per actual expiry. N near-
          // simultaneous redirect attempts racing the browser's own
          // back/forward navigation is exactly the shape of bug that
          // produces a Flutter "_ElementLifecycle.inactive" assertion
          // (two Navigator mutations overlapping in one frame).
          return handler.next(error);
        }

        // Retry the original request once, with the new token.
        final retryOptions = error.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        try {
          final retryResponse = await _dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      },
    );
  }

  Future<String?> _refreshAccessToken() {
    // If a refresh is already in flight, piggyback on it rather than
    // starting a second one — this is the coalescing behavior.
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    () async {
      try {
        final storedRefreshToken =
            await SecureStorage.instance.readRefreshToken();
        if (storedRefreshToken == null) {
          await _handleRefreshFailure();
          completer.complete(null);
          return;
        }

        final response = await _dio.post(
          ApiEndpoints.refresh,
          data: {'refresh_token': storedRefreshToken},
        );

        final data = response.data['data'];
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        AuthTokenHolder.instance.setAccessToken(newAccessToken);
        if (newRefreshToken != null) {
          // Backend rotates refresh tokens on every use (old one
          // revoked, new one issued) — must persist the new one or
          // the second-ever refresh call would fail, using a token
          // the backend already revoked. Verified and fixed on the
          // backend this session (/refresh now returns refresh_token
          // in its response body, matching the other 4 auth endpoints).
          await SecureStorage.instance.saveRefreshToken(newRefreshToken);
        }
        completer.complete(newAccessToken);
      } catch (_) {
        await _handleRefreshFailure();
        completer.complete(null);
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }

  // Runs exactly once per failed refresh cycle, regardless of how many
  // requests piggybacked on the same _refreshCompleter — see the
  // onError comment above for why that matters.
  Future<void> _handleRefreshFailure() async {
    AuthTokenHolder.instance.clear();
    await SecureStorage.instance.clearRefreshToken();
    _onSessionExpired();
  }
}

/// The real, single definition every other file in this app correctly
/// expects to find here -- previously this was misplaced inside
/// auth_controller.dart, wired directly to authControllerProvider at
/// construction time, which created a genuine circular dependency
/// (see the comment on ApiClient's onSessionExpired field above).
/// Clean here: no dependency on auth or any other feature, matching
/// this file's own header comment about avoiding exactly that.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
