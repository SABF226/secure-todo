// Lab 1 verification script — run with: node --env-file=.env scripts/verify-lab1.mjs
// Requires the API to be listening on http://localhost:3000 and MongoDB up.
import { SignJWT } from 'jose';

const BASE = process.env.API_BASE ?? 'http://localhost:3000/api/v1';
const email = `verify+${Date.now()}@example.com`;
const password = 'correct-horse-9';

const results = [];
function check(name, pass, detail = '') {
  results.push({ name, pass: !!pass, detail: String(detail).slice(0, 140) });
}

async function call(method, path, body, token, rawBody) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    ...(rawBody !== undefined ? { body: rawBody } : body ? { body: JSON.stringify(body) } : {}),
  });
  let json = null;
  try { json = await res.json(); } catch {}
  return { status: res.status, json, headers: res.headers };
}

// ---------- 1. Public surface ----------
let r;
// /health lives outside /api/v1
const health = await fetch('http://localhost:3000/health').then(async x => ({ status: x.status, json: await x.json() }));
check('GET /health -> 200 ok', health.status === 200 && health.json?.status === 'ok', `status ${health.status}`);

const nf = await fetch('http://localhost:3000/nope').then(async x => ({ status: x.status, json: await x.json() }));
check('Unknown route -> 404 JSON envelope', nf.status === 404 && nf.json?.error?.code === 'NOT_FOUND', `${nf.status} ${nf.json?.error?.code}`);

// ---------- 2. Registration ----------
r = await call('POST', '/auth/register', { name: 'Ada Lovelace', email, password, role: 'admin' });
check('Register -> 201', r.status === 201, `status ${r.status}`);
const dto = r.json?.data?.user ?? {};
check('Register returns user + both tokens',
  dto.id && dto.name === 'Ada Lovelace' && r.json?.data?.accessToken && r.json?.data?.refreshToken,
  Object.keys(r.json?.data ?? {}).join(','));
check('Extra field "role" dropped from response', !('role' in dto), JSON.stringify(Object.keys(dto)));
check('No password material in any response', !/password/i.test(JSON.stringify(r.json)), '');
const accessToken = r.json?.data?.accessToken;
const refreshToken = r.json?.data?.refreshToken;
check('Access token is a 3-part JWT', accessToken?.split('.').length === 3, '');
const payload = JSON.parse(Buffer.from(accessToken.split('.')[1], 'base64url').toString());
check('JWT sub = user id', payload.sub === dto.id, `sub ${payload.sub} vs id ${dto.id}`);
check('JWT has exp/iss/aud', !!payload.exp && payload.iss === 'todo-api' && payload.aud === 'todo-app', `iss=${payload.iss} aud=${payload.aud}`);

r = await call('POST', '/auth/register', { name: 'Ada Again', email, password });
check('Duplicate email -> 409 CONFLICT', r.status === 409 && r.json?.error?.code === 'CONFLICT', `${r.status} ${r.json?.error?.code}`);

r = await call('POST', '/auth/register', { name: 'A', email: 'bad-email', password: 'short' });
check('Invalid email + short name/password -> 422',
  r.status === 422 && r.json?.error?.code === 'VALIDATION_ERROR',
  `${r.status} ${JSON.stringify(r.json?.error?.details)}`);
check('422 details names each field', !!r.json?.error?.details?.email && !!r.json?.error?.details?.password && !!r.json?.error?.details?.name,
  Object.keys(r.json?.error?.details ?? {}).join(','));

// ---------- 3. Login ----------
r = await call('POST', '/auth/login', { email, password });
check('Login -> 200 with tokens', r.status === 200 && !!r.json?.data?.accessToken, `status ${r.status}`);
const loginRefresh = r.json?.data?.refreshToken;

r = await call('POST', '/auth/login', { email, password: 'wrong-password' });
const wrongPw = { status: r.status, msg: r.json?.error?.message };
check('Wrong password -> 401', r.status === 401, `${r.status} ${r.json?.error?.code}`);

r = await call('POST', '/auth/login', { email: 'nobody@example.com', password: 'whatever1' });
const unknown = { status: r.status, msg: r.json?.error?.message };
check('Unknown email -> 401', r.status === 401, `${r.status}`);
check('Same message for unknown email / wrong password (no user enumeration)',
  wrongPw.msg === unknown.msg, `"${wrongPw.msg}"`);

// ---------- 4. Protected route ----------
r = await call('GET', '/auth/me');
check('/auth/me no header -> 401', r.status === 401 && r.json?.error?.code === 'UNAUTHORIZED', `${r.status}`);
r = await call('GET', '/auth/me', null, accessToken);
check('/auth/me valid token -> 200 + correct email', r.status === 200 && r.json?.data?.email === email, `${r.status}`);
r = await call('GET', '/auth/me', null, accessToken.slice(0, -2) + 'xx');
check('/auth/me tampered token -> 401', r.status === 401, `${r.status}`);

const expired = await new SignJWT()
  .setProtectedHeader({ alg: 'HS256' })
  .setSubject(dto.id)
  .setIssuer('todo-api')
  .setAudience('todo-app')
  .setIssuedAt(Math.floor(Date.now() / 1000) - 60)
  .setExpirationTime(Math.floor(Date.now() / 1000) - 30)
  .sign(new TextEncoder().encode(process.env.JWT_ACCESS_SECRET));
r = await call('GET', '/auth/me', null, expired);
check('/auth/me expired token -> 401', r.status === 401, `${r.status}`);

const wrongKey = await new SignJWT({ sub: dto.id })
  .setProtectedHeader({ alg: 'HS256' })
  .setIssuer('todo-api')
  .setAudience('todo-app')
  .setExpirationTime('15m')
  .sign(new TextEncoder().encode('x'.repeat(48)));
r = await call('GET', '/auth/me', null, wrongKey);
check('/auth/me token signed with wrong key -> 401', r.status === 401, `${r.status}`);

// ---------- 5. Malformed body ----------
r = await call('POST', '/auth/login', undefined, undefined, '{"email":');
check('Malformed JSON -> 400 BAD_REQUEST', r.status === 400 && r.json?.error?.code === 'BAD_REQUEST', `${r.status} ${r.json?.error?.code}`);

// ---------- 6. Refresh rotation & reuse ----------
r = await call('POST', '/auth/refresh', { refreshToken: loginRefresh });
check('Refresh -> 200 new pair', r.status === 200 && !!r.json?.data?.refreshToken && r.json.data.refreshToken !== loginRefresh, `status ${r.status}`);
const rotated = r.json?.data?.refreshToken;

r = await call('POST', '/auth/refresh', { refreshToken: loginRefresh });
check('Replay used refresh token -> 401', r.status === 401, `${r.status}`);
r = await call('POST', '/auth/refresh', { refreshToken: rotated });
check('Reuse detection revokes the family (newest token dead)', r.status === 401, `${r.status}`);
r = await call('POST', '/auth/refresh', { refreshToken: 'not-a-real-token' });
check('Garbage refresh token -> 401', r.status === 401, `${r.status}`);

// ---------- 7. Logout ----------
r = await call('POST', '/auth/login', { email, password });
const logoutRefresh = r.json?.data?.refreshToken;
const logoutAt = r.json?.data?.accessToken;
r = await call('POST', '/auth/logout', { refreshToken: logoutRefresh });
check('Logout -> 204 No Content', r.status === 204, `${r.status}`);
r = await call('POST', '/auth/refresh', { refreshToken: logoutRefresh });
check('Refresh after logout -> 401 (family revoked)', r.status === 401, `${r.status}`);
r = await call('GET', '/auth/me', null, logoutAt);
check('Access token still valid until it expires (stateless JWT)', r.status === 200, `${r.status} (expected by design)`);

// ---------- 8. Rate-limit headers ----------
r = await call('POST', '/auth/login', { email, password });
const rl = r.headers.get('ratelimit');
check('Login response carries rate-limit headers', !!rl, rl ?? 'missing');

// ---------- Report ----------
const failed = results.filter(x => !x.pass);
for (const x of results) {
  console.log(`${x.pass ? 'PASS' : 'FAIL'}  ${x.name}${x.detail ? `  [${x.detail}]` : ''}`);
}
console.log(`\n${results.length - failed.length}/${results.length} passed — ${failed.length ? 'FAILURES' : 'ALL PASSED'}`);
process.exit(failed.length ? 1 : 0);
