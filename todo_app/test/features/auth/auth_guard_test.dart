import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo_app/core/di/injection.dart';
import 'package:todo_app/core/error/failure.dart';
import 'package:todo_app/core/result/result.dart';
import 'package:todo_app/core/router/app_router.dart';
import 'package:todo_app/features/auth/domain/entities/user.dart';
import 'package:todo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:todo_app/features/auth/domain/usecases/auth_usecases.dart';
import 'package:todo_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo_app/features/auth/presentation/pages/login_page.dart';
import 'package:todo_app/features/todos/domain/entities/todo.dart';
import 'package:todo_app/features/todos/domain/repositories/todo_repository.dart';
import 'package:todo_app/features/todos/domain/usecases/todo_usecases.dart';
import 'package:todo_app/features/todos/presentation/bloc/todo_bloc.dart';
import 'package:todo_app/features/todos/presentation/pages/todos_page.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  const ada = User(id: 'u1', name: 'Ada', email: 'ada@example.com');

  AuthBloc buildBloc(MockAuthRepository repository) => AuthBloc(
    loginUser: LoginUser(repository),
    registerUser: RegisterUser(repository),
    getCurrentUser: GetCurrentUser(repository),
    logoutUser: LogoutUser(repository),
  )..add(const AuthStarted());

  /// The route builder asks the service locator for a [TodoBloc], exactly like
  /// the real app. We register one built on a fake repository: the guard tests
  /// only care about navigation, never about real todos.
  setUp(() {
    final todoRepository = MockTodoRepository();
    when(() => todoRepository.getTodos())
        .thenAnswer((_) async => const Ok(<Todo>[]));
    sl.registerFactory(
      () => TodoBloc(
        getTodos: GetTodos(todoRepository),
        addTodo: AddTodo(todoRepository),
        toggleTodo: ToggleTodo(todoRepository),
        deleteTodo: DeleteTodo(todoRepository),
      ),
    );
  });

  tearDown(sl.reset);

  /// Pumps the real router behind a real [AuthBloc], exactly like `main.dart`.
  /// Discrete pumps: the splash screen shows a never-ending progress indicator,
  /// so `pumpAndSettle` would time out.
  Future<GoRouter> pumpApp(WidgetTester tester, AuthBloc bloc) async {
    final router = createRouter(bloc);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(); // AuthStarted -> Authenticated | Unauthenticated
    await tester.pump(); // redirect runs again after refreshListenable fires
    await tester.pump(); // TodosRequested -> success (empty list)
    return router;
  }

  testWidgets('no saved session: the guard opens /login', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.currentUser())
        .thenAnswer((_) async => const Err(UnauthorizedFailure()));
    final bloc = buildBloc(repository);
    final router = await pumpApp(tester, bloc);

    expect(bloc.state, isA<Unauthenticated>());
    expect(find.byType(LoginPage), findsOneWidget);

    router.dispose();
    // Real async: closing a bloc awaits a microtask the fake-async zone of a
    // widget test never flushes.
    await tester.runAsync(bloc.close);
  });

  testWidgets('saved session: the guard opens /todos, not /login', (
    tester,
  ) async {
    final repository = MockAuthRepository();
    when(() => repository.currentUser()).thenAnswer((_) async => const Ok(ada));
    final bloc = buildBloc(repository);
    final router = await pumpApp(tester, bloc);

    expect(bloc.state, isA<Authenticated>());
    expect(find.byType(TodosPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);

    router.dispose();
    // Real async: closing a bloc awaits a microtask the fake-async zone of a
    // widget test never flushes.
    await tester.runAsync(bloc.close);
  });

  testWidgets('signing out sends the user back to /login', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.currentUser()).thenAnswer((_) async => const Ok(ada));
    when(() => repository.logout()).thenAnswer((_) async {});
    final bloc = buildBloc(repository);
    final router = await pumpApp(tester, bloc);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
    verify(() => repository.logout()).called(1);

    router.dispose();
    // Real async: closing a bloc awaits a microtask the fake-async zone of a
    // widget test never flushes.
    await tester.runAsync(bloc.close);
  });
}
