# Secure Todo API — Labs 1 & 2

REST API for a per-user todo app, built for the *Advanced Mobile Development* labs.
**Lab 1:** project skeleton, configuration, centralised errors, and authentication
(register, login, refresh-token rotation, logout, profile).
**Lab 2:** the `todos` resource with owner scoping (BOLA defence), integration tests and a
security review.

## Stack

| Tool | Version | Role |
|---|---|---|
| Node.js | ≥ 24 | Runs TypeScript directly (`--env-file`, `--watch`, `--test`) |
| TypeScript | 7.x | Type checking only (`tsc --noEmit`) — no build step |
| Express | 5.3 | HTTP framework; async errors reach the error handler automatically |
| Mongoose | 9.12 | Schemas, validation, queries |
| Zod | 4.6 | Validation of env vars and request bodies; types derived from schemas |
| jose | 6.x | Signs and verifies JWTs (HS256) |
| argon2 | 0.45 | Argon2id password hashing |
| helmet / cors / express-rate-limit | 8 / 2.8 / 8 | Security headers, CORS, brute-force protection |
| pino / pino-http | 10 / 11 | Structured logging with redaction |

## Project structure

```
todo_api/
├── docker-compose.yml        # MongoDB 8 (host port 27018)
├── .env.example              # documented configuration (committed)
├── .env                      # real values incl. JWT secret (git-ignored)
├── .env.test                 # test configuration, database `todo_test`
├── requests.http             # REST Client requests for manual testing
├── scripts/
│   └── verify-lab1.mjs       # end-to-end verification (30 checks)
├── test/
│   ├── helpers.ts            # supertest client, test DB lifecycle, registerUser
│   ├── auth.test.ts          # registration, duplicate, enumeration, refresh replay
│   └── todos.test.ts         # CRUD, validation, pagination, user isolation
├── src/
│   ├── app.ts                # createApp(): middleware pipeline + routes
│   ├── server.ts             # connect DB, listen, graceful shutdown
│   ├── config/
│   │   ├── env.ts            # Zod-validated environment (fail fast)
│   │   └── db.ts             # Mongoose connect / disconnect
│   ├── shared/
│   │   ├── errors.ts         # AppError + factories
│   │   ├── error-handler.ts  # one handler for every error
│   │   ├── logger.ts         # pino (pretty in dev, silent in tests)
│   │   └── authenticate.ts   # Bearer guard + currentUserId()
│   ├── types/
│   │   └── express.d.ts      # req.userId typing
│   └── modules/
│       ├── auth/
│       │   ├── user.model.ts           # schema + DTO
│       │   ├── refresh-token.model.ts  # hashed tokens, family, TTL
│       │   ├── auth.schemas.ts         # Zod request schemas
│       │   ├── token.service.ts        # JWT + refresh rotation
│       │   ├── auth.service.ts         # business rules
│       │   ├── auth.controller.ts      # HTTP in/out
│       │   └── auth.routes.ts          # URLs + rate limiting
│       └── todos/
│           ├── todo.model.ts           # schema, compound index, DTO
│           ├── todo.schemas.ts         # create/update/list/id schemas
│           ├── todo.service.ts         # every query scoped by owner
│           ├── todo.controller.ts      # HTTP in/out
│           └── todo.routes.ts          # URLs + authenticate guard
└── docs/
    ├── lab1-report.md        # Lab 1 report (French)
    └── lab2-report.md        # Lab 2 report (French)
```

## Getting started

Prerequisites: Node.js ≥ 24, Docker.

```bash
npm install
cp .env.example .env
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
# paste the output as JWT_ACCESS_SECRET in .env

docker compose up -d        # MongoDB on http://127.0.0.1:27018
npm run dev                 # API on http://localhost:3000
curl http://localhost:3000/health
```

> **Port note:** MongoDB is mapped to host port **27018** in this environment because port
> 27017 is already used by another local container. If 27017 is free on your machine, change
> the mapping in `docker-compose.yml` and `MONGO_URI` in `.env` back to `27017`.

### Environment variables

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `NODE_ENV` | no | `development` | `development` / `test` / `production` |
| `PORT` | no | `3000` | HTTP port |
| `MONGO_URI` | **yes** | — | MongoDB connection string |
| `JWT_ACCESS_SECRET` | **yes** (≥ 32 chars) | — | Signs access tokens |
| `ACCESS_TOKEN_TTL` | no | `15m` | Access-token lifetime |
| `REFRESH_TOKEN_TTL_DAYS` | no | `30` | Refresh-token lifetime |
| `CORS_ORIGIN` | no | `*` | Allowed origin (Flutter web) |

Invalid or missing variables stop the process at boot and name the culprit.

### Scripts

| Script | Command | Purpose |
|---|---|---|
| `npm run dev` | `node --env-file=.env --watch src/server.ts` | Development server with reload |
| `npm start` | `node --env-file=.env src/server.ts` | Production-style start |
| `npm run typecheck` | `tsc --noEmit` | Type checking |
| `npm test` | `node --env-file=.env.test --test ...` | Integration tests (real HTTP, `todo_test` database) |

The test configuration lives in `.env.test`. The helper refuses to run if `MONGO_URI` does not
end with `_test`, so a mistyped command can never wipe the development database.

## API

Base URL: `/api/v1`. All responses are JSON; errors always share one envelope.

### Endpoints

| Method | Path | Auth | Body | Success | Errors |
|---|---|---|---|---|---|
| GET | `/health` | — | — | `200 {status, uptime}` | — |
| POST | `/api/v1/auth/register` | — | `{name, email, password}` | `201 {data: {user, accessToken, refreshToken}}` | `409` email taken · `422` invalid input |
| POST | `/api/v1/auth/login` | — | `{email, password}` | `200 {data: {user, accessToken, refreshToken}}` | `401` bad credentials |
| POST | `/api/v1/auth/refresh` | — | `{refreshToken}` | `200 {data: {accessToken, refreshToken}}` | `401` invalid/used/expired |
| POST | `/api/v1/auth/logout` | — | `{refreshToken}` | `204` | `422` invalid body |
| GET | `/api/v1/auth/me` | Bearer | — | `200 {data: user}` | `401` |
| GET | `/api/v1/todos?page=1&limit=20&completed=true` | Bearer | — | `200 {data: todo[], meta: {page, limit, total, totalPages}}` | `401` · `422` bad query |
| POST | `/api/v1/todos` | Bearer | `{title, dueDate?}` | `201 {data: todo}` | `401` · `422` |
| GET | `/api/v1/todos/:id` | Bearer | — | `200 {data: todo}` | `401` · `404` · `422` malformed id |
| PATCH | `/api/v1/todos/:id` | Bearer | any of `{title, completed, dueDate}` | `200 {data: todo}` | `401` · `404` · `422` |
| DELETE | `/api/v1/todos/:id` | Bearer | — | `204` | `401` · `404` · `422` |

`user` in every response is a DTO: `{id, name, email, createdAt}` — never the password hash or
internal fields. `todo` is `{id, title, completed, dueDate, createdAt, updatedAt}` — the `owner`
field never leaves the server.

### Ownership (BOLA defence)

The owner is **never** read from the request. It comes from the verified access token, and every
query in `todo.service.ts` includes it:

```ts
Todo.findOne({ _id: id, owner: ownerId })   // not Todo.findById(id)
```

A todo that belongs to another user is indistinguishable from a todo that does not exist: the
API answers `404` for read, update and delete. A `owner` key in the request body is silently
dropped by the Zod schema, so a client cannot transfer a todo to someone else either.

### Error envelope

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "The request contains invalid data",
             "details": { "email": ["Invalid email address"] } } }
```

| Status | Code | When |
|---|---|---|
| 400 | `BAD_REQUEST` | Malformed JSON body |
| 401 | `UNAUTHORIZED` | Missing/invalid/expired token, bad credentials |
| 404 | `NOT_FOUND` | Unknown route or resource |
| 409 | `CONFLICT` | Email already registered |
| 413 | `PAYLOAD_TOO_LARGE` | Request body above the 100 kB cap |
| 422 | `VALIDATION_ERROR` | Zod rejected the input; `details` maps field → messages |
| 429 | `TOO_MANY_REQUESTS` | Login/register rate limit exceeded |
| 500 | `INTERNAL_ERROR` | Unexpected bug — details stay in the server logs |

### Authentication design

- **Access token** — JWT HS256, 15 minutes, sent as `Authorization: Bearer <token>`.
  Verifier pins algorithm, issuer (`todo-api`) and audience (`todo-app`), so a token signed with
  another algorithm or for another app is rejected even if its signature is valid.
- **Refresh token** — 32 random bytes (base64url), no meaning in itself, **only its SHA-256 hash
  is stored**. Single use: every refresh rotates it. All tokens issued from one login share a
  `family`; replaying a used token revokes the whole family (safe choice when the server cannot
  distinguish the user from a thief).
- **Passwords** — Argon2id, one-way, salt embedded in the hash. Unknown email and wrong password
  return the same 401 message (no account enumeration).
- **Logout** — revokes the refresh-token family. Access tokens remain valid until they expire;
  their short lifetime bounds the exposure.

## Security measures

| Measure | Where |
|---|---|
| **Every todo query filters on `owner` from the token** (BOLA / API1) | `todo.service.ts` |
| `owner` cannot be chosen by the client (Zod strips unknown keys) | `todo.schemas.ts` |
| Argon2id hashing, `passwordHash` with `select: false` | `user.model.ts`, `auth.service.ts` |
| DTOs control what leaves the API | `toUserDto`, `toTodoDto` |
| Zod schemas drop unknown fields (no self-promotion to `admin`) | `auth.schemas.ts` |
| Generic 500; stack traces only in server logs | `error-handler.ts` |
| Helmet headers, CORS, 100 kB body cap | `app.ts` |
| Login/register rate limiting (10 per 15 min in production) | `auth.routes.ts` |
| Page size capped at 100; malformed ids rejected before MongoDB | `todo.schemas.ts` |
| Log redaction of `authorization` and `cookie` headers | `logger.ts` |
| Secrets from environment only; `.env` git-ignored | `.gitignore`, `env.ts` |

Still missing for real production: HTTPS (terminate TLS in front of Node), a restricted
`CORS_ORIGIN`, email verification and password reset, and monitoring.

## Verification

### Automated tests

```bash
npm test          # 9 tests, real HTTP, real test database
```

| Suite | What it proves |
|---|---|
| `auth` | register 201 without password material · duplicate → 409 · unknown email and wrong password return the same 401 · refresh works once, replay revokes the family |
| `todos` | 401 without a token · full CRUD · trimming, defaults, partial PATCH · 422 on empty title, malformed id, empty patch · pagination + `completed` filter · **user isolation: 404 on read/patch/delete of another user's todo** |

Each test starts from an empty database (`beforeEach(resetDatabase)`), so tests never depend on
each other or on their order.

### Manual verification

Through real HTTP (server must be running) — 30 checks from Lab 1:

```bash
node --env-file=.env scripts/verify-lab1.mjs
```

Manual requests for every endpoint, including todos, are in `requests.http` (VS Code REST
Client) or with `curl`:

```bash
curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H 'content-type: application/json' \
  -d '{"name":"Ada","email":"ada@example.com","password":"correct-horse-9"}'
```

### Postman

Import `postman/secure-todo.postman_collection.json` (File → Import). No environment is needed:
every value lives in collection variables, and the tokens are captured automatically.

Run in this order:

| Step | Request | Effect |
|---|---|---|
| 1 | **Auth → Register** | creates a unique account, stores `accessToken` / `refreshToken` |
| 2 | **Todos → Create a todo** | stores `todoId` |
| 3 | List / Get / Patch / Delete | assertions on status and response shape |

The collection-level authorization is already `Bearer {{accessToken}}`, so every todo request
inherits it. **Logout sits in its own folder at the end**, because it revokes the session and
clears the token variables — running it before the todos is what produces
`401 Authentication required`.

A folder-level pre-request script on **Todos** decodes the access token and, when it is missing
or expires within 10 seconds, refreshes the pair automatically. If something still fails,
**Auth → Diagnostic du jeton (console)** prints the token's `sub`, `iss`, `aud`, expiry date and
remaining seconds in the Postman Console, and warns when an environment variable shadows
`accessToken`.

> `401 Invalid or expired access token` means the header was received but the token failed
> verification: expired, signed with another secret (server run with a different `.env`),
> refresh token used instead of the access token, or a literal unresolved `{{accessToken}}`.

Verified by replaying the whole export against the running API: **14/14 requests return the
expected status**.

Database checks (hashes, indexes):

```bash
docker exec -it todo-mongo mongosh todo_dev
```

Expected: unique index on `users.email`, `$argon2id$…` hash, in `refreshtokens` a unique
SHA-256 `tokenHash`, a `family` index and a TTL index on `expiresAt`, and in `todos` a compound
index `{owner: 1, createdAt: -1}`.

Access-token expiry check (the trick from Lab 2, reused in Lab 4): set `ACCESS_TOKEN_TTL=20s`,
log in, wait 20 seconds, call `/auth/me` → `401`. The client must then call `/auth/refresh`
with its refresh token to obtain a new access token. Restore `15m` afterwards.

## Next — Lab 3

The Flutter client: clean architecture (domain / data / presentation), Dio networking,
secure token storage, go_router guards and Bloc-based authentication.
