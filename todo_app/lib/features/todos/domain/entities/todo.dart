import 'package:equatable/equatable.dart';

class Todo extends Equatable {
  const Todo({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;

  /// Entities are immutable: to "change" one, build a modified copy.
  Todo copyWith({String? title, bool? completed}) {
    return Todo(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, title, completed, createdAt];
}
