import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

/// Sees every event, state change and error of every bloc in the app.
/// Perfect for logging now, and for crash reporting / analytics later.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    log(
      '${transition.event.runtimeType}: '
      '${transition.currentState.runtimeType} -> '
      '${transition.nextState.runtimeType}',
      name: bloc.runtimeType.toString(),
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('$error', name: bloc.runtimeType.toString(), stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
