import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:todo_app/core/error/failure.dart';
import 'package:todo_app/core/result/result.dart';
import 'package:todo_app/features/todos/domain/entities/todo.dart';
import 'package:todo_app/features/todos/domain/repositories/todo_repository.dart';
import 'package:todo_app/features/todos/domain/usecases/todo_usecases.dart';
import 'package:todo_app/features/todos/presentation/bloc/todo_bloc.dart';

// The bloc is tested with the REAL use cases and a FAKE repository:
// thanks to the repository interface, no server is needed.

class MockTodoRepository extends Mock implements TodoRepository {}

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

  TodoBloc buildBloc() => TodoBloc(
    getTodos: GetTodos(repository),
    addTodo: AddTodo(repository),
    toggleTodo: ToggleTodo(repository),
    deleteTodo: DeleteTodo(repository),
  );

  setUp(() => repository = MockTodoRepository());

  group('TodosRequested', () {
    blocTest<TodoBloc, TodoState>(
      'emits loading then success with the todos',
      setUp: () =>
          when(() => repository.getTodos())
              .thenAnswer((_) async => Ok([milk, bread])),
      build: buildBloc,
      act: (bloc) => bloc.add(const TodosRequested()),
      expect: () => [
        const TodoState(status: TodoStatus.loading),
        TodoState(status: TodoStatus.success, todos: [milk, bread]),
      ],
    );

    blocTest<TodoBloc, TodoState>(
      'emits loading then failure when the network is down',
      setUp: () =>
          when(() => repository.getTodos())
              .thenAnswer((_) async => const Err(NetworkFailure())),
      build: buildBloc,
      act: (bloc) => bloc.add(const TodosRequested()),
      expect: () => [
        const TodoState(status: TodoStatus.loading),
        const TodoState(status: TodoStatus.failure, failure: NetworkFailure()),
      ],
    );
  });

  group('TodoAdded', () {
    blocTest<TodoBloc, TodoState>(
      'trims the title and puts the new todo first',
      setUp: () =>
          when(() => repository.addTodo('Buy milk'))
              .thenAnswer((_) async => Ok(milk)),
      build: buildBloc,
      seed: () => TodoState(status: TodoStatus.success, todos: [bread]),
      act: (bloc) => bloc.add(const TodoAdded(' Buy milk ')),
      expect: () => [
        TodoState(status: TodoStatus.success, todos: [milk, bread]),
      ],
      verify: (_) => verify(() => repository.addTodo('Buy milk')).called(1),
    );
  });

  group('TodoToggled', () {
    final done = milk.copyWith(completed: true);

    blocTest<TodoBloc, TodoState>(
      'updates the UI immediately (optimistic), then keeps the server value',
      setUp: () =>
          when(() => repository.updateTodo('1', completed: true))
              .thenAnswer((_) async => Ok(done)),
      build: buildBloc,
      seed: () => TodoState(status: TodoStatus.success, todos: [milk]),
      act: (bloc) => bloc.add(TodoToggled(milk)),
      // The optimistic state and the confirmed state are equal, and a
      // bloc never emits the same state twice in a row: one emission.
      expect: () => [
        TodoState(status: TodoStatus.success, todos: [done]),
      ],
    );

    blocTest<TodoBloc, TodoState>(
      'rolls back and reports the error when the API fails',
      setUp: () =>
          when(() => repository.updateTodo('1', completed: true))
              .thenAnswer((_) async => const Err(NetworkFailure())),
      build: buildBloc,
      seed: () => TodoState(status: TodoStatus.success, todos: [milk]),
      act: (bloc) => bloc.add(TodoToggled(milk)),
      expect: () => [
        TodoState(status: TodoStatus.success, todos: [done]),
        TodoState(
          status: TodoStatus.success,
          todos: [milk],
          failure: const NetworkFailure(),
        ),
      ],
    );
  });

  group('TodoDeleted', () {
    blocTest<TodoBloc, TodoState>(
      'removes the todo, and restores it at the same place on failure',
      setUp: () =>
          when(() => repository.deleteTodo('1'))
              .thenAnswer((_) async => const Err(ServerFailure())),
      build: buildBloc,
      seed: () => TodoState(status: TodoStatus.success, todos: [milk, bread]),
      act: (bloc) => bloc.add(TodoDeleted(milk)),
      expect: () => [
        TodoState(status: TodoStatus.success, todos: [bread]),
        TodoState(
          status: TodoStatus.success,
          todos: [milk, bread],
          failure: const ServerFailure(),
        ),
      ],
    );

    // Your turn #1: the success path removes the todo and stops there.
    blocTest<TodoBloc, TodoState>(
      'removes the todo and keeps it removed when the API succeeds',
      setUp: () =>
          when(() => repository.deleteTodo('1'))
              .thenAnswer((_) async => const Ok(null)),
      build: buildBloc,
      seed: () => TodoState(status: TodoStatus.success, todos: [milk, bread]),
      act: (bloc) => bloc.add(TodoDeleted(milk)),
      expect: () => [
        TodoState(status: TodoStatus.success, todos: [bread]),
      ],
      verify: (_) => verify(() => repository.deleteTodo('1')).called(1),
    );

    blocTest<TodoBloc, TodoState>(
      'ignores a todo that is not in the list',
      setUp: () =>
          when(() => repository.deleteTodo('1'))
              .thenAnswer((_) async => const Ok(null)),
      build: buildBloc,
      seed: () => TodoState(status: TodoStatus.success, todos: [bread]),
      act: (bloc) => bloc.add(TodoDeleted(milk)),
      expect: () => <TodoState>[],
      verify: (_) => verifyNever(() => repository.deleteTodo(any())),
    );
  });

  // Your turn #2: switching filter only touches the derived getters.
  group('TodoFilterChanged', () {
    blocTest<TodoBloc, TodoState>(
      'stores the filter and filters visibleTodos',
      build: buildBloc,
      seed: () => TodoState(status: TodoStatus.success, todos: [milk, bread]),
      act: (bloc) => bloc.add(const TodoFilterChanged(TodoFilter.active)),
      expect: () => [
        TodoState(
          status: TodoStatus.success,
          todos: [milk, bread],
          filter: TodoFilter.active,
        ),
      ],
    );
  });

  test('visibleTodos applies the filter', () {
    final state = TodoState(todos: [milk, bread]);
    expect(state.visibleTodos, [milk, bread]);
    expect(state.copyWith(filter: TodoFilter.active).visibleTodos, [milk]);
    expect(state.copyWith(filter: TodoFilter.completed).visibleTodos, [bread]);
    expect(state.activeCount, 1);
  });
}
