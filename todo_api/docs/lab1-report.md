# Rapport de laboratoire — Lab 1
## API Todo sécurisée : fondations et authentification

**Cours :** Advanced Mobile Development (Mobile Apps) — Dr Lebian Wilfried NIKIEMA
**Projet :** `secure-todo` — partie A, API Node.js + MongoDB
**Date :** 17 novembre 2026

---

## 1. Objectif

Mettre en service une API REST où un utilisateur peut **s'inscrire**, **se connecter** et recevoir
une **paire de jetons** (access token + refresh token), avec une base de code structurée pour
accueillir la ressource `todos` au Lab 2.

Le Lab 1 couvre les sections 1.1 à 1.9 du guide : squelette du projet, configuration, gestion
centralisée des erreurs, modèles et schémas, service de jetons, service/contrôleur/routes, puis
vérification.

## 2. Environnement

| Outil | Version constatée | Exigence du guide |
|---|---|---|
| Node.js | v24.12.0 | ≥ 24 |
| Docker | 29.8.2 | récent |
| MongoDB (conteneur) | 8.x | 8 |
| TypeScript | 7.x | — |
| VS Code | extensions Dart/Flutter présentes | REST Client recommandé |

**Écart d'environnement :** le port hôte 27017 étant déjà occupé par un autre conteneur local,
MongoDB du laboratoire est exposé sur le port **27018**. `docker-compose.yml` et `MONGO_URI`
ont été modifiés en conséquence ; cela n'affecte aucune étape fonctionnelle du laboratoire.

## 3. Architecture réalisée

```
Requête HTTP
   │
   ├─ helmet → cors → express.json (100 kb) → pino-http
   ├─ /health
   ├─ /api/v1/auth → routes → contrôleur → service → modèles Mongoose → MongoDB
   └─ notFoundHandler → errorHandler (inscrit en dernier)
```

Principes appliqués (cours 3) :

- **Route** : quelle URL, quels gardes — aucune logique.
- **Contrôleur** : valide l'entrée (Zod), appelle le service, choisit le statut HTTP.
- **Service** : les règles métier, sans `req`/`res` — testable isolément.
- **Modèle** : schéma Mongoose et accès à la base.
- **Une seule sortie d'erreur** : tout ce qui est levé aboutit au même gestionnaire.

## 4. Travail réalisé

| Section | Fichiers créés | Points clés |
|---|---|---|
| 1.1 Projet | `package.json`, `tsconfig.json`, `.gitignore` | Node exécute le TypeScript directement ; imports avec extension `.ts` ; `erasableSyntaxOnly` interdit `enum` et les paramètres de constructeur |
| 1.2 MongoDB + config | `docker-compose.yml`, `.env.example`, `.env`, `src/config/env.ts`, `src/shared/logger.ts`, `src/config/db.ts` | Validation Zod de l'environnement au démarrage ; arrêt immédiat si une variable manque ; logs structurés avec rédaction des en-têtes sensibles |
| 1.3 Erreurs | `src/shared/errors.ts`, `src/shared/error-handler.ts` | `AppError` + fabriques ; gestionnaire à 4 paramètres ; Zod → 422, AppError → son statut, JSON invalide → 400, bug → 500 générique + log |
| 1.4 Application/serveur | `src/app.ts`, `src/server.ts` | `createApp()` séparé de `listen` (testabilité) ; arrêt propre SIGINT/SIGTERM |
| 1.6 Modèles et schémas | `user.model.ts`, `refresh-token.model.ts`, `auth.schemas.ts` | Email unique + minuscules ; `passwordHash` en `select:false` ; DTO ; jetons de rafraîchissement hachés SHA-256 avec `family` et index TTL |
| 1.7 Service de jetons | `token.service.ts` | JWT HS256 15 min (algorithme/émetteur/audience épinglés) ; refresh opaque 32 octets, rotation à usage unique, révocation de famille en cas de rejeu |
| 1.8 Service/contrôleur/routes | `auth.service.ts`, `auth.controller.ts`, `auth.routes.ts`, `authenticate.ts`, `types/express.d.ts` | Argon2id ; message identique email inconnu / mot de passe faux ; limitation de débit sur inscription et connexion |
| 1.9 Essai | `requests.http`, `scripts/verify-lab1.mjs` | Scénarios manuels et suite de vérification automatisée |

Deux commits : `API skeleton` puis `Auth: register, login, refresh rotation, profile`.

## 5. Démarche de test

La vérification a été menée **à travers HTTP réel**, sur un serveur lancé avec le fichier `.env`,
avec une base MongoDB réelle. Trois niveaux :

1. **Checkpoints du guide** : inscription 201, doublon 409, mot de passe court 422, `/auth/me`
   401/200, `npm run typecheck` silencieux.
2. **Suite étendue** (`scripts/verify-lab1.mjs`, 30 contrôles) : cas nominaux et cas limites.
3. **Inspection de la base** (`mongosh`) : index, format des hachages, absence de données sensibles.
4. **Test de limitation de débit** : serveur relancé avec `NODE_ENV=production` (limite 10/15 min),
   puis 12 tentatives de connexion.

Jeu de données : comptes générés à la volée (`ada+<timestamp>@example.com`,
`verify+<timestamp>@example.com`), mot de passe `correct-horse-9`.

## 6. Résultats

### 6.1 Suite de vérification — 30/30

| Domaine | Contrôles | Résultat |
|---|---|---|
| Surface publique | `/health` 200 ; route inconnue → 404 `NOT_FOUND` | ✅ |
| Inscription | 201 ; `user` + `accessToken` + `refreshToken` ; champ `role:"admin"` ignoré ; aucun mot de passe dans la réponse | ✅ |
| Jeton d'accès | JWT en 3 parties ; `sub` = id utilisateur ; `iss`, `aud`, `exp` présents | ✅ |
| Doublon / validation | 409 `CONFLICT` ; 422 `VALIDATION_ERROR` avec `details` par champ (`name`, `email`, `password`) | ✅ |
| Connexion | 200 ; mot de passe faux → 401 ; email inconnu → 401 avec **le même message** | ✅ |
| `/auth/me` | sans en-tête → 401 ; valide → 200 ; altéré → 401 ; expiré → 401 ; signé avec une autre clé → 401 | ✅ |
| Corps JSON | JSON malformé → 400 `BAD_REQUEST` | ✅ |
| Rotation | refresh → nouvelle paire ; rejeu de l'ancien jeton → 401 ; le jeton le plus récent est aussi invalidé (famille révoquée) | ✅ |
| Déconnexion | 204 ; refresh ensuite → 401 ; l'access token reste valide jusqu'à expiration (comportement JWT attendu) | ✅ |
| Limitation | en-têtes `ratelimit` présents en développement (100/15 min) | ✅ |

### 6.2 Preuves côté base

```
users       : index unique sur email ; passwordHash = $argon2id$… (97 caractères) ;
              champ role inexistant (le schéma Zod a supprimé la clé inconnue)
refreshtokens : tokenHash unique en SHA-256 hexadécimal (64 caractères) ;
              index family ; index TTL expiresAt (expireAfterSeconds = 0) ;
              aucun jeton en clair
```

### 6.3 Limitation de débit (production)

```
tentatives 1 à 10 → 401
tentative 11      → 429 {"error":{"code":"TOO_MANY_REQUESTS","message":"Try again later"}}
en-tête retry-after : 900
```

### 6.4 Journalisation

Les logs de requête affichent `"authorization": "[Redacted]"` : le jeton n'est jamais écrit dans
les journaux, conformément à la règle « journaliser sans mots de passe ni jetons ».

## 7. Analyse de sécurité (OWASP API)

| Risque | État au Lab 1 |
|---|---|
| API2 — Authentification cassée | Traité : Argon2id, jetons courts, rotation, limitation de débit, messages non énumérants |
| API3 — Autorisation au niveau propriété | Partiellement traité : Zod supprime les champs inconnus (pas d'auto-promotion `admin`) ; les DTO contrôlent la sortie |
| API4 — Consommation de ressources | Partiellement traité : corps limité à 100 kb, limitation sur les routes sensibles |
| API1 — BOLA | **Hors périmètre Lab 1** : à traiter au Lab 2 avec la ressource `todos` (filtrage par propriétaire issu du jeton) |
| API8 — Mauvaise configuration | Traité : helmet, pas de traces de pile vers le client, secrets validés au démarrage |

## 8. Conclusion

Le Lab 1 est **terminé et vérifié** : l'API démarre, refuse de démarrer si la configuration est
invalide, expose une inscription/connexion complètes, émet une paire de jetons conforme au cours,
et se comporte correctement sur les cas d'erreur et les tentatives d'abus testés. La séparation
routes/contrôleur/service/modèle et le gestionnaire d'erreurs unique constituent la base du Lab 2.

**Perspectives :** ressource `todos` avec propriété (BOLA), tests `supertest` sur HTTP réel,
revue de sécurité, puis application Flutter (Labs 3–4).

## Annexe — commandes utiles

```bash
# Démarrer la base et l'API
docker compose up -d
npm run dev

# Vérification complète (serveur démarré)
node --env-file=.env scripts/verify-lab1.mjs

# Vérification des types
npm run typecheck

# Inspection de la base
docker exec -it todo-mongo mongosh todo_dev

# Nettoyage des comptes de test
docker exec -it todo-mongo mongosh todo_dev --quiet \
  --eval 'db.users.deleteMany({email: /^(ada|verify)\+/})'
```
