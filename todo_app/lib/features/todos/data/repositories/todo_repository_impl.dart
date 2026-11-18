import '../../../../core/network/error_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/todo_remote_data_source.dart';

class TodoRepositoryImpl implements TodoRepository {
  const TodoRepositoryImpl(this._remote);

  final TodoRemoteDataSource _remote;

  @override
  Future<Result<List<Todo>>> getTodos() => guard(_remote.getTodos);

  @override
  Future<Result<Todo>> addTodo(String title) {
    return guard(() => _remote.addTodo(title));
  }

  @override
  Future<Result<Todo>> updateTodo(String id, {String? title, bool? completed}) {
    return guard(
      () => _remote.updateTodo(id, title: title, completed: completed),
    );
  }

  @override
  Future<Result<void>> deleteTodo(String id) {
    return guard(() => _remote.deleteTodo(id));
  }
}
