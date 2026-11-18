import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/app_bloc_observer.dart';
import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();

  Bloc.observer = const AppBlocObserver();

  runApp(
    // AuthBloc sits above the whole app: every page can read it.
    BlocProvider<AuthBloc>(
      create: (_) => sl<AuthBloc>()..add(const AuthStarted()),
      child: const TodoApp(),
    ),
  );
}
