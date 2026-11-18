# todo_app — Flutter client for the Secure Todo API

Lab 3 of the Advanced Mobile Development course: a Flutter app that can register, sign in,
stay signed in after a restart and sign out — built with Clean Architecture, BLoC, Dio,
`go_router` and the device keystore.

The API it talks to is `../todo_api` (Labs 1–2).

## Run it

```bash
# 1. Backend (MongoDB on 27018 + API on 3000)
cd ../todo_api && docker compose up -d && npm run dev

# 2. App
cd ../todo_app
flutter pub get
flutter run                    # Android emulator: http://10.0.2.2:3000/api/v1
```

Any other target needs an explicit base URL, because `10.0.2.2` only exists on the Android
emulator:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
flutter run -d <ios-simulator> --dart-define=API_BASE_URL=http://localhost:3000/api/v1
flutter run -d <phone> --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1
```

`android/app/src/debug/AndroidManifest.xml` sets `android:usesCleartextTraffic="true"` so the
debug build can talk plain HTTP to the emulator host. The release manifest is untouched: a
released app must use HTTPS.

## Architecture

```
lib/
  main.dart                  entry point: DI, bloc observer, BlocProvider<AuthBloc>
  app.dart                   MaterialApp.router + theme
  core/
    config/app_config.dart   API_BASE_URL from --dart-define
    error/failure.dart       sealed Failure (network, unauthorized, validation, server)
    result/result.dart       sealed Result<T> = Ok<T> | Err<T>
    network/error_mapper.dart  guard() + mapDioException(): Dio -> Failure, once
    network/auth_interceptor.dart  Bearer header + silent refresh on 401 (QueuedInterceptor)
    network/dio_client.dart  the single Dio instance
    storage/token_storage.dart  TokenStorage contract + SecureTokenStorage (Keychain/Keystore)
    di/injection.dart        composition root (get_it)
    router/app_router.dart   go_router + the auth route guard
    app_bloc_observer.dart   one log line per bloc transition
  features/auth/
    domain/    entities/user.dart, repositories/auth_repository.dart, usecases/auth_usecases.dart
    data/      models/user_model.dart, datasources/auth_remote_data_source.dart,
               repositories/auth_repository_impl.dart
    presentation/  bloc/auth_{bloc,event,state}.dart, pages/login_page.dart, register_page.dart
```

The dependency rule holds: `domain/` imports nothing from Flutter, Dio or JSON; `data/`
implements the domain contract; `presentation/` depends on use cases only. `di/injection.dart`
is the only file that knows every layer.

## Authentication behaviour

| Situation | What happens |
|---|---|
| Sign in / register | tokens saved in the Keychain (iOS) or Keystore (Android) |
| App restart | `AuthStarted` → `GetCurrentUser` → `GET /auth/me`; still signed in |
| Access token expired | interceptor refreshes the pair and replays the request; the UI sees nothing |
| Several 401s at once | `QueuedInterceptor` refreshes once, the queued requests reuse the new token |
| Refresh token rejected | tokens erased, `AuthSessionExpired` → back to `/login` with a message |
| Sign out | device cleared first, then `POST /auth/logout` (best effort: works offline) |
| Navigation | `redirect` in `app_router.dart` is the single guard; pages never call `Navigator.push` |

Tokens are never written to `SharedPreferences`: that file is plain text.

## Tests

```bash
flutter analyze     # No issues found!
flutter test        # 10 tests: 7 bloc + 3 route-guard widget tests, no server, no device

# Integration: the real data layer against the real API (start todo_api first)
flutter test --dart-define=RUN_INTEGRATION=true
```

The guard tests (`test/features/auth/auth_guard_test.dart`) pump the real `go_router` behind a
real `AuthBloc`: no session → `/login`, saved session → `/todos`, tapping *Sign out* → `/login`.

The integration suite (`test/integration/auth_api_test.dart`) registers real accounts and
checks: token persistence, `GET /auth/me`, wrong password → `UnauthorizedFailure`, duplicate
email → `ServerFailure` (409), short password → `ValidationFailure` with `fieldErrors`, silent
refresh after an invalid access token, five concurrent 401s → one refresh, rejected refresh
token → session cleared, logout offline.

## Notes

- `ACCESS_TOKEN_TTL` in `todo_api/.env` is `15m`. If you set it very low (for example `20s`) to
  watch the refresh happen, remember to restore it: every token then dies almost immediately and
  the app spends its life refreshing.
- Flutter 3.50 moved the Material widgets to `package:material_ui/material_ui.dart`; this project
  imports that package instead of the deprecated `package:flutter/material.dart`.
- Lab 4 replaces the temporary `/todos` route (a "Signed in" screen with a sign-out button) with
  the real todos feature; nothing in `core/` or `features/auth/` should need to change.
