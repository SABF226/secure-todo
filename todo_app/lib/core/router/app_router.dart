import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/todos/presentation/bloc/todo_bloc.dart';
import '../../features/todos/presentation/pages/todos_page.dart';
import '../di/injection.dart';
import '../widgets/splash_screen.dart';

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/splash',
    // Re-run `redirect` every time the auth state changes.
    refreshListenable: _StreamListenable(authBloc.stream),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onAuthPage = location == '/login' || location == '/register';

      // The route guard: ONE place decides who can see what.
      return switch (authBloc.state) {
        AuthInitial() => '/splash',
        Authenticated() when onAuthPage || location == '/splash' => '/todos',
        Unauthenticated() when !onAuthPage => '/login',
        _ => null, // stay where you are
      };
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/todos',
        // The bloc lives exactly as long as this route.
        builder: (context, state) => BlocProvider(
          create: (_) => sl<TodoBloc>()..add(const TodosRequested()),
          child: const TodosPage(),
        ),
      ),
    ],
  );
}

/// Adapts a Stream (the bloc) to a Listenable (what go_router expects).
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
