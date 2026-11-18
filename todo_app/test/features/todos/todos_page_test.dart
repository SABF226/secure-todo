import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo_app/core/error/failure.dart';
import 'package:todo_app/core/result/result.dart';
import 'package:todo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:todo_app/features/auth/domain/usecases/auth_usecases.dart';
import 'package:todo_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo_app/features/todos/domain/entities/todo.dart';
import 'package:todo_app/features/todos/domain/repositories/todo_repository.dart';
import 'package:todo_app/features/todos/domain/usecases/todo_usecases.dart';
import 'package:todo_app/features/todos/presentation/bloc/todo_bloc.dart';
import 'package:todo_app/features/todos/presentation/pages/todos_page.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

// The page is pumped with the REAL TodoBloc and a fake repository: enough to
// check the wiring (title count, filters, swipe, snackbar), no server needed.

void main() {
  late MockTodoRepository repository;

  final milk = Todo(
    id: '1',
    title: 'Buy milk',
    completed: false,
    createdAt: DateTime(2026),
  );
  final bread = Todo(
    id: '2',
    title: 'Buy bread',
    completed: true,
    createdAt: DateTime(2026),
  );

  setUp(() {
    repository = MockTodoRepository();
    when(() => repository.getTodos())
        .thenAnswer((_) async => Ok([milk, bread]));
  });

  Future<TodoBloc> pumpPage(WidgetTester tester) async {
    final bloc = TodoBloc(
      getTodos: GetTodos(repository),
      addTodo: AddTodo(repository),
      toggleTodo: ToggleTodo(repository),
      deleteTodo: DeleteTodo(repository),
    )..add(const TodosRequested());
    final authBloc = AuthBloc(
      loginUser: LoginUser(MockAuthRepository()),
      registerUser: RegisterUser(MockAuthRepository()),
      getCurrentUser: GetCurrentUser(MockAuthRepository()),
      logoutUser: LogoutUser(MockAuthRepository()),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<TodoBloc>.value(value: bloc),
        ],
        child: const MaterialApp(home: TodosPage()),
      ),
    );
    await tester.pump(); // TodosRequested -> success

    addTearDown(() async {
      await tester.runAsync(authBloc.close);
      await tester.runAsync(bloc.close);
    });
    return bloc;
  }

  testWidgets('the title counts the remaining todos only', (tester) async {
    await pumpPage(tester);

    expect(find.text('My todos (1 left)'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Buy bread'), findsOneWidget);
  });

  testWidgets('the Active filter hides completed todos', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Active'));
    await tester.pump();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Buy bread'), findsNothing);
  });

  testWidgets('ticking a checkbox is optimistic: the UI flips immediately', (
    tester,
  ) async {
    when(() => repository.updateTodo('1', completed: true))
        .thenAnswer((_) async => Ok(milk.copyWith(completed: true)));
    await pumpPage(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(); // optimistic emission, before the API answers

    expect(find.text('My todos (0 left)'), findsOneWidget);
    verify(() => repository.updateTodo('1', completed: true)).called(1);
  });

  testWidgets('swiping a tile deletes it', (tester) async {
    when(() => repository.deleteTodo('1'))
        .thenAnswer((_) async => const Ok(null));
    await pumpPage(tester);

    await tester.drag(find.text('Buy milk'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsNothing);
    verify(() => repository.deleteTodo('1')).called(1);
  });

  testWidgets('a failed toggle rolls back and shows the message once', (
    tester,
  ) async {
    when(() => repository.updateTodo('1', completed: true))
        .thenAnswer((_) async => const Err(NetworkFailure()));
    await pumpPage(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(); // optimistic
    await tester.pump(); // failure + snackbar

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('My todos (1 left)'), findsOneWidget);
    expect(
      find.text('Cannot reach the server. Check your connection.'),
      findsOneWidget,
    );
  });
}
