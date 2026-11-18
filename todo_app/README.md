# todo_app — Flutter client for the Secure Todo API

Lab 3–4 of the Advanced Mobile Development course: a Flutter app that can register, sign in,
stay signed in after a restart, sign out, and manage a todo list with optimistic updates —
built with Clean Architecture, BLoC, Dio, `go_router` and the device keystore.

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
    theme/app_theme.dart     brand purple, Material 3 light + dark, component styles
    widgets/                 AppLogo, SplashScreen (the only shared dumb widgets)
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
    presentation/  bloc/auth_{bloc,event,state}.dart, pages/login_page.dart, register_page.dart,
                   widgets/auth_header.dart
  features/todos/
    domain/    entities/todo.dart, repositories/todo_repository.dart, usecases/todo_usecases.dart
    data/      models/todo_model.dart, datasources/todo_remote_data_source.dart,
               repositories/todo_repository_impl.dart
    presentation/  bloc/todo_{bloc,event,state}.dart, pages/todos_page.dart,
                   widgets/todo_tile.dart, widgets/add_todo_sheet.dart
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

## Todos behaviour

| Situation | What happens |
|---|---|
| Open `/todos` | the route creates a **new** `TodoBloc` (factory) → `TodosRequested` → `GET /todos?limit=100` |
| Add | bottom sheet → `POST /todos`, the new todo is put first (the API sorts newest first) |
| Tick | optimistic: the checkbox flips before the call, `PATCH /todos/:id` confirms or rolls back |
| Delete (swipe) | optimistic removal, `DELETE /todos/:id`; on failure the todo returns to its exact index |
| Filter | All / Active / Done, computed from the list (`visibleTodos`), never stored |
| Title | `My todos (n left)`, rebuilt only when `activeCount` changes (`BlocSelector`) |
| Pull to refresh | `RefreshIndicator` waits for the first non-`loading` state |
| Any API error | snackbar with `Failure.message`, shown once (`copyWith` never carries `failure` over) |

Event transformers: `restartable()` for the list (a new refresh cancels the previous one),
`sequential()` for add/toggle/delete (writes reach the API in the order the user made them),
and the default `concurrent()` for the filter, which is pure UI state.

## Look and feel

The whole visual identity lives in `lib/core/theme/app_theme.dart`. One seed colour —
`#7C3AED` — feeds `ColorScheme.fromSeed`, so every role (primary, containers, outlines,
surface tints) is derived instead of hard-coded, and a light **and** dark theme come out of
the same code. `MaterialApp` uses `ThemeMode.system`, so the app follows the OS. There is no
theme state to persist yet: adding a `ThemeCubit` later would not touch this file.

Component styles set once in the theme, so pages stay readable:

| Component | Choice |
|---|---|
| Cards | no elevation, hairline outline, 18 px radius, `surfaceContainerLow` |
| Text fields | filled, borderless until focus, then a 1.6 px purple border |
| Buttons | 52 px minimum height, 16 px radius, bold label |
| Filter bar | full-width `SegmentedButton`, selected segment filled purple |
| Checkbox | circular, filled purple when checked |
| FAB | extended "New todo", purple, 18 px radius |
| Snackbar | floating, rounded, inverse surface |
| Bottom sheet | 28 px top radius + drag handle |

Pages only use scheme tokens (`colorScheme.primary`, `onSurfaceVariant`, …), so dark mode needed
no page-level branch. The sign-in/sign-up pages share a purple gradient header (`AuthHeader`),
show/hide password buttons, and keep every validator and bloc call unchanged.

## Tests

```bash
flutter analyze     # No issues found!
flutter test        # 25 tests: 7 auth bloc + 10 todo bloc + 3 route guard + 5 todos page

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

The todos suites:

- `test/features/todos/todo_bloc_test.dart` — the bloc with the real use cases and a mock
  repository: loading/success/failure, title trimming, optimistic toggle and its rollback,
  delete rollback at the same index, filter changes, and the `visibleTodos` / `activeCount`
  getters. The two "Your turn" exercises are included.
- `test/features/todos/todos_page_test.dart` — the page pumped with the real bloc: title count,
  the Active filter, an optimistic tick, a swipe that deletes, and a failed tick that rolls back
  and shows the snackbar.
- `test/integration/todos_api_test.dart` — real HTTP: add/list ordering, a PATCH that sends only
  `completed`, delete + 404 on a second delete, empty title → `ValidationFailure`, and object-level
  authorization (a second account sees nothing, and reading somebody else's todo answers 404).

## Notes

- `ACCESS_TOKEN_TTL` in `todo_api/.env` is `15m`. If you set it very low (for example `20s`) to
  watch the refresh happen, remember to restore it: every token then dies almost immediately and
  the app spends its life refreshing.
- Flutter 3.50 moved the Material widgets to `package:material_ui/material_ui.dart`; this project
  imports that package instead of the deprecated `package:flutter/material.dart` (the guide's
  Lab 4 listings still use `flutter/material.dart`, which now emits a deprecation warning).
- `app_router.dart` reads `sl<TodoBloc>()` inside the route builder, so it imports
  `core/di/injection.dart`. The Lab 3 guard tests therefore register a `TodoBloc` built on a fake
  repository in `setUp`; they assert on `TodosPage` instead of the old "Signed in" text.
- The `/todos` route is now the real page. Nothing else in `core/` or `features/auth/` changed.
- The purple theme arrived *after* the labs: it is presentation only (`core/theme/`,
  `core/widgets/`, auth header, page layouts). No bloc, use case, repository, DI registration or
  route guard was modified, and the 25 unit/widget tests pass untouched.
