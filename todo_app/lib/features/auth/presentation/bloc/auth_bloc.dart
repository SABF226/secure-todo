import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/auth_usecases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._loginUser,
    required this._registerUser,
    required this._getCurrentUser,
    required this._logoutUser,
  }) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  final LoginUser _loginUser;
  final RegisterUser _registerUser;
  final GetCurrentUser _getCurrentUser;
  final LogoutUser _logoutUser;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final result = await _getCurrentUser();
    emit(switch (result) {
      Ok(:final value) => Authenticated(value),
      Err() => const Unauthenticated(),
    });
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _loginUser(
      email: event.email,
      password: event.password,
    );
    emit(_toState(result));
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _registerUser(
      name: event.name,
      email: event.email,
      password: event.password,
    );
    emit(_toState(result));
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _logoutUser();
    emit(const Unauthenticated());
  }

  void _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) {
    emit(
      const Unauthenticated(
        failure: UnauthorizedFailure('Your session expired. Sign in again.'),
      ),
    );
  }

  // Pattern matching on a sealed class: the compiler checks that
  // both Ok and Err are handled.
  AuthState _toState(Result<User> result) => switch (result) {
    Ok(:final value) => Authenticated(value),
    Err(:final failure) => Unauthenticated(failure: failure),
  };
}
