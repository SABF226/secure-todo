# Lab 3 — Architecture, réseau et authentification

**Application** : `todo_app` (client Flutter de l'API `todo_api`)
**Objectif du TP** : une application où l'on peut s'inscrire, se connecter, rester connecté après
un redémarrage et se déconnecter — construite de façon à ce que le Lab 4 (les tâches) n'exige
aucune modification de ce qui est écrit ici.

---

## 1. Ce qui a été livré

| Section du guide | Livré | Fichiers |
|---|---|---|
| 3.2 Création du projet | oui | `pubspec.yaml` (13 dépendances) |
| 3.3 Core : configuration, échecs, résultats | oui | `core/config/app_config.dart`, `core/error/failure.dart`, `core/result/result.dart`, `core/network/error_mapper.dart` |
| 3.4 Core : jetons et réseau | oui | `core/storage/token_storage.dart`, `core/network/auth_interceptor.dart`, `core/network/dio_client.dart` |
| 3.5 Auth : domaine | oui | `domain/entities/user.dart`, `domain/repositories/auth_repository.dart`, `domain/usecases/auth_usecases.dart` |
| 3.6 Auth : données | oui | `data/models/user_model.dart`, `data/datasources/auth_remote_data_source.dart`, `data/repositories/auth_repository_impl.dart` |
| 3.7 Auth : BLoC | oui | `presentation/bloc/auth_bloc.dart`, `auth_event.dart`, `auth_state.dart` |
| 3.8 Pages | oui | `presentation/pages/login_page.dart`, `register_page.dart` |
| 3.9 Injection de dépendances | oui | `core/di/injection.dart` |
| 3.10 Navigation + garde de route | oui | `core/router/app_router.dart` |
| 3.11 Assemblage | oui | `main.dart`, `app.dart`, `core/app_bloc_observer.dart` |
| 3.12 Test du BLoC | oui + 2 tests « À vous de jouer » | `test/features/auth/auth_bloc_test.dart` |
| Garde de route (testée) | en plus | `test/features/auth/auth_guard_test.dart` |
| Intégration API réelle | en plus | `test/integration/auth_api_test.dart` |

Total : **23 fichiers Dart** dans `lib/`, **3 fichiers de test**.

---

## 2. Architecture retenue

```
lib/
  main.dart / app.dart
  core/      config  error  result  network  storage  di  router
  features/auth/  domain/  data/  presentation/
```

La règle de dépendance est respectée : `domain/` n'importe ni Flutter, ni Dio, ni JSON ;
`data/` implémente le contrat du domaine ; `presentation/` ne connaît que les cas d'usage.
`core/di/injection.dart` est le seul fichier qui connaisse toutes les couches (composition root).

### Choix structurants

**`Result<T>` scellé plutôt que des exceptions.** `login()` renvoie `Future<Result<User>>`, donc
l'échec est visible dans la signature et le compilateur impose de traiter les deux branches :

```dart
emit(switch (result) {
  Ok(:final value) => Authenticated(value),
  Err(:final failure) => Unauthenticated(failure: failure),
});
```

Les exceptions restent cantonnées à la couche données : `guard()` dans `error_mapper.dart` est le
seul endroit qui convertit `DioException` en `Failure`.

**États scellés.** Quatre états (`AuthInitial`, `AuthLoading`, `Authenticated`,
`Unauthenticated`) au lieu de trois booléens : les combinaisons impossibles (« en chargement ET
authentifié ») ne peuvent pas être construites. `Equatable` fournit l'égalité de valeur, sans
laquelle BLoC n'émettrait pas deux fois le même état et `bloc_test` échouerait partout.

**Rafraîchissement silencieux.** `AuthInterceptor` étend `QueuedInterceptor` : il ajoute
`Authorization: Bearer …`, et sur un 401 il appelle `/auth/refresh`, enregistre la nouvelle paire
et rejoue la requête. Les erreurs sont traitées une par une : si cinq requêtes échouent ensemble,
une seule rafraîchit, les autres constatent que le jeton stocké a changé et rejouent. C'est
indispensable avec la rotation côté API : deux rafraîchissements simultanés avec le même refresh
token révoqueraient toute la famille.

**Garde de route unique.** Aucune page n'appelle `Navigator.push` après un login. La page ajoute
un événement, le BLoC émet `Authenticated`, le routeur est notifié via `refreshListenable` et
`redirect` décide. Une nouvelle page ne peut donc pas « oublier » la protection.

**Déconnexion qui marche hors ligne.** `AuthRepositoryImpl.logout()` efface d'abord l'appareil,
puis prévient le serveur sans attendre le succès.

---

## 3. Écarts assumés par rapport au guide

| Point | Guide | Projet | Raison |
|---|---|---|---|
| Import Material | `package:flutter/material.dart` | `package:material_ui/material_ui.dart` | Flutter 3.50+ marque l'ancien import comme déprécié ; `go_router` 18 dépend déjà de `material_ui`. Sans cela `flutter analyze` n'affiche pas « No issues found! » |
| Route `/todos` | Page `TodosPage` réelle | Écran temporaire « Signed in » + bouton *Sign out* | C'est la consigne du guide pour le Lab 3 (le dossier `features/todos/` arrive au Lab 4) |
| Imports `features/todos` dans `injection.dart` | Présents dans l'extrait | Absents | Le guide demande explicitement de les retirer pour aujourd'hui |
| Versions | flutter_bloc 9, dio 5 | flutter_bloc 9.1.1, dio 5.11.1, go_router 18.1.4, get_it 9.3.0, flutter_secure_storage 11.2.0 | Versions résolues par `pub` sur Flutter 3.50 / Dart 3.14 |

Aucun autre écart : le code des sections 3.3 à 3.11 est repris tel quel, y compris les paramètres
nommés privés (`required this._tokenStorage`), disponibles depuis Dart 3.10.

---

## 4. Vérifications effectuées

### 4.1 Analyse statique

```
$ flutter analyze
Analyzing todo_app...
No issues found! (ran in 22.6s)
```

### 4.2 Tests du BLoC — sans serveur ni téléphone

```
$ flutter test
00:02 +10 ~9: All tests passed!     (9 tests d'intégration ignorés)
```

Sept tests de BLoC : restauration de session, absence de session, login réussi (avec `trim` de
l'email), login refusé, déconnexion, plus les deux tests demandés en fin de section 3.12 —
`AuthRegisterRequested` en échec de validation (avec `fieldErrors`) et `AuthSessionExpired`
depuis un état `Authenticated`.

Trois tests de widget (`test/features/auth/auth_guard_test.dart`) montent le vrai `go_router`
derrière un vrai `AuthBloc` : sans session la garde ouvre `/login`, avec session elle ouvre
`/todos`, et le bouton *Sign out* ramène à `/login` en appelant bien `repository.logout()`.
C'est la partie du TP la plus facile à casser sans s'en apercevoir, donc elle est testée.

### 4.3 Tests d'intégration — vraie API, vrai réseau

`test/integration/auth_api_test.dart` exécute la vraie couche données (Dio + intercepteur +
repository) contre l'API en marche, avec un `TokenStorage` en mémoire :

```
$ flutter test --dart-define=RUN_INTEGRATION=true
00:00 +9: All tests passed!
```

| Test | Ce qu'il prouve |
|---|---|
| `register stores the tokens` | 201, jetons écrits dans le stockage |
| `currentUser restores the session` | `GET /auth/me` avec le jeton stocké |
| `login with a wrong password` | 401 → `UnauthorizedFailure` portant le message de l'API |
| `an already used email` | 409 → `ServerFailure` |
| `a too short password` | 422 → `ValidationFailure` + `fieldErrors['password']` |
| `invalid access token is refreshed silently` | 401 → refresh → rejeu → `Ok`, paire ayant tourné |
| `five concurrent 401s trigger a single refresh` | les 5 requêtes réussissent, 0 session expirée |
| `a rejected refresh token ends the session` | jetons effacés + `onSessionExpired` appelé une fois |
| `logout clears the device` | effacement local même si l'API refuse |

### 4.4 Compilation pour une cible réelle

```
$ flutter build web
✓ Built build/web   (123.3 s)
```

---

## 5. Difficulté rencontrée — et la cause probable des 401 dans Postman

Pendant la mise au point, `todo_api/.env` contenait encore `ACCESS_TOKEN_TTL=20s` (réglage de
l'expérience du Lab 2). Conséquence mesurée : un jeton obtenu par `Register` mourait **20 secondes
plus tard**, donc `Auth → Register` répondait 201 puis `Todos → …` répondait
`401 Invalid or expired access token`.

C'est exactement le symptôme observé dans Postman : les requêtes Auth passaient, les requêtes
Todos échouaient. Le message est trompeur car l'API renvoie volontairement le même texte pour six
causes différentes (jeton expiré, signé avec un autre secret, refresh token utilisé comme access
token, mauvais `aud`, variable non résolue, jeton tronqué).

Correctifs appliqués :

1. `ACCESS_TOKEN_TTL` remis à `15m` (valeur documentée dans `todo_api/README.md`), API redémarrée.
2. La collection Postman rafraîchit désormais la paire automatiquement avant chaque requête
   `/todos` quand `exp` est dépassé.

Leçon transférable : un TTL très court est un bon outil pour observer le rafraîchissement, mais il
faut le remettre à sa valeur nominale — sinon tous les diagnostics pointent vers le mauvais coupable.

### 5.1 Piège des tests de widget avec BLoC

`await bloc.close()` **ne rend jamais la main** dans un `testWidgets` : la zone *fake async* du
framework de test ne draine pas la microtâche attendue par `close()`. Le test se bloque sans
message, et seul le délai global de `flutter test` le tue (« did not complete »). Solution :

```dart
await tester.runAsync(bloc.close);   // async réel, hors de la zone simulée
```

À retenir dès qu'on mélange BLoC et tests de widget.

---

## 6. Points de contrôle du guide

À vérifier à la main avec `flutter run` (l'API doit tourner) :

- [ ] l'app s'ouvre sur l'écran de connexion ;
- [ ] créer un compte mène à l'écran « Signed in » ;
- [ ] un mauvais mot de passe affiche le message de l'API dans un `SnackBar` ;
- [ ] une adresse déjà utilisée affiche le message 409 ;
- [ ] `R` (hot restart) : toujours connecté — grâce aux jetons du Keychain/Keystore ;
- [ ] *Sign out* ramène à la connexion, et `R` y reste ;
- [ ] API arrêtée + tentative de connexion → « Cannot reach the server », pas de crash ;
- [ ] la console affiche une ligne par transition, par exemple
      `AuthLoginRequested: AuthLoading -> Authenticated`.

Commandes utiles :

```bash
cd todo_api && npm run dev
cd todo_app && flutter run                                        # émulateur Android
cd todo_app && flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1          # Chrome
```

---

## 7. Suite

Le Lab 4 ajoute `features/todos/` (entité, repository, BLoC avec mises à jour optimistes,
page et tests). Rien dans `core/` ni dans `features/auth/` ne devrait changer : la route
`/todos` temporaire sera remplacée par `TodosPage`, et les cinq imports `features/todos`
reviendront dans `injection.dart`.
