import '../../../../core/result/result.dart';
import '../entities/todo.dart';

abstract interface class TodoRepository {
  Future<Result<List<Todo>>> getTodos();

  Future<Result<Todo>> addTodo(String title);

  Future<Result<Todo>> updateTodo(String id, {String? title, bool? completed});

  Future<Result<void>> deleteTodo(String id);
}
