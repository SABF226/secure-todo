import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  // Created once: rebuilding the router would reset the navigation.
  late final _router = createRouter(context.read<AuthBloc>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Secure Todo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Light by default: the dark scheme stays available (set this to
      // ThemeMode.system, or wire a ThemeCubit) but it is opt-in, not
      // imposed by the phone's system setting.
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
