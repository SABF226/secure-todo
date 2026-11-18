import 'package:material_ui/material_ui.dart';

import '../../domain/entities/todo.dart';

/// A "dumb" widget: it receives data and callbacks, and knows nothing
/// about blocs or repositories. That makes it trivial to reuse and test.
class TodoTile extends StatelessWidget {
  const TodoTile({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    super.key,
  });

  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      child: Card(
        child: CheckboxListTile(
          value: todo.completed,
          onChanged: (_) => onToggle(),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            todo.title,
            style: theme.textTheme.titleMedium?.copyWith(
              decoration: todo.completed ? TextDecoration.lineThrough : null,
              decorationColor: scheme.outline,
              color: todo.completed ? scheme.outline : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
