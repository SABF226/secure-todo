import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// 1. Adds `Authorization: Bearer <access token>` to every request.
/// 2. When the API answers 401, silently refreshes the tokens and replays
///    the request, so the user never notices the access token expired.
///
/// A [QueuedInterceptor] handles errors ONE AT A TIME. If five requests
/// fail with 401 together, only the first one triggers a refresh; the
/// others wait in the queue and then reuse the new token.
class AuthInterceptor extends QueuedInterceptor {
  // Private named parameters: callers write `tokenStorage:`, the value
  // lands in the private field `_tokenStorage`.
  AuthInterceptor({
    required this._tokenStorage,
    required this._plainDio,
    required this._onSessionExpired,
  });

  final TokenStorage _tokenStorage;

  /// A Dio WITHOUT this interceptor, used to refresh and to replay.
  /// Using the main Dio here would re-enter the queue and deadlock.
  final Dio _plainDio;

  final void Function() _onSessionExpired;

  static const _publicPaths = [
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
  ];

  bool _isPublic(RequestOptions options) =>
      _publicPaths.any(options.path.endsWith);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options)) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || _isPublic(request)) {
      return handler.next(err);
    }

    try {
      // Another request may have refreshed while this one was queued.
      final sentHeader = request.headers['Authorization'];
      var token = await _tokenStorage.readAccessToken();
      if (token == null || sentHeader == 'Bearer $token') {
        token = await _refreshTokens();
      }

      // Replay the original request with the fresh token.
      request.headers['Authorization'] = 'Bearer $token';
      final response = await _plainDio.fetch<dynamic>(request);

      return handler.resolve(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // The refresh token is invalid too: the session is over.
        await _tokenStorage.clear();
        _onSessionExpired();
      }
      return handler.next(e);
    }
  }

  Future<String> _refreshTokens() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    final response = await _plainDio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    await _tokenStorage.save(
      accessToken: accessToken,
      refreshToken: data['refreshToken'] as String,
    );
    return accessToken;
  }
}
