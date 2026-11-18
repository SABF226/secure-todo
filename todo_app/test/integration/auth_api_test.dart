/// Integration test: the real data layer against the real API.
///
/// Not part of the default `flutter test` run, because it needs the server:
///   cd todo_api && npm run dev
///   cd todo_app && flutter test --dart-define=RUN_INTEGRATION=true
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/error/failure.dart';
import 'package:todo_app/core/network/auth_interceptor.dart';
import 'package:todo_app/core/result/result.dart';
import 'package:todo_app/core/storage/token_storage.dart';
import 'package:todo_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:todo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo_app/features/auth/domain/entities/user.dart';

const _enabled = bool.fromEnvironment('RUN_INTEGRATION');
const _baseUrl = 'http://localhost:3000/api/v1';

/// In-memory stand-in for the Keystore: a unit test must not touch the device.
class InMemoryTokenStorage implements TokenStorage {
  String? access;
  String? refresh;

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

void main() {
  late InMemoryTokenStorage storage;
  late AuthRepositoryImpl repository;
  late String email;
  var sessionsExpired = 0;

  Dio plainDio() => Dio(BaseOptions(baseUrl: _baseUrl));

  setUp(() {
    // A fresh account per test: no test depends on another one's leftovers.
    email = 'flutter+${DateTime.now().microsecondsSinceEpoch}@example.com';
    storage = InMemoryTokenStorage();
    sessionsExpired = 0;
    final dio = Dio(BaseOptions(baseUrl: _baseUrl))
      ..interceptors.add(
        AuthInterceptor(
          tokenStorage: storage,
          plainDio: plainDio(),
          onSessionExpired: () => sessionsExpired++,
        ),
      );
    repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(dio),
      tokenStorage: storage,
    );
  });

  const password = 'correct-horse-9';

  test('register stores the tokens and returns the user', () async {
    final result = await repository.register(
      name: 'Ada Lovelace',
      email: email,
      password: password,
    );

    expect(result, isA<Ok<User>>());
    expect((result as Ok<User>).value.email, email);
    expect(storage.access, isNotNull);
    expect(storage.refresh, isNotNull);
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');

  test('currentUser restores the session from the stored token', () async {
    await repository.register(
      name: 'Ada Lovelace',
      email: email,
      password: password,
    );

    final result = await repository.currentUser();

    expect(result, isA<Ok<User>>());
    expect((result as Ok<User>).value.email, email);
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');

  test('login with a wrong password is an UnauthorizedFailure', () async {
    await repository.register(
      name: 'Ada Lovelace',
      email: email,
      password: password,
    );

    final result = await repository.login(
      email: email,
      password: 'not-the-password',
    );

    expect(result, isA<Err<User>>());
    expect(
      (result as Err<User>).failure,
      isA<UnauthorizedFailure>().having(
        (f) => f.message,
        'message',
        'Invalid email or password',
      ),
    );
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');

  test('an already used email is a ServerFailure with the 409 message', () async {
    await repository.register(
      name: 'Ada Lovelace',
      email: email,
      password: password,
    );

    final result = await repository.register(
      name: 'Ada Again',
      email: email,
      password: password,
    );

    expect(result, isA<Err<User>>());
    expect((result as Err<User>).failure, isA<ServerFailure>());
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');

  test('a too short password is a ValidationFailure with fieldErrors', () async {
    final result = await repository.register(
      name: 'Ada Lovelace',
      email: 'short+${DateTime.now().millisecondsSinceEpoch}@example.com',
      password: 'short',
    );

    expect(result, isA<Err<User>>());
    final failure = (result as Err<User>).failure;
    expect(failure, isA<ValidationFailure>());
    expect((failure as ValidationFailure).fieldErrors, contains('password'));
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');

  test('an invalid access token is refreshed silently, then replayed', () async {
    await repository.register(
      name: 'Ada Lovelace',
      email: email,
      password: password,
    );
    final refreshToken = storage.refresh;

    storage.access = 'not.a.valid.jwt';

    final result = await repository.currentUser();

    expect(result, isA<Ok<User>>());
    expect(storage.access, isNot('not.a.valid.jwt'));
    expect(storage.refresh, isNot(refreshToken), reason: 'rotation');
    expect(sessionsExpired, 0);
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');

  test('five concurrent 401s trigger a single refresh', () async {
    await repository.register(
      name: 'Ada Lovelace',
      email: email,
      password: password,
    );

    storage.access = 'not.a.valid.jwt';

    final results = await Future.wait([
      for (var i = 0; i < 5; i++) repository.currentUser(),
    ]);

    expect(results.every((r) => r is Ok<User>), isTrue);
    expect(sessionsExpired, 0);
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');

  test('a rejected refresh token ends the session', () async {
    await repository.register(
      name: 'Ada Lovelace',
      email: email,
      password: password,
    );

    storage.access = 'not.a.valid.jwt';
    storage.refresh = 'not-a-valid-refresh-token';

    final result = await repository.currentUser();

    expect(result, isA<Err<User>>());
    expect((result as Err<User>).failure, isA<UnauthorizedFailure>());
    expect(sessionsExpired, 1);
    expect(storage.access, isNull);
    expect(storage.refresh, isNull);
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');

  test('logout clears the device even when the API is unreachable', () async {
    await repository.register(
      name: 'Ada Lovelace',
      email: email,
      password: password,
    );

    await repository.logout();

    expect(storage.access, isNull);
    expect(storage.refresh, isNull);
  }, skip: _enabled ? false : 'needs the API: --dart-define=RUN_INTEGRATION=true');
}
