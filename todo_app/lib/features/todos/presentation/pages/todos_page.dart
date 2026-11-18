import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        // BlocSelector rebuilds ONLY when the selected value changes.
        title: BlocSelector<TodoBloc, TodoState, int>(
          selector: (state) => state.activeCount,
          builder: (context, count) => Text('My todos ($count left)'),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTodo(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.all(12), child: _FilterBar()),
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
      segments: const [
        ButtonSegment(value: TodoFilter.all, label: Text('All')),
        ButtonSegment(value: TodoFilter.active, label: Text('Active')),
        ButtonSegment(value: TodoFilter.completed, label: Text('Done')),
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
          return Center(
            child: FilledButton.tonal(
              onPressed: () =>
                  context.read<TodoBloc>().add(const TodosRequested()),
              child: const Text('Retry'),
            ),
          );
        case TodoStatus.success:
          break;
      }
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: todos.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Nothing here. Tap + to add a todo.')),
              ],
            )
          : ListView.builder(
              itemCount: todos.length,
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
