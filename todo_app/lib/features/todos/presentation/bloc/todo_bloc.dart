import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/todo.dart';
import '../../domain/usecases/todo_usecases.dart';

part 'todo_event.dart';
part 'todo_state.dart';

class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc({
    required this._getTodos,
    required this._addTodo,
    required this._toggleTodo,
    required this._deleteTodo,
  }) : super(const TodoState()) {
    // restartable: a new refresh cancels the one still in progress.
    on<TodosRequested>(_onRequested, transformer: restartable());
    // sequential: changes are sent to the API one after the other.
    on<TodoAdded>(_onAdded, transformer: sequential());
    on<TodoToggled>(_onToggled, transformer: sequential());
    on<TodoDeleted>(_onDeleted, transformer: sequential());
    on<TodoFilterChanged>(_onFilterChanged);
  }

  final GetTodos _getTodos;
  final AddTodo _addTodo;
  final ToggleTodo _toggleTodo;
  final DeleteTodo _deleteTodo;

  Future<void> _onRequested(
    TodosRequested event,
    Emitter<TodoState> emit,
  ) async {
    emit(state.copyWith(status: TodoStatus.loading));
    final result = await _getTodos();
    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        status: TodoStatus.success,
        todos: value,
      ),
      Err(:final failure) => state.copyWith(
        status: TodoStatus.failure,
        failure: failure,
      ),
    });
  }

  Future<void> _onAdded(TodoAdded event, Emitter<TodoState> emit) async {
    final result = await _addTodo(event.title);
    emit(switch (result) {
      Ok(:final value) => state.copyWith(todos: [value, ...state.todos]),
      Err(:final failure) => state.copyWith(failure: failure),
    });
  }

  /// Optimistic update: change the UI first, then call the API.
  /// If the API refuses, put the old value back and report the error.
  Future<void> _onToggled(TodoToggled event, Emitter<TodoState> emit) async {
    final original = event.todo;
    final optimistic = original.copyWith(completed: !original.completed);
    emit(state.copyWith(todos: _replace(optimistic)));

    final result = await _toggleTodo(original);
    emit(switch (result) {
      Ok(:final value) => state.copyWith(todos: _replace(value)),
      Err(:final failure) => state.copyWith(
        todos: _replace(original),
        failure: failure,
      ),
    });
  }

  Future<void> _onDeleted(TodoDeleted event, Emitter<TodoState> emit) async {
    final index = state.todos.indexWhere((todo) => todo.id == event.todo.id);
    if (index == -1) return;
    emit(
      state.copyWith(
        todos: state.todos.where((todo) => todo.id != event.todo.id).toList(),
      ),
    );

    final result = await _deleteTodo(event.todo.id);
    if (result case Err(:final failure)) {
      // Roll back: put the todo back where it was.
      final restored = [...state.todos]
        ..insert(index.clamp(0, state.todos.length), event.todo);
      emit(state.copyWith(todos: restored, failure: failure));
    }
  }

  void _onFilterChanged(TodoFilterChanged event, Emitter<TodoState> emit) {
    emit(state.copyWith(filter: event.filter));
  }

  List<Todo> _replace(Todo updated) => [
    for (final todo in state.todos) todo.id == updated.id ? updated : todo,
  ];
}
