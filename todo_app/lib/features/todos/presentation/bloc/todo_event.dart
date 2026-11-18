part of 'todo_bloc.dart';

sealed class TodoEvent extends Equatable {
  const TodoEvent();

  @override
  List<Object?> get props => [];
}

/// The list must be (re)loaded: page opened or pull-to-refresh.
final class TodosRequested extends TodoEvent {
  const TodosRequested();
}

final class TodoAdded extends TodoEvent {
  const TodoAdded(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

final class TodoToggled extends TodoEvent {
  const TodoToggled(this.todo);

  final Todo todo;

  @override
  List<Object?> get props => [todo];
}

final class TodoDeleted extends TodoEvent {
  const TodoDeleted(this.todo);

  final Todo todo;

  @override
  List<Object?> get props => [todo];
}

final class TodoFilterChanged extends TodoEvent {
  const TodoFilterChanged(this.filter);

  final TodoFilter filter;

  @override
  List<Object?> get props => [filter];
}
