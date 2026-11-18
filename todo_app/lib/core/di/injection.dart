import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/todos/data/datasources/todo_remote_data_source.dart';
import '../../features/todos/data/repositories/todo_repository_impl.dart';
import '../../features/todos/domain/repositories/todo_repository.dart';
import '../../features/todos/domain/usecases/todo_usecases.dart';
import '../../features/todos/presentation/bloc/todo_bloc.dart';
import '../network/dio_client.dart';
import '../storage/token_storage.dart';

/// The service locator ("sl"). This file is the COMPOSITION ROOT: the only
/// place that knows which concrete class implements which contract.
final sl = GetIt.instance;

void configureDependencies() {
  // ---- Core ----
  sl.registerLazySingleton<TokenStorage>(
    () => SecureTokenStorage(const FlutterSecureStorage()),
  );
  sl.registerLazySingleton<Dio>(
    () => createDio(
      tokenStorage: sl(),
      onSessionExpired: () => sl<AuthBloc>().add(const AuthSessionExpired()),
    ),
  );

  // ---- Auth feature ----
  sl.registerLazySingleton(() => AuthRemoteDataSource(sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remote: sl(), tokenStorage: sl()),
  );
  sl.registerLazySingleton(() => LoginUser(sl()));
  sl.registerLazySingleton(() => RegisterUser(sl()));
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => LogoutUser(sl()));
  // Singleton: one AuthBloc for the whole app (global state).
  sl.registerLazySingleton(
    () => AuthBloc(
      loginUser: sl(),
      registerUser: sl(),
      getCurrentUser: sl(),
      logoutUser: sl(),
    ),
  );

  // ---- Todos feature ----
  sl.registerLazySingleton(() => TodoRemoteDataSource(sl()));
  sl.registerLazySingleton<TodoRepository>(() => TodoRepositoryImpl(sl()));
  sl.registerLazySingleton(() => GetTodos(sl()));
  sl.registerLazySingleton(() => AddTodo(sl()));
  sl.registerLazySingleton(() => ToggleTodo(sl()));
  sl.registerLazySingleton(() => DeleteTodo(sl()));

  // Factory: a NEW TodoBloc each time the todos page is opened
  // (so a new user never sees the previous user's list).
  sl.registerFactory(
    () => TodoBloc(
      getTodos: sl(),
      addTodo: sl(),
      toggleTodo: sl(),
      deleteTodo: sl(),
    ),
  );
}
