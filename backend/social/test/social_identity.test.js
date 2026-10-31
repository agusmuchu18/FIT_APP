'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const project = 'demo-fit-social';
// Never run these integration tests against production, even by mistake.
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/);
assert.match(process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '', /^127\.0\.0\.1:\d+$/);
const app = initializeApp({ projectId: project }, 'social-integration-tests');
const db = getFirestore(app);
const root = `http://127.0.0.1:5197/${project}/us-central1/socialIdentity`;
const authRoot = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`;
let users;
async function account() {
  const response = await fetch(authRoot, { method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: `${randomUUID()}@example.test`, password: 'local-test-only-password', returnSecureToken: true }) });
  const result = await response.json();
  assert.equal(response.status, 200, JSON.stringify(result));
  return { uid: result.localId, token: result.idToken };
}
async function call(user, data, expected = null) {
  const response = await fetch(root, { method: 'POST', headers: { 'content-type': 'application/json',
    ...(user ? { authorization: `Bearer ${user.token}` } : {}) }, body: JSON.stringify({ data }) });
  const body = await response.json();
  if (expected) { assert.equal(body.error?.status, expected, JSON.stringify(body)); return body; }
  assert.equal(response.status, 200, JSON.stringify(body));
  return body.result ?? body.data;
}
function profile(username, extra = {}) {
  return { handle: username, displayName: 'Persona de prueba', ...extra };
}
const unique = () => `u${randomUUID().replaceAll('-', '').slice(0, 15)}`;
async function prepare(extraA = {}, extraB = {}) {
  const a = await account(), b = await account(), c = await account();
  await call(a, { action: 'saveProfile', profile: profile(unique(), extraA) });
  await call(b, { action: 'saveProfile', profile: profile(unique(), extraB) });
  await call(c, { action: 'saveProfile', profile: profile(unique()) });
  return { a, b, c };
}
before(async () => { users = await prepare(); });
after(async () => { await db.terminate(); await deleteApp(app); });

test('callable verifies real auth and never trusts a target as the acting user', async () => {
  await call(null, { action: 'getProfile', target: users.a.uid }, 'UNAUTHENTICATED');
  const username = unique();
  const result = await call(users.a, { action: 'saveProfile', target: users.b.uid, profile: profile(username) });
  assert.equal(result.uid, users.a.uid);
  assert.notEqual((await call(users.b, { action: 'getProfile', target: users.b.uid })).handle, username);
  await call(users.a, { action: 'saveProfile', uid: users.b.uid, profile: profile(username) }, 'INVALID_ARGUMENT');
});

test('private opt-out is default and contains no health information', async () => {
  const own = await call(users.a, { action: 'getProfile', target: users.a.uid });
  assert.equal(own.visibility, 'private'); assert.equal(own.discoverable, false);
  await call(users.b, { action: 'getProfile', target: users.a.uid }, 'NOT_FOUND');
  await call(users.b, { action: 'follow', target: users.a.uid }, 'NOT_FOUND');
  assert.deepEqual(Object.keys(own).sort(), ['uid', 'handle', 'displayName', 'bio', 'link', 'discipline',
    'visibility', 'relationship', 'followerCount', 'followingCount', 'discoverable'].sort());
  const page = await call(users.b, { action: 'search', query: own.handle });
  assert.equal(page.items.length, 0);
});

test('normalized handles reserve atomically, reject reserved names, and preserve aliases', async () => {
  const a = await account(), b = await account(), username = unique();
  await call(a, { action: 'saveProfile', profile: profile(username.toUpperCase()) });
  await call(b, { action: 'saveProfile', profile: profile(username) }, 'ALREADY_EXISTS');
  const wide = username.replace(/[a-z0-9]/g, ch => String.fromCharCode(ch.charCodeAt(0) + 0xfee0));
  await call(b, { action: 'saveProfile', profile: profile(wide) }, 'ALREADY_EXISTS');
  for (const name of ['admin', 'ADMIN', 'José', 'ab', 'with space', 'a'.repeat(25)]) {
    await call(b, { action: 'saveProfile', profile: profile(name) }, 'INVALID_ARGUMENT');
  }
  const next = unique();
  await call(a, { action: 'saveProfile', profile: profile(next, { visibility: 'public', discoverable: true }) });
  assert.equal((await call(b, { action: 'getProfile', handle: username })).uid, a.uid);
  await call(b, { action: 'saveProfile', profile: profile(username) }, 'ALREADY_EXISTS');
  const raceHandle = unique();
  const results = await Promise.all([a, b].map(async user => {
    const res = await fetch(root, { method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${user.token}` },
      body: JSON.stringify({ data: { action: 'saveProfile', profile: profile(raceHandle) } }) });
    return res.json();
  }));
  assert.equal(results.filter(r => r.result || r.data).length, 1);
  assert.equal(results.filter(r => r.error?.status === 'ALREADY_EXISTS').length, 1);
});

test('search handles accents/case and excludes blocked and opted-out profiles', async () => {
  const token = unique(), { a, b, c } = await prepare({}, {
    displayName: `Jósé ${token}`, visibility: 'public', discoverable: true,
  });
  let found = await call(a, { action: 'search', query: `JOSE ${token.toUpperCase()}` });
  assert.deepEqual(found.items.map(p => p.uid), [b.uid]);
  assert.deepEqual((await call(a, { action: 'search', query: token })).items.map(p => p.uid), [b.uid]);
  await call(b, { action: 'block', target: a.uid });
  found = await call(a, { action: 'search', query: token }); assert.equal(found.items.length, 0);
  await call(a, { action: 'getProfile', target: b.uid }, 'NOT_FOUND');
  await call(a, { action: 'follow', target: b.uid }, 'NOT_FOUND');
  assert.equal((await call(c, { action: 'search', query: token })).items.length, 1);
});

test('public follow/unfollow is idempotent and concurrent counters stay consistent', async () => {
  const { a, b } = await prepare({}, { visibility: 'public', discoverable: true });
  await Promise.all(Array.from({ length: 6 }, () => call(a, { action: 'follow', target: b.uid })));
  assert.equal((await call(b, { action: 'getProfile', target: b.uid })).followerCount, 1);
  assert.equal((await call(a, { action: 'getProfile', target: a.uid })).followingCount, 1);
  const list = await call(b, { action: 'connections', type: 'followers' });
  assert.deepEqual(list.items.map(p => p.uid), [a.uid]);
  await Promise.all(Array.from({ length: 4 }, () => call(a, { action: 'unfollow', target: b.uid })));
  assert.equal((await call(b, { action: 'getProfile', target: b.uid })).followerCount, 0);
  assert.equal((await call(a, { action: 'getProfile', target: a.uid })).followingCount, 0);
  await call(a, { action: 'follow', target: a.uid }, 'INVALID_ARGUMENT');
});

test('private requests cannot be accepted by a third party and reveal no private metadata', async () => {
  const { a, b, c } = await prepare({}, { discoverable: true, bio: 'Biografía privada', link: 'https://example.test' });
  assert.equal((await call(a, { action: 'getProfile', target: b.uid })).bio, '');
  assert.equal((await call(a, { action: 'follow', target: b.uid })).relationship, 'pending');
  await call(c, { action: 'respond', target: a.uid, accept: true });
  assert.equal((await call(a, { action: 'getProfile', target: b.uid })).relationship, 'pending');
  await call(c, { action: 'connections', target: b.uid, type: 'requests' }, 'PERMISSION_DENIED');
  assert.deepEqual((await call(b, { action: 'connections', type: 'requests' })).items.map(p => p.uid), [a.uid]);
  await call(b, { action: 'respond', target: a.uid, accept: false });
  assert.equal((await call(a, { action: 'getProfile', target: b.uid })).relationship, 'none');
  await call(a, { action: 'follow', target: b.uid });
  await Promise.all([1, 2].map(() => call(b, { action: 'respond', target: a.uid, accept: true })));
  const permitted = await call(a, { action: 'getProfile', target: b.uid });
  assert.equal(permitted.relationship, 'accepted'); assert.equal(permitted.bio, 'Biografía privada');
  assert.equal(permitted.followerCount, 1);
});

test('blocking removes both follow directions; unblock does not restore access', async () => {
  const { a, b } = await prepare({ visibility: 'public', discoverable: true }, { visibility: 'public', discoverable: true });
  await call(a, { action: 'follow', target: b.uid }); await call(b, { action: 'follow', target: a.uid });
  await call(a, { action: 'block', target: b.uid });
  for (const user of [a, b]) {
    const own = await call(user, { action: 'getProfile', target: user.uid });
    assert.equal(own.followerCount, 0); assert.equal(own.followingCount, 0);
  }
  await call(b, { action: 'getProfile', target: a.uid }, 'NOT_FOUND');
  await call(a, { action: 'unblock', target: b.uid });
  assert.equal((await call(b, { action: 'getProfile', target: a.uid })).relationship, 'none');
});

test('privacy reduction is immediate and cursor binding cannot bypass access', async () => {
  const token = unique(), { a, b } = await prepare({}, { displayName: token, visibility: 'public', discoverable: true });
  assert.equal((await call(a, { action: 'search', query: token })).items.length, 1);
  const old = await call(b, { action: 'getProfile', target: b.uid });
  await call(b, { action: 'saveProfile', profile: profile(old.handle, { displayName: token }) });
  await call(a, { action: 'getProfile', target: b.uid }, 'NOT_FOUND');
  assert.equal((await call(a, { action: 'search', query: token })).items.length, 0);
  const forged = Buffer.from(JSON.stringify({ v: 1, binding: 'other user/query', after: b.uid })).toString('base64url');
  await call(a, { action: 'search', query: token, cursor: forged }, 'INVALID_ARGUMENT');
});

test('direct Firestore clients cannot read or write even their social projection or counters', async () => {
  const endpoint = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents/socialProfiles/${users.a.uid}`;
  const headers = { authorization: `Bearer ${users.a.token}`, 'content-type': 'application/json' };
  assert.equal((await fetch(endpoint, { headers })).status, 403);
  assert.equal((await fetch(endpoint, { method: 'PATCH', headers, body: JSON.stringify({ fields: { followerCount: { integerValue: '999' } } }) })).status, 403);
  const privateOther = endpoint.replace(`socialProfiles/${users.a.uid}`, `users/${users.b.uid}/workouts/any`);
  assert.equal((await fetch(privateOther, { headers })).status, 403);
});

test('pagination returns all eligible profiles without duplicates and binds cursors to the viewer', async () => {
  const token = unique(), batch = db.batch(), viewer = await account();
  for (let i = 0; i < 25; i++) {
    const id = `${token}_${String(i).padStart(2, '0')}`;
    await getAuth(app).createUser({ uid: id });
    batch.set(db.collection('socialProfiles').doc(id), {
      schemaVersion: 1, uid: id, handle: id, displayName: token, bio: '', link: '', discipline: '',
      visibility: 'public', discoverable: true, followerCount: 0, followingCount: 0,
      searchPrefixes: [token],
    });
  }
  await batch.commit();
  const first = await call(viewer, { action: 'search', query: token });
  assert.equal(first.items.length, 20); assert.ok(first.nextCursor);
  const second = await call(viewer, { action: 'search', query: token, cursor: first.nextCursor });
  assert.equal(second.items.length, 5); assert.equal(second.nextCursor, null);
  assert.equal(new Set([...first.items, ...second.items].map(p => p.uid)).size, 25);
  await call(users.a, { action: 'search', query: token, cursor: first.nextCursor }, 'INVALID_ARGUMENT');
});

test('anonymous, deleted and disabled accounts cannot invoke social actions', async () => {
  const response = await fetch(authRoot, { method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }) });
  const anonymous = await response.json();
  await call({ token: anonymous.idToken }, { action: 'search' }, 'UNAUTHENTICATED');
  const disabled = await account(), deleted = await account(), revoked = await account();
  await call(disabled, { action: 'saveProfile', profile: profile(unique(), { visibility: 'public', discoverable: true }) });
  await call(deleted, { action: 'saveProfile', profile: profile(unique(), { visibility: 'public', discoverable: true }) });
  await getAuth(app).updateUser(disabled.uid, { disabled: true });
  await getAuth(app).deleteUser(deleted.uid);
  // Auth timestamps have second precision. Cross the boundary before revoking.
  await new Promise(resolve => setTimeout(resolve, 1100));
  await getAuth(app).revokeRefreshTokens(revoked.uid);
  await call(disabled, { action: 'search' }, 'UNAUTHENTICATED');
  await call(deleted, { action: 'search' }, 'UNAUTHENTICATED');
  await call(revoked, { action: 'search' }, 'UNAUTHENTICATED');
  await call(users.a, { action: 'getProfile', target: disabled.uid }, 'NOT_FOUND');
  await call(users.a, { action: 'getProfile', target: deleted.uid }, 'NOT_FOUND');
  await call(users.a, { action: 'follow', target: deleted.uid }, 'NOT_FOUND');
});

test('future profile schemas are preserved without overwriting fields or claiming a new handle', async () => {
  const { a } = await prepare(), ref = db.collection('socialProfiles').doc(a.uid), next = unique();
  const original = { ...(await ref.get()).data(), schemaVersion: 99, futureField: 'keep-me' };
  await ref.set(original);
  await call(a, { action: 'saveProfile', profile: profile(next) }, 'FAILED_PRECONDITION');
  assert.deepEqual((await ref.get()).data(), original);
  assert.equal((await db.collection('socialHandles').doc(next).get()).exists, false);
});

test('search opt-out hides suggestions without revoking a deliberately public identity link', async () => {
  const { a, b } = await prepare({}, { visibility: 'public', discoverable: false });
  const own = await call(b, { action: 'getProfile', target: b.uid });
  assert.equal((await call(a, { action: 'search', query: own.handle })).items.length, 0);
  assert.equal((await call(a, { action: 'getProfile', handle: own.handle })).uid, b.uid);
  assert.equal((await call(a, { action: 'follow', target: b.uid })).relationship, 'accepted');
});
