import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';

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
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      // Temporary route: Lab 4 replaces it with the real todos page.
      GoRoute(
        path: '/todos',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Signed in')),
          body: Center(
            child: FilledButton(
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthLogoutRequested()),
              child: const Text('Sign out'),
            ),
          ),
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
