part of 'todo_bloc.dart';

enum TodoStatus { initial, loading, success, failure }

enum TodoFilter { all, active, completed }

/// A single state class with a status field. This style suits screens
/// that keep showing their data while something else happens (refresh,
/// add, delete). Compare with the sealed AuthState.
class TodoState extends Equatable {
  const TodoState({
    this.status = TodoStatus.initial,
    this.todos = const [],
    this.filter = TodoFilter.all,
    this.failure,
  });

  final TodoStatus status;
  final List<Todo> todos;
  final TodoFilter filter;

  /// The last error, shown once by the UI.
  final Failure? failure;

  /// Derived data is computed, never stored: it can never be out of sync.
  List<Todo> get visibleTodos => switch (filter) {
    TodoFilter.all => todos,
    TodoFilter.active => todos.where((todo) => !todo.completed).toList(),
    TodoFilter.completed => todos.where((todo) => todo.completed).toList(),
  };

  int get activeCount => todos.where((todo) => !todo.completed).length;

  /// Note: [failure] is NOT carried over. Every new state starts without
  /// an error unless one is given, so an old error is never shown twice.
  TodoState copyWith({
    TodoStatus? status,
    List<Todo>? todos,
    TodoFilter? filter,
    Failure? failure,
  }) {
    return TodoState(
      status: status ?? this.status,
      todos: todos ?? this.todos,
      filter: filter ?? this.filter,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, todos, filter, failure];
}
