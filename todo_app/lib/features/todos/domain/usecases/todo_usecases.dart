import '../../../../core/result/result.dart';
import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

class GetTodos {
  const GetTodos(this._repository);

  final TodoRepository _repository;

  Future<Result<List<Todo>>> call() => _repository.getTodos();
}

class AddTodo {
  const AddTodo(this._repository);

  final TodoRepository _repository;

  Future<Result<Todo>> call(String title) => _repository.addTodo(title.trim());
}

class ToggleTodo {
  const ToggleTodo(this._repository);

  final TodoRepository _repository;

  /// Business rule lives here: toggling means inverting `completed`.
  Future<Result<Todo>> call(Todo todo) {
    return _repository.updateTodo(todo.id, completed: !todo.completed);
  }
}

class DeleteTodo {
  const DeleteTodo(this._repository);

  final TodoRepository _repository;

  Future<Result<void>> call(String id) => _repository.deleteTodo(id);
}
