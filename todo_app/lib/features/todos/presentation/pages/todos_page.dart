import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_logo.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/todo_bloc.dart';
import '../widgets/add_todo_sheet.dart';
import '../widgets/todo_tile.dart';

class TodosPage extends StatelessWidget {
  const TodosPage({super.key});

  Future<void> _addTodo(BuildContext context) async {
    final bloc = context.read<TodoBloc>();
    final title = await AddTodoSheet.show(context);
    if (title != null) bloc.add(TodoAdded(title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Center(child: AppLogo(size: 34)),
        ),
        // BlocSelector rebuilds ONLY when the selected value changes.
        title: BlocSelector<TodoBloc, TodoState, int>(
          selector: (state) => state.activeCount,
          builder: (context, count) => Text('My todos ($count left)'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthLogoutRequested()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTodo(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New todo'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _FilterBar(),
          ),
          Expanded(
            child: BlocConsumer<TodoBloc, TodoState>(
              listenWhen: (previous, current) => current.failure != null,
              listener: (context, state) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(state.failure!.message)),
                  );
              },
              builder: (context, state) => _TodoList(state: state),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final filter = context.select((TodoBloc bloc) => bloc.state.filter);
    return SegmentedButton<TodoFilter>(
      // Full width: three equal segments under the app bar.
      expandedInsets: EdgeInsets.zero,
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: TodoFilter.all,
          label: Text('All'),
          icon: Icon(Icons.inbox_rounded, size: 18),
        ),
        ButtonSegment(
          value: TodoFilter.active,
          label: Text('Active'),
          icon: Icon(Icons.radio_button_unchecked_rounded, size: 18),
        ),
        ButtonSegment(
          value: TodoFilter.completed,
          label: Text('Done'),
          icon: Icon(Icons.check_circle_outline_rounded, size: 18),
        ),
      ],
      selected: {filter},
      onSelectionChanged: (selection) =>
          context.read<TodoBloc>().add(TodoFilterChanged(selection.first)),
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({required this.state});

  final TodoState state;

  Future<void> _refresh(BuildContext context) {
    final bloc = context.read<TodoBloc>()..add(const TodosRequested());
    // Keep the refresh spinner visible until loading is over.
    return bloc.stream.firstWhere((s) => s.status != TodoStatus.loading);
  }

  @override
  Widget build(BuildContext context) {
    final todos = state.visibleTodos;

    // First load: nothing to show yet.
    if (state.todos.isEmpty) {
      switch (state.status) {
        case TodoStatus.initial || TodoStatus.loading:
          return const Center(child: CircularProgressIndicator());
        case TodoStatus.failure:
          return _ErrorState(
            onRetry: () =>
                context.read<TodoBloc>().add(const TodosRequested()),
          );
        case TodoStatus.success:
          break;
      }
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: todos.isEmpty
          ? _EmptyState(filter: state.filter)
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: todos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final todo = todos[index];
                return TodoTile(
                  todo: todo,
                  onToggle: () =>
                      context.read<TodoBloc>().add(TodoToggled(todo)),
                  onDelete: () =>
                      context.read<TodoBloc>().add(TodoDeleted(todo)),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final TodoFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, title, hint) = switch (filter) {
      TodoFilter.all => (
        Icons.task_alt_rounded,
        'Nothing here yet',
        'Tap “New todo” to add your first one.',
      ),
      TodoFilter.active => (
        Icons.done_all_rounded,
        'All done',
        'Every todo is completed. Nice work.',
      ),
      TodoFilter.completed => (
        Icons.schedule_rounded,
        'Nothing completed',
        'Tick a todo and it will show up here.',
      ),
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 88, 32, 32),
      children: [
        Icon(icon, size: 52, color: scheme.primary),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'Could not load your todos',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
