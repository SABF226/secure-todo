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
        title: const Text('My todos'),
        actions: [
          const Center(child: _RemainingPill()),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 12),
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
          const _CompletionSummary(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
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
              // Cross-fade between loading, empty and list states.
              builder: (context, state) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _TodoList(
                  key: ValueKey(
                    '${state.status.name}-${state.visibleTodos.isEmpty}',
                  ),
                  state: state,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How many todos are left, right in the app bar.
class _RemainingPill extends StatelessWidget {
  const _RemainingPill();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // BlocSelector rebuilds ONLY when the selected value changes.
    return BlocSelector<TodoBloc, TodoState, int>(
      selector: (state) => state.activeCount,
      builder: (context, count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count left',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A quiet progress line: "1 of 3 done" plus the ratio.
class _CompletionSummary extends StatelessWidget {
  const _CompletionSummary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // One record selector: no rebuild unless the two numbers change.
    return BlocSelector<TodoBloc, TodoState, (int, int)>(
      selector: (state) =>
          (state.todos.length - state.activeCount, state.todos.length),
      builder: (context, value) {
        final (done, total) = value;
        if (total == 0) return const SizedBox.shrink();
        final ratio = done / total;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$done of $total done',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, animated, _) => LinearProgressIndicator(
                    value: animated,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final filter = context.select((TodoBloc bloc) => bloc.state.filter);
    return SegmentedButton<TodoFilter>(
      // Full width: three equal segments under the summary.
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
  const _TodoList({required this.state, super.key});

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

/// A soft purple disc around the icon: no image asset needed.
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
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      children: [
        Center(
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer,
                  scheme.primaryContainer.withValues(alpha: 0.25),
                ],
              ),
            ),
            child: Icon(icon, size: 52, color: scheme.primary),
          ),
        ),
        const SizedBox(height: 24),
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
