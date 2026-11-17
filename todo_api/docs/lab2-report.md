# Rapport de laboratoire — Lab 2
## Ressource `todos`, propriété des données, tests automatisés et revue de sécurité

**Cours :** Advanced Mobile Development (Mobile Apps) — Dr Lebian Wilfried NIKIEMA
**Projet :** `secure-todo` — partie A, API Node.js + MongoDB
**Date :** 17 novembre 2026

---

## 1. Objectif

Compléter l'API du Lab 1 avec une ressource `todos` où **chaque utilisateur ne gère que ses
propres tâches**, puis prouver ce comportement par des tests d'intégration et le confronter à la
liste OWASP API Top 10.

Le Lab 2 couvre les sections 2.1 à 2.5 du guide : expérimentation de la rotation des jetons,
modèle et schémas, service/contrôleur/routes, tests automatisés, revue de sécurité.

## 2. Environnement

| Outil | Version constatée | Exigence du guide |
|---|---|---|
| Node.js | v24.12.0 | ≥ 24 |
| MongoDB (conteneur) | 8.x, port hôte **27018** | 8 |
| supertest | 7.3.2 | — |
| TypeScript | 7.x | — |

**Écart d'environnement :** le port 27017 étant occupé par un autre conteneur local, `.env.test`
utilise lui aussi le port **27018** :

```dotenv
MONGO_URI=mongodb://127.0.0.1:27018/todo_test
```

Cela ne change rien au laboratoire : la base de test reste distincte (`todo_test`) et le helper
refuse toute base dont le nom ne se termine pas par `_test`.

## 3. Architecture de la ressource

```
app.ts
 └─ /api/v1/todos → todo.routes.ts
      authenticate          (toutes les routes exigent un access token)
      ├─ GET    /          → todo.controller.list     → todo.service.listTodos
      ├─ POST   /          → todo.controller.create   → todo.service.createTodo
      ├─ GET    /:id       → todo.controller.getOne   → todo.service.getTodo
      ├─ PATCH  /:id       → todo.controller.update   → todo.service.updateTodo
      └─ DELETE /:id       → todo.controller.remove   → todo.service.deleteTodo
                                                         └─ Todo (Mongoose)
```

Modèle : `title` (requis, `trim`, 200 car. max), `completed` (défaut `false`), `dueDate`
(défaut `null`), `owner` (ObjectId requis vers `User`), plus `createdAt`/`updatedAt`.

Index composé `{ owner: 1, createdAt: -1 }` : la requête principale (« les todos d'un
utilisateur, du plus récent au plus ancien ») est servie sans parcours de collection.

## 4. Travail réalisé

| Section | Fichiers créés / modifiés | Points clés |
|---|---|---|
| 2.1 Rotation | `requests.http` | Requête `Refresh` ajoutée ; le rejeu d'un jeton déjà utilisé supprime toute la famille (le « claim » est un seul `findOneAndUpdate` atomique avec `usedAt: null`) |
| 2.2 Modèle et schémas | `todo.model.ts`, `todo.schemas.ts` | Index composé ; `todoIdSchema` (24 hex), `createTodoSchema`, `updateTodoSchema` en `.partial()` avec au moins un champ, `listTodosSchema` avec `page`/`limit`/`completed` coercés |
| 2.3 Service/contrôleur/routes | `todo.service.ts`, `todo.controller.ts`, `todo.routes.ts`, `app.ts` | Toutes les requêtes filtrent par `owner` ; `404` si le todo appartient à autrui ; `PATCH` partiel ; `meta` de pagination ; `authenticate` sur tout le routeur |
| 2.4 Tests | `.env.test`, `test/helpers.ts`, `test/todos.test.ts`, `test/auth.test.ts` | Tests d'intégration via HTTP réel, base vidée avant chaque test, garde-fou sur le nom de la base |
| 2.5 Revue de sécurité | (documentation) | Tableau OWASP avec, pour chaque ligne, l'emplacement exact dans le code |

## 5. Démarche de test

1. **Tests automatisés** (`npm test`) : deux suites, exécution séquentielle
   (`--test-concurrency=1`), chaque fichier ouvre et ferme sa connexion, chaque test part d'une
   base vide.
2. **Expérimentation 2.1 (« Your turn »)** : `ACCESS_TOKEN_TTL=20s`, inscription, attente de
   21 s, appel à `/auth/me`, puis `/auth/refresh` et nouvel appel. Le TTL est restauré à `15m`
   ensuite.
3. **Expérimentation 2.3 (« Your turn »)** : deux utilisateurs réels, A crée un todo, B tente de
   le lire, de le modifier et de le supprimer.
4. **Non-régression** : la suite du Lab 1 (`scripts/verify-lab1.mjs`, 30 contrôles) est rejouée
   contre l'API modifiée.
5. **Inspection de la base** : index de la collection `todos`, contenu d'un document.

## 6. Résultats

### 6.1 `npm test` — 9/9

```
▶ auth
  ✔ registers a user and never returns password material
  ✔ refuses a duplicate email with 409
  ✔ answers the same for a wrong password and an unknown email
  ✔ uses a refresh token once and revokes the family on replay
▶ todos
  ✔ requires authentication
  ✔ creates, reads, updates and deletes a todo
  ✔ validates input
  ✔ paginates and filters the list
  ✔ isolates the todos of each user
ℹ tests 9   pass 9   fail 0
```

| Suite | Ce qui est prouvé |
|---|---|
| `auth` | Inscription 201 sans aucun matériel de mot de passe ; doublon → 409 ; email inconnu et mot de passe faux donnent le **même** statut et le **même** message ; refresh à usage unique, rejeu → 401 **et** le jeton issu du premier refresh est refusé aussi |
| `todos` | 401 sans jeton ; CRUD complet ; `title` nettoyé (`trim`), `completed` par défaut à `false` ; `PATCH` partiel sans écraser les autres champs ; 422 sur titre vide, id malformé, patch vide ; pagination (`meta` exact) et filtre `completed` ; **isolation : 404 en lecture, modification et suppression du todo d'autrui** |

### 6.2 Expiration de l'access token (`ACCESS_TOKEN_TTL=20s`)

```
register                                   -> 201
GET /auth/me (jeton expiré, après 21 s)    -> 401 UNAUTHORIZED
POST /auth/refresh                         -> 200 (nouveau access token : true)
GET /auth/me (nouveau jeton)               -> 200
```

**Conclusion :** l'access token est volontairement court ; arrivé à expiration, le client doit
appeler `/auth/refresh` avec son refresh token pour obtenir une nouvelle paire. C'est exactement
le mécanisme que l'application Flutter utilisera au Lab 4 (intercepteur Dio).

### 6.3 Isolation entre utilisateurs (HTTP réel)

```
A crée un todo (avec un champ "owner" visant B) -> 201
   → le champ "owner" est supprimé par Zod : le client ne choisit jamais le propriétaire
B liste ses todos                              -> 200, 0 élément
B lit le todo de A                             -> 404 NOT_FOUND
B modifie le todo de A                         -> 404 NOT_FOUND
B supprime le todo de A                        -> 404 NOT_FOUND
A relit son todo                               -> 200, titre "A private todo"
```

**Trois 404**, conformément à l'exigence du guide. Le todo de A est intact : l'attaquant ne peut
ni le voir, ni le modifier, ni le supprimer, et l'existence de la ressource ne fuit pas.

### 6.4 Base de données

```
todo_dev.todos :
  index  { owner: 1, createdAt: -1 }   name = owner_1_createdAt_-1
  document : { title: "A private todo", completed: false, owner: ObjectId, dueDate: null }
```

Après `npm test`, la base `todo_test` a bien été supprimée par `closeTestDatabase()` : seules
`todo_dev` et les bases système subsistent.

### 6.5 Non-régression Lab 1

```
node --env-file=.env scripts/verify-lab1.mjs
30/30 passed — ALL PASSED
```

### 6.6 Ajout au-delà du guide

En vérifiant le plafond de 100 kb, un corps de 120 kb renvoyait **500 `INTERNAL_ERROR`** : le
`PayloadTooLargeError` de body-parser tombait dans la branche « bug interne ». Le plafond
protégeait bien la mémoire, mais le statut était faux et l'événement était journalisé comme une
erreur serveur. Le gestionnaire d'erreurs distingue désormais ce cas :

```
corps de 120 kb -> 413 PAYLOAD_TOO_LARGE
```

C'est un ajout de durcissement, hors du strict énoncé, qui rend la table des erreurs cohérente
(`400`, `401`, `404`, `409`, `413`, `422`, `429`, `500`).

## 7. Revue de sécurité (OWASP API Top 10)

| Risque | Réponse dans le code | Emplacement |
|---|---|---|
| **API1 — Broken object level authorization** | Chaque requête `todos` filtre sur `owner` issu du jeton ; un todo d'autrui répond 404 comme s'il n'existait pas | `todo.service.ts` lignes 16, 36, 47, 56 |
| **API2 — Broken authentication** | Argon2id ; message identique email inconnu / mot de passe faux ; limitation de débit sur inscription et connexion ; access token court ; refresh tokens à rotation stockés hachés | `auth.service.ts:26,43`, `token.service.ts`, `auth.routes.ts:9-13` |
| **API3 — Broken object property level authorization** | Zod supprime les clés inconnues (`owner`, `role`, `_id`…) ; les DTO choisissent ce qui sort | `todo.schemas.ts`, `toTodoDto`, `toUserDto` |
| **API4 — Unrestricted resource consumption** | `limit` plafonné à 100 ; corps JSON limité à 100 kb ; limitation sur les routes sensibles | `todo.schemas.ts:26`, `app.ts:20`, `auth.routes.ts` |
| **API8 — Security misconfiguration** | Helmet, `X-Powered-By` désactivé, aucune trace de pile dans les réponses, secrets validés au démarrage | `app.ts:17-20`, `error-handler.ts`, `env.ts` |

Attaques concrètement bloquées et vérifiées :

- **Mass assignment** : `POST /todos` avec `{"title":"x","owner":"<id de B>"}` → le todo
  appartient à A (le champ est supprimé silencieusement).
- **Énumération de comptes** : impossible de distinguer un email inconnu d'un mot de passe faux.
- **BOLA par identifiant deviné** : 404 sur lecture, modification et suppression.
- **Épuisement de ressources** : `?limit=1000000` → 422 (plafond 100) ; corps > 100 kb → 413.
- **Injection d'identifiant** : `/todos/123` → 422 avant tout accès à MongoDB.

### Ce qui reste à faire pour la production

HTTPS (terminaison TLS devant Node), `CORS_ORIGIN` restreint, vérification d'email et
réinitialisation de mot de passe, supervision et alerting. Ces points sont hors périmètre du
laboratoire et consignés pour le projet.

## 8. Conclusion

Le Lab 2 est **terminé et vérifié** : la ressource `todos` est complète (CRUD, pagination,
filtre), chaque requête est structurellement liée au propriétaire authentifié, et l'isolation
entre utilisateurs est prouvée par un test automatisé ainsi que par une manipulation HTTP réelle.
`npm test` (9/9) et `npm run typecheck` sont verts, la suite du Lab 1 reste à 30/30.

**Perspectives :** application Flutter (Lab 3 : architecture, réseau, authentification ;
Lab 4 : écrans todos et gestion de l'expiration des jetons).

## Annexe — commandes utiles

```bash
# Base + API
docker compose up -d
npm run dev

# Tests automatisés et vérification des types
npm test
npm run typecheck

# Vérification manuelle du Lab 1 (serveur démarré)
node --env-file=.env scripts/verify-lab1.mjs

# Inspection de la base
docker exec -it todo-mongo mongosh todo_dev

# Nettoyage des comptes et todos de test
docker exec -it todo-mongo mongosh todo_dev --quiet --eval '
  const ids = db.users.find({email: /^(ada|verify|owner|thief)\+/}, {_id: 1}).toArray().map(u => u._id);
  db.todos.deleteMany({owner: {$in: ids}});
  db.users.deleteMany({_id: {$in: ids}});
'
```
