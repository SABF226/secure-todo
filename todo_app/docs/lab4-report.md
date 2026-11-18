# Lab 4 — La fonctionnalité « tâches »

**Application** : `todo_app` (client Flutter de l'API `todo_api`)
**Objectif du TP** : lister, ajouter, cocher et supprimer des tâches avec une interface instantanée,
et prouver par des tests que la logique est juste. Observation attendue : **rien** dans `core/` ni
dans `features/auth/` n'a besoin de changer.

---

## 1. Ce qui a été livré

| Section du guide | Livré | Fichiers |
|---|---|---|
| 4.1 Domaine | oui | `domain/entities/todo.dart`, `domain/repositories/todo_repository.dart`, `domain/usecases/todo_usecases.dart` |
| 4.2 Données | oui | `data/models/todo_model.dart`, `data/datasources/todo_remote_data_source.dart`, `data/repositories/todo_repository_impl.dart` |
| 4.3 TodoBloc | oui | `presentation/bloc/todo_bloc.dart`, `todo_event.dart`, `todo_state.dart` |
| 4.4 Interface | oui | `presentation/pages/todos_page.dart`, `widgets/todo_tile.dart`, `widgets/add_todo_sheet.dart` |
| 4.5 Câblage | oui | `core/di/injection.dart` (6 singletons + 1 factory), `core/router/app_router.dart` (route réelle) |
| 4.6 Tests du BLoC | oui + les 2 exercices « Votre tour » | `test/features/todos/todo_bloc_test.dart` |
| Test de la page (en plus) | oui | `test/features/todos/todos_page_test.dart` |
| Intégration API réelle (en plus) | oui | `test/integration/todos_api_test.dart` |
| Mise à jour des tests de garde (Lab 3) | oui | `test/features/auth/auth_guard_test.dart` |

Total : **12 nouveaux fichiers Dart** dans `lib/` (35 au total), **3 fichiers de test** ajoutés.

---

## 2. Choix structurants

### 2.1 `TodoState` : une classe + un `status`, pas des états scellés

`AuthState` est scellé parce que les situations sont exclusives et portent des données différentes.
`TodoState` fait le contraire, volontairement : **l'écran garde ses données pendant qu'il se passe
autre chose**. Pendant un *pull-to-refresh*, la liste doit rester visible alors que
`status == loading` ; avec des états scellés il faudrait dupliquer la liste dans un
`TodoRefreshing(todos: …)`.

Les données dérivées (`visibleTodos`, `activeCount`) sont des **getters**, jamais des champs : elles
sont recalculées à partir de la source et ne peuvent donc pas être désynchronisées.

Point subtil que le guide signale : `copyWith` **ne reporte pas** `failure`. Chaque nouvel état
repart sans erreur, sinon un `BlocConsumer` qui écoute `current.failure != null` afficherait la même
`SnackBar` à chaque émission.

### 2.2 Mise à jour optimiste

Cocher une case attend le serveur rendrait l'application pâteuse sur un réseau lent. `_onToggled`
émet d'abord l'état modifié, puis appelle l'API, puis :

- succès → émet la version **du serveur** (source de vérité) ;
- échec → remet **l'original** et joint la `Failure`.

Le retour arrière est précis : `_replace` ne remplace que l'élément concerné, car le reste de la
liste a pu changer entre-temps. Même logique pour la suppression, mais avec l'index mémorisé pour
que la tâche restaurée revienne **à sa place**, pas à la fin :

```dart
final index = state.todos.indexWhere((todo) => todo.id == event.todo.id);
...
final restored = [...state.todos]..insert(index.clamp(0, state.todos.length), event.todo);
```

Conséquence intéressante : `bloc_test` n'observe **qu'une** émission dans le cas nominal (optimiste
puis confirmation serveur), parce que BLoC n'émet pas deux états égaux consécutifs — c'est exactement
ce que documente le test « updates the UI immediately ».

### 2.3 Transformateurs d'événements

| Événement | Politique | Pourquoi |
|---|---|---|
| `TodosRequested` | `restartable()` | un nouveau rafraîchissement annule le précédent : on veut la vérité la plus récente |
| `TodoAdded`, `TodoToggled`, `TodoDeleted` | `sequential()` | les écritures partent dans l'ordre où l'utilisateur les a faites ; deux `PATCH` sur la même tâche ne peuvent pas se croiser |
| `TodoFilterChanged` | défaut (`concurrent()`) | état d'interface pur, aucun appel réseau |

### 2.4 Reconstruire le moins possible

- `BlocSelector<TodoBloc, TodoState, int>` sur le titre : cocher une tâche ne reconstruit pas la
  `AppBar` si le compteur ne change pas.
- `context.select` sur la barre de filtres ; `context.read` dans les callbacks ;
  `BlocConsumer` avec `listenWhen` pour la `SnackBar` (effet unique) et un `builder` pur.

### 2.5 Rien à changer ailleurs

Seules deux lignes de `core/` ont bougé, et uniquement pour **brancher** le nouveau module :
six `registerLazySingleton` + un `registerFactory<TodoBloc>` dans `injection.dart`, et la route
`/todos` qui construit désormais `TodosPage` derrière un `BlocProvider`. `features/auth/`,
`result.dart`, `failure.dart`, `error_mapper.dart`, `auth_interceptor.dart` et les pages de
connexion sont inchangés : c'est la démonstration que l'architecture du Lab 3 tenait sa promesse.

`TodoBloc` est enregistré en **factory** (et non en singleton) : chaque ouverture de la page crée
un bloc neuf, donc un nouvel utilisateur ne voit jamais la liste du précédent.

---

## 3. Écarts assumés par rapport au guide

| Point | Guide | Projet | Raison |
|---|---|---|---|
| Import Material | `package:flutter/material.dart` | `package:material_ui/material_ui.dart` | même écart qu'au Lab 3 : l'ancien import est déprécié depuis Flutter 3.47, et `flutter analyze` doit rester à « No issues found! » |
| `app_router.dart` | « restaurer les deux imports » | + `import '../di/injection.dart';` | l'extrait du guide appelle `sl<TodoBloc>()` dans le `builder` : sans cet import le fichier ne compile pas |
| Tests de garde du Lab 3 | — | enregistrent un `TodoBloc` factice (`setUp`) et attendent `TodosPage` au lieu du texte « Signed in » | la route `/todos` n'est plus un écran temporaire : la garde construit maintenant un vrai bloc via le service locator |
| Exercices « Votre tour » | 1 et 2 facultatifs | faits ; le 3 est traité en §5.2 | cf. ci-dessous |
| Tests supplémentaires | non demandés | tests de page + intégration API réelle | le guide ne teste que le BLoC ; la page et la couche données sont les endroits où une erreur passe inaperçue |

Aucun autre écart : le code des sections 4.1 à 4.5 est repris tel quel (y compris `{'title': ?title}`
et les paramètres nommés privés, disponibles depuis Dart 3.10/3.12).

---

## 4. Vérifications effectuées

### 4.1 Analyse statique

```
$ flutter analyze
Analyzing todo_app...
No issues found! (ran in 8.5s)
```

### 4.2 Tests sans serveur ni téléphone

```
$ flutter test
00:10 +25 ~16: All tests passed!      (16 tests d'intégration ignorés)
```

- **10 tests de BLoC** (`todo_bloc_test.dart`) : chargement réussi / en échec, `trim` du titre et
  insertion en tête, bascule optimiste confirmée par le serveur, bascule annulée avec retour
  arrière, suppression + restauration au même index, suppression réussie (exercice 1), suppression
  d'une tâche absente de la liste, changement de filtre (exercice 2), et les getters
  `visibleTodos` / `activeCount`.
- **5 tests de page** (`todos_page_test.dart`) : compteur du titre, filtre *Active*, case cochée
  immédiatement (avant la réponse), glissement qui supprime, et échec qui remet la case **et**
  affiche la `SnackBar` une seule fois.
- **7 tests de BLoC auth + 3 tests de garde** du Lab 3, toujours verts après le câblage.

### 4.3 Tests d'intégration — vraie API, vrai réseau

```
$ flutter test --dart-define=RUN_INTEGRATION=true test/integration
00:03 +16: All tests passed!          (9 auth + 7 todos)
```

`test/integration/todos_api_test.dart` exécute la vraie couche données (`Dio` + intercepteur +
`TodoRepositoryImpl`) contre l'API en marche, avec un `TokenStorage` en mémoire et **un compte neuf
par test** :

| Test | Ce qu'il prouve |
|---|---|
| `add then list` | `POST /todos` puis `GET /todos` renvoient la même tâche |
| `getTodos is newest first` | le tri décroissant de l'API est bien celui attendu par l'écran |
| `updateTodo sends only completed` | les éléments *null-aware* n'écrasent pas le titre |
| `deleteTodo removes… second delete is a 404` | suppression effective, puis `ServerFailure` (l'API répond 404 deux fois, jamais 500) |
| `an empty title is a ValidationFailure` | 422 → `ValidationFailure` + `fieldErrors['title']` |
| `a second account does not see the first account's todos` | liste vide pour un autre compte (le BLoC est recréé, l'API filtre par propriétaire) |
| `a todo belonging to somebody else answers 404` | autorisation au niveau objet : on ne peut pas modifier la tâche d'autrui, même avec son identifiant |

### 4.4 Compilation pour une cible réelle

```
$ flutter build web
✓ Built build/web
```

---

## 5. Difficultés rencontrées

### 5.1 Les tests de garde ont cassé au moment du câblage

C'est le seul « effet de bord » du Lab 4, et il est instructif. `auth_guard_test.dart` monte le
**vrai** routeur : dès que `/todos` devient `BlocProvider(create: (_) => sl<TodoBloc>(), …)`, le
test échoue avec `GetIt: Object/factory with type TodoBloc is not registered`. La correction tient
en six lignes de `setUp` : enregistrer un `TodoBloc` construit sur un `MockTodoRepository`
(`getTodos` → `Ok([])`), puis `tearDown(sl.reset)`.

Leçon transférable : un test qui monte le vrai routeur dépend de tout ce que le routeur construit.
C'est acceptable — et même souhaitable — à condition de remplacer uniquement les **frontières**
(réseau, stockage) par des doublures, ce que fait ce `setUp`.

### 5.2 Exercice 3 : `restartable()` remplacé par `droppable()`

Avec `droppable()`, les tests passent toujours : chaque `blocTest` n'envoie qu'un seul
`TodosRequested`, et la politique ne change que le comportement **entre** deux événements.

Ce qui change pour l'utilisateur : avec `droppable`, un rafraîchissement demandé pendant qu'un
chargement est en cours est **ignoré**. Deux conséquences opposées :

- bon côté : ouvrir la page puis tirer aussitôt vers le bas ne lance pas deux `GET /todos` ;
- mauvais côté : si la première requête est lente (réseau qui rame) et que l'utilisateur retire
  pour rafraîchir, son geste ne fait **rien** — il attend la fin d'une requête qu'il croyait
  remplacée. `restartable()` correspond mieux à l'intention « je veux l'état le plus récent ».

`droppable()` reste le bon choix pour un bouton « Payer » ou un chargement de page suivante, là où
relancer l'action serait nuisible.

### 5.3 `RefreshIndicator` et `firstWhere`

`_refresh` renvoie `bloc.stream.firstWhere((s) => s.status != TodoStatus.loading)` : sans cela, le
spinner du *pull-to-refresh* disparaîtrait immédiatement (le `Future` de `add()` rend la main tout
de suite), alors que la requête est encore en vol. Le filtre ignore aussi l'état `loading` initial
pour ne pas rendre la main avant le début du chargement.

---

## 6. Points de contrôle du guide (section 4.5)

À vérifier à la main avec `flutter run` et l'API en marche. Ce qui peut être vérifié sans
interaction est déjà couvert par les tests ci-dessus ; la liste reste utile pour la démonstration :

- [ ] ajouter trois tâches, en cocher une, en supprimer une par glissement, puis tirer pour
      rafraîchir ;
- [ ] les trois filtres fonctionnent et le titre compte les tâches restantes ;
- [ ] se déconnecter puis créer un second compte : sa liste est vide ;
- [ ] **retour arrière** : arrêter l'API (`Ctrl+C`), cocher une tâche → elle se coche puis se
      décoche avec un message ; redémarrer l'API ;
- [ ] **rafraîchissement silencieux** : `ACCESS_TOKEN_TTL=20s` dans `todo_api/.env`, se reconnecter,
      attendre 30 s, ajouter une tâche → succès ; dans les logs de l'API on voit 401,
      `POST /auth/refresh`, puis la requête rejouée. **Remettre `15m` ensuite.**

Commandes :

```bash
cd todo_api && npm run dev
cd todo_app && flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

---

## 7. Suite possible (projet)

Le guide propose plusieurs pistes ; celles qui s'intègrent le mieux à l'existant :

1. **Modifier une tâche** — l'API (`PATCH /todos/:id`) et `TodoRepository.updateTodo(title: …)`
   existent déjà : il ne manque qu'un événement `TodoRenamed`, un `on<TodoRenamed>` et un
   `TextField` au tap sur la tuile.
2. **Scroll infini** — `meta.totalPages` est déjà renvoyé par l'API ; un événement
   `TodosPageRequested` en `droppable()` évite de lancer deux chargements de suite.
3. **Mode sombre** — un `ThemeCubit` persistant (`hydrated_bloc`) ne touche ni `core/` ni les
   features : c'est un ajout purement présentation.
