import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  api,
  closeTestDatabase,
  connectTestDatabase,
  registerUser,
  resetDatabase,
} from './helpers.ts';

describe('auth', () => {
  before(connectTestDatabase);
  beforeEach(resetDatabase);
  after(closeTestDatabase);

  const credentials = {
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    password: 'correct-horse-9',
  };

  it('registers a user and never returns password material', async () => {
    const res = await api.post('/api/v1/auth/register').send(credentials);
    assert.equal(res.status, 201);
    assert.ok(res.body.data.accessToken);
    assert.ok(res.body.data.refreshToken);
    assert.equal(res.body.data.user.email, credentials.email);
    assert.equal(res.body.data.user.passwordHash, undefined);
    assert.doesNotMatch(JSON.stringify(res.body), /passwordHash|correct-horse-9/);
  });

  it('refuses a duplicate email with 409', async () => {
    await api.post('/api/v1/auth/register').send(credentials);
    const res = await api.post('/api/v1/auth/register').send({
      ...credentials,
      name: 'Someone Else',
    });
    assert.equal(res.status, 409);
    assert.equal(res.body.error.code, 'CONFLICT');
  });

  it('answers the same for a wrong password and an unknown email', async () => {
    await api.post('/api/v1/auth/register').send(credentials);

    const wrongPassword = await api
      .post('/api/v1/auth/login')
      .send({ email: credentials.email, password: 'not-the-password' });
    const unknownEmail = await api
      .post('/api/v1/auth/login')
      .send({ email: 'nobody@example.com', password: 'not-the-password' });

    assert.equal(wrongPassword.status, 401);
    assert.equal(unknownEmail.status, 401);
    assert.equal(
      wrongPassword.body.error.message,
      unknownEmail.body.error.message,
    );
  });

  it('uses a refresh token once and revokes the family on replay', async () => {
    const session = await registerUser();

    const first = await api
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken });
    assert.equal(first.status, 200);
    const rotated: string = first.body.data.refreshToken;
    assert.notEqual(rotated, session.refreshToken);

    // The old token was already used: replaying it is treated as theft.
    const replay = await api
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: session.refreshToken });
    assert.equal(replay.status, 401);

    // The whole family is gone, including the token just issued.
    const afterReplay = await api
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rotated });
    assert.equal(afterReplay.status, 401);
  });
});
