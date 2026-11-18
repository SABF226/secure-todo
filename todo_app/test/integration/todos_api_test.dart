/// Integration test: the real todos data layer against the real API.
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
import 'package:todo_app/features/todos/data/datasources/todo_remote_data_source.dart';
import 'package:todo_app/features/todos/data/repositories/todo_repository_impl.dart';
import 'package:todo_app/features/todos/domain/entities/todo.dart';

const _enabled = bool.fromEnvironment('RUN_INTEGRATION');
const _baseUrl = 'http://localhost:3000/api/v1';
const _password = 'correct-horse-9';

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
  late AuthRepositoryImpl auth;
  late TodoRepositoryImpl todos;
  late String email;

  setUp(() async {
    // A fresh account per test: no test depends on another one's leftovers,
    // and a new account must never see somebody else's todos.
    email = 'todos+${DateTime.now().microsecondsSinceEpoch}@example.com';
    storage = InMemoryTokenStorage();
    final dio = Dio(BaseOptions(baseUrl: _baseUrl))
      ..interceptors.add(
        AuthInterceptor(
          tokenStorage: storage,
          plainDio: Dio(BaseOptions(baseUrl: _baseUrl)),
          onSessionExpired: () {},
        ),
      );
    auth = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(dio),
      tokenStorage: storage,
    );
    todos = TodoRepositoryImpl(TodoRemoteDataSource(dio));

    // Every test starts signed in, exactly like the app after the login page.
    final session = await auth.register(
      name: 'Ada Lovelace',
      email: email,
      password: _password,
    );
    expect(session, isA<Ok<Object>>(), reason: 'the API must be running');
  });

  Future<Todo> add(String title) async {
    final result = await todos.addTodo(title);
    expect(result, isA<Ok<Todo>>());
    return (result as Ok<Todo>).value;
  }

  test(
    'add then list: the todo comes back from the server',
    () async {
      final created = await add('Buy milk');
      expect(created.title, 'Buy milk');
      expect(created.completed, isFalse);

      final result = await todos.getTodos();

      expect(result, isA<Ok<List<Todo>>>());
      final list = (result as Ok<List<Todo>>).value;
      expect(list.map((t) => t.id), contains(created.id));
    },
    skip: _enabled
        ? false
        : 'needs the API: --dart-define=RUN_INTEGRATION=true',
  );

  test(
    'getTodos is newest first, as the API sorts it',
    () async {
      await add('first');
      await add('second');

      final list = (await todos.getTodos() as Ok<List<Todo>>).value;

      expect(list.map((t) => t.title).take(2), ['second', 'first']);
    },
    skip: _enabled
        ? false
        : 'needs the API: --dart-define=RUN_INTEGRATION=true',
  );

  test(
    'updateTodo sends only completed and keeps the title',
    () async {
      final created = await add('Buy milk');

      final result = await todos.updateTodo(created.id, completed: true);

      expect(result, isA<Ok<Todo>>());
      final updated = (result as Ok<Todo>).value;
      expect(updated.completed, isTrue);
      expect(updated.title, 'Buy milk', reason: 'null-aware map elements');
    },
    skip: _enabled
        ? false
        : 'needs the API: --dart-define=RUN_INTEGRATION=true',
  );

  test(
    'deleteTodo removes the todo, and a second delete is a 404',
    () async {
      final created = await add('Buy milk');

      expect(await todos.deleteTodo(created.id), isA<Ok<void>>());
      final after = (await todos.getTodos() as Ok<List<Todo>>).value;
      expect(after.map((t) => t.id), isNot(contains(created.id)));

      final again = await todos.deleteTodo(created.id);
      expect(again, isA<Err<void>>());
      expect((again as Err<void>).failure, isA<ServerFailure>());
    },
    skip: _enabled
        ? false
        : 'needs the API: --dart-define=RUN_INTEGRATION=true',
  );

  test(
    'an empty title is a ValidationFailure with fieldErrors',
    () async {
      final result = await todos.addTodo('');

      expect(result, isA<Err<Todo>>());
      final failure = (result as Err<Todo>).failure;
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fieldErrors, contains('title'));
    },
    skip: _enabled
        ? false
        : 'needs the API: --dart-define=RUN_INTEGRATION=true',
  );

  test(
    'a second account does not see the first account\'s todos',
    () async {
      await add('private');

      // Same device, new account: the bloc is recreated, the API must filter.
      final second = InMemoryTokenStorage();
      final dio = Dio(BaseOptions(baseUrl: _baseUrl))
        ..interceptors.add(
          AuthInterceptor(
            tokenStorage: second,
            plainDio: Dio(BaseOptions(baseUrl: _baseUrl)),
            onSessionExpired: () {},
          ),
        );
      final otherAuth = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(dio),
        tokenStorage: second,
      );
      await otherAuth.register(
        name: 'Grace Hopper',
        email: 'other+${DateTime.now().microsecondsSinceEpoch}@example.com',
        password: _password,
      );

      final list =
          (await TodoRepositoryImpl(TodoRemoteDataSource(dio)).getTodos()
                  as Ok<List<Todo>>)
              .value;

      expect(list, isEmpty);
    },
    skip: _enabled
        ? false
        : 'needs the API: --dart-define=RUN_INTEGRATION=true',
  );

  test(
    'a todo belonging to somebody else answers 404',
    () async {
      final created = await add('private');

      final second = InMemoryTokenStorage();
      final dio = Dio(BaseOptions(baseUrl: _baseUrl))
        ..interceptors.add(
          AuthInterceptor(
            tokenStorage: second,
            plainDio: Dio(BaseOptions(baseUrl: _baseUrl)),
            onSessionExpired: () {},
          ),
        );
      await AuthRepositoryImpl(
        remote: AuthRemoteDataSource(dio),
        tokenStorage: second,
      ).register(
        name: 'Grace Hopper',
        email: 'other+${DateTime.now().microsecondsSinceEpoch}@example.com',
        password: _password,
      );

      final result = await TodoRepositoryImpl(TodoRemoteDataSource(dio))
          .updateTodo(created.id, completed: true);

      expect(result, isA<Err<Todo>>());
      expect((result as Err<Todo>).failure, isA<ServerFailure>());
    },
    skip: _enabled
        ? false
        : 'needs the API: --dart-define=RUN_INTEGRATION=true',
  );
}
