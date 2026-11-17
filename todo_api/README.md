# Secure Todo API — Lab 1

REST API for a per-user todo app, built for the *Advanced Mobile Development* labs.
**Lab 1 scope:** project skeleton, configuration, centralised errors, and authentication
(register, login, refresh-token rotation, logout, profile). The `todos` resource arrives in Lab 2.

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
├── requests.http             # REST Client requests for manual testing
├── scripts/
│   └── verify-lab1.mjs       # end-to-end verification (30 checks)
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
│       └── auth/
│           ├── user.model.ts           # schema + DTO
│           ├── refresh-token.model.ts  # hashed tokens, family, TTL
│           ├── auth.schemas.ts         # Zod request schemas
│           ├── token.service.ts        # JWT + refresh rotation
│           ├── auth.service.ts         # business rules
│           ├── auth.controller.ts      # HTTP in/out
│           └── auth.routes.ts          # URLs + rate limiting
└── docs/
    └── lab1-report.md        # lab report (French)
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
| `npm test` | `node --env-file=.env.test --test ...` | Automated tests (added in Lab 2) |

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

`user` in every response is a DTO: `{id, name, email, createdAt}` — never the password hash or
internal fields.

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

## Security measures in Lab 1

| Measure | Where |
|---|---|
| Argon2id hashing, `passwordHash` with `select: false` | `user.model.ts`, `auth.service.ts` |
| DTOs control what leaves the API | `toUserDto` |
| Zod schemas drop unknown fields (no self-promotion to `admin`) | `auth.schemas.ts` |
| Generic 500; stack traces only in server logs | `error-handler.ts` |
| Helmet headers, CORS, 100 kB body cap | `app.ts` |
| Login/register rate limiting (10 per 15 min in production) | `auth.routes.ts` |
| Log redaction of `authorization` and `cookie` headers | `logger.ts` |
| Secrets from environment only; `.env` git-ignored | `.gitignore`, `env.ts` |

## Verification

Manual, through real HTTP (server must be running):

```bash
node --env-file=.env scripts/verify-lab1.mjs
```

Covers 30 checks: registration, duplicate, validation, login, enumeration, `/me` (missing,
tampered, expired, wrong-key tokens), malformed JSON, refresh rotation, reuse detection, logout,
and rate-limit headers. Latest run: **30/30 passed**.

Manual requests are in `requests.http` (VS Code REST Client) or with `curl`:

```bash
curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H 'content-type: application/json' \
  -d '{"name":"Ada","email":"ada@example.com","password":"correct-horse-9"}'
```

Database checks (hashes, indexes):

```bash
docker exec -it todo-mongo mongosh todo_dev
```

Expected: unique index on `users.email`, `$argon2id$…` hash, and in `refreshtokens` a unique
SHA-256 `tokenHash`, a `family` index and a TTL index on `expiresAt`.

## Next — Lab 2

- `todos` resource with **owner scoping** (BOLA defence): every query filtered by the user id
  taken from the token.
- supertest tests through HTTP, including "user B cannot read/modify/delete user A's todo".
- Security review against the OWASP API risks.
