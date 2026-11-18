import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo_app/core/error/failure.dart';
import 'package:todo_app/core/result/result.dart';
import 'package:todo_app/features/auth/domain/entities/user.dart';
import 'package:todo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:todo_app/features/auth/domain/usecases/auth_usecases.dart';
import 'package:todo_app/features/auth/presentation/bloc/auth_bloc.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  const ada = User(id: 'u1', name: 'Ada', email: 'ada@example.com');

  AuthBloc buildBloc() => AuthBloc(
    loginUser: LoginUser(repository),
    registerUser: RegisterUser(repository),
    getCurrentUser: GetCurrentUser(repository),
    logoutUser: LogoutUser(repository),
  );

  setUp(() => repository = MockAuthRepository());

  blocTest<AuthBloc, AuthState>(
    'AuthStarted restores a saved session',
    setUp: () => when(
      () => repository.currentUser(),
    ).thenAnswer((_) async => const Ok(ada)),
    build: buildBloc,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const Authenticated(ada)],
  );

  blocTest<AuthBloc, AuthState>(
    'AuthStarted without a session goes to Unauthenticated, silently',
    setUp: () => when(
      () => repository.currentUser(),
    ).thenAnswer((_) async => const Err(UnauthorizedFailure())),
    build: buildBloc,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const Unauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'login success: loading then authenticated (email is trimmed)',
    setUp: () => when(
      () => repository.login(email: 'ada@example.com', password: 'secret123'),
    ).thenAnswer((_) async => const Ok(ada)),
    build: buildBloc,
    act: (bloc) => bloc.add(
      const AuthLoginRequested(
        email: ' ada@example.com ',
        password: 'secret123',
      ),
    ),
    expect: () => [const AuthLoading(), const Authenticated(ada)],
  );

  blocTest<AuthBloc, AuthState>(
    'login failure: loading then unauthenticated with the reason',
    setUp: () => when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const Err(UnauthorizedFailure('Invalid email or password')),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(
      const AuthLoginRequested(email: 'ada@example.com', password: 'nope'),
    ),
    expect: () => [
      const AuthLoading(),
      const Unauthenticated(
        failure: UnauthorizedFailure('Invalid email or password'),
      ),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'logout clears the session',
    setUp: () => when(() => repository.logout()).thenAnswer((_) async {}),
    build: buildBloc,
    seed: () => const Authenticated(ada),
    act: (bloc) => bloc.add(const AuthLogoutRequested()),
    expect: () => [const Unauthenticated()],
    verify: (_) => verify(() => repository.logout()).called(1),
  );

  // ---- Your turn (Lab 3, section 3.12) ----

  blocTest<AuthBloc, AuthState>(
    'register failure: loading then unauthenticated with the field errors',
    setUp: () => when(
      () => repository.register(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const Err(
        ValidationFailure(
          'Validation failed',
          fieldErrors: {'password': 'String should have at least 8 characters'},
        ),
      ),
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(
      const AuthRegisterRequested(
        name: 'Ada',
        email: 'ada@example.com',
        password: 'short',
      ),
    ),
    expect: () => [
      const AuthLoading(),
      const Unauthenticated(
        failure: ValidationFailure(
          'Validation failed',
          fieldErrors: {'password': 'String should have at least 8 characters'},
        ),
      ),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'AuthSessionExpired signs the user out with an explanation',
    build: buildBloc,
    seed: () => const Authenticated(ada),
    act: (bloc) => bloc.add(const AuthSessionExpired()),
    expect: () => [
      const Unauthenticated(
        failure: UnauthorizedFailure('Your session expired. Sign in again.'),
      ),
    ],
  );
}
