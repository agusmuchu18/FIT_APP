'use strict';

const { createHash } = require('node:crypto');
const { FieldPath, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');

const reserved = new Set(['admin', 'administrator', 'root', 'system', 'support',
  'soporte', 'moderator', 'moderacion', 'fitapp', 'fit_app', 'fitup', 'api', 'help']);
const fail = (code, message) => { throw new HttpsError(code, message); };
const pair = (a, b) => createHash('sha256').update(JSON.stringify([a, b])).digest('hex');
const normalize = (value) => value.normalize('NFKD').replace(/\p{M}/gu, '')
  .toLowerCase().replace(/\s+/g, ' ').trim();
function text(value, max, required = false) {
  if (typeof value !== 'string' || value.length > max || /[\p{Cc}\p{Cf}]/u.test(value)) {
    fail('invalid-argument', 'Revisá el texto ingresado.');
  }
  const result = value.trim().normalize('NFC');
  if (required && !result) fail('invalid-argument', 'Completá los campos obligatorios.');
  return result;
}
function uid(value) {
  if (typeof value !== 'string' || !value || value.length > 128 || value.includes('/')) {
    fail('invalid-argument', 'Identidad no válida.');
  }
  return value;
}
function keys(data, allowed) {
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some((key) => !allowed.includes(key))) {
    fail('invalid-argument', 'Solicitud no válida.');
  }
}
function handle(value) {
  if (typeof value !== 'string') fail('invalid-argument', 'Nombre de usuario no válido.');
  const result = value.normalize('NFKC').toLowerCase();
  if (!/^[a-z0-9_]{3,24}$/.test(result) || reserved.has(result)) {
    fail('invalid-argument', 'Usá de 3 a 24 letras, números o guiones bajos. Ese nombre debe estar disponible.');
  }
  return result;
}
function prefixes(name, username) {
  const words = new Set([normalize(name), ...normalize(name).split(' '), username]);
  const result = new Set();
  for (const word of words) for (let n = 2; n <= Math.min(word.length, 64); n++) result.add(word.slice(0, n));
  return [...result];
}
function profileInput(data) {
  keys(data, ['handle', 'displayName', 'bio', 'link', 'discipline', 'discoverable', 'visibility']);
  const result = {
    handle: handle(data.handle), displayName: text(data.displayName, 80, true),
    bio: text(data.bio ?? '', 160), link: text(data.link ?? '', 300),
    discipline: text(data.discipline ?? '', 60), discoverable: data.discoverable ?? false,
    visibility: data.visibility ?? 'private',
  };
  if (typeof result.discoverable !== 'boolean' || !['private', 'public'].includes(result.visibility)) {
    fail('invalid-argument', 'Revisá la visibilidad del perfil.');
  }
  if (result.link) {
    let url;
    try { url = new URL(result.link); } catch { fail('invalid-argument', 'Enlace no válido.'); }
    if (url.protocol !== 'https:' || url.username || url.password) fail('invalid-argument', 'Usá un enlace HTTPS sin credenciales.');
  }
  return result;
}
function projection(profile, relationship = 'none', owner = false) {
  const countsVisible = owner || profile.visibility === 'public' || relationship === 'accepted';
  return {
    uid: profile.uid, handle: profile.handle, displayName: profile.displayName,
    bio: countsVisible ? profile.bio : '', link: countsVisible ? profile.link : '',
    discipline: countsVisible ? profile.discipline : '',
    visibility: profile.visibility, relationship,
    followerCount: countsVisible ? profile.followerCount : null,
    followingCount: countsVisible ? profile.followingCount : null,
    ...(owner ? { discoverable: profile.discoverable } : {}),
  };
}

class SocialIdentity {
  constructor(db, auth) { this.db = db; this.auth = auth; }
  profile(id) { return this.db.collection('socialProfiles').doc(uid(id)); }
  relation(from, to) { return this.db.collection('socialFollows').doc(pair(from, to)); }
  block(from, to) { return this.db.collection('socialBlocks').doc(pair(from, to)); }
  async available(id) {
    try { return !(await this.auth.getUser(id)).disabled; }
    catch (error) {
      if (error.code === 'auth/user-not-found') return false;
      fail('unavailable', 'No se pudo verificar la disponibilidad del perfil. Reintentá.');
    }
  }
  async activeIds(ids) {
    if (!ids.length) return new Set();
    try {
      const result = await this.auth.getUsers([...new Set(ids)].map(id => ({ uid: id })));
      return new Set(result.users.filter(user => !user.disabled).map(user => user.uid));
    } catch { fail('unavailable', 'No se pudo verificar la disponibilidad de los perfiles. Reintentá.'); }
  }

  async execute(actor, data) {
    uid(actor);
    keys(data, ['action', 'profile', 'target', 'handle', 'query', 'cursor', 'accept', 'type']);
    const allowed = ['saveProfile', 'getProfile', 'search', 'follow', 'unfollow',
      'respond', 'block', 'unblock', 'connections'];
    if (!allowed.includes(data.action)) fail('invalid-argument', 'Acción no válida.');
    await this.quota(actor, ['getProfile', 'search', 'connections'].includes(data.action) ? 'read' : 'write');
    switch (data.action) {
      case 'saveProfile': return this.save(actor, data.profile);
      case 'getProfile': return this.get(actor, data);
      case 'search': return this.search(actor, data);
      case 'follow': case 'unfollow': case 'respond': case 'block': case 'unblock':
        return this.mutateRelation(actor, data);
      case 'connections': return this.connections(actor, data);
    }
  }

  async quota(actor, lane) {
    const ref = this.db.collection('socialQuotas').doc(pair(actor, lane));
    const limit = lane === 'read' ? 90 : 40;
    await this.db.runTransaction(async (tx) => {
      const window = Math.floor(Date.now() / 60000);
      const old = (await tx.get(ref)).data();
      const count = old?.window === window ? old.count : 0;
      if (count >= limit) fail('resource-exhausted', 'Esperá un minuto antes de volver a intentar.');
      tx.set(ref, { window, count: count + 1 });
    });
  }

  async save(actor, input) {
    const clean = profileInput(input), ref = this.profile(actor);
    return this.db.runTransaction(async (tx) => {
      const old = (await tx.get(ref)).data();
      if (old && old.schemaVersion !== 1) fail('failed-precondition', 'Este perfil requiere una versión compatible. Los datos se conservan.');
      const alias = this.db.collection('socialHandles').doc(clean.handle);
      const reservedHandle = (await tx.get(alias)).data();
      if (reservedHandle && reservedHandle.uid !== actor) fail('already-exists', 'Ese nombre de usuario no está disponible.');
      const handleWindow = Math.floor(Date.now() / 86400000);
      let handleChanges = old?.handleWindow === handleWindow ? old.handleChanges : 0;
      if (old && old.handle !== clean.handle && ++handleChanges > 3) {
        fail('resource-exhausted', 'Podés cambiar el nombre de usuario hasta tres veces por día.');
      }
      // All old aliases remain bound to the same immutable UID.
      const result = {
        ...clean, schemaVersion: 1, uid: actor, searchPrefixes: prefixes(clean.displayName, clean.handle),
        followerCount: old?.followerCount ?? 0, followingCount: old?.followingCount ?? 0,
        handleWindow, handleChanges,
        createdAt: old?.createdAt ?? FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      };
      tx.set(alias, { uid: actor }, { merge: true });
      tx.set(ref, result);
      return projection(result, 'self', true);
    });
  }

  async context(actor, target) {
    const [a, b, relation] = await this.db.getAll(this.block(actor, target),
      this.block(target, actor), this.relation(actor, target));
    return { blocked: a.exists || b.exists, relationship: relation.data()?.state ?? 'none' };
  }
  async get(actor, data) {
    let target = data.target;
    if (data.handle !== undefined) {
      const alias = await this.db.collection('socialHandles').doc(handle(data.handle)).get();
      target = alias.data()?.uid;
    }
    if (target === undefined) fail('not-found', 'Perfil no disponible.');
    const profile = (await this.profile(target).get()).data();
    if (!profile) fail('not-found', 'Perfil no disponible.');
    if (profile.schemaVersion !== 1) fail('failed-precondition', 'Este perfil requiere una versión compatible. Los datos se conservan.');
    if (target === actor) return projection(profile, 'self', true);
    if (!await this.available(target)) fail('not-found', 'Perfil no disponible.');
    const context = await this.context(actor, target);
    if (context.blocked || (!profile.discoverable && profile.visibility !== 'public' && context.relationship !== 'accepted')) {
      fail('not-found', 'Perfil no disponible.');
    }
    return projection(profile, context.relationship);
  }

  cursor(raw, binding) {
    if (raw === undefined || raw === null) return null;
    try {
      if (typeof raw !== 'string' || raw.length > 700) throw Error();
      const parsed = JSON.parse(Buffer.from(raw, 'base64url').toString());
      if (parsed.v !== 1 || parsed.binding !== binding) throw Error();
      return uid(parsed.after);
    } catch { fail('invalid-argument', 'La página no es válida. Reiniciá la búsqueda.'); }
  }
  next(after, binding) {
    return Buffer.from(JSON.stringify({ v: 1, after, binding })).toString('base64url');
  }
  async search(actor, data) {
    const query = normalize(text(data.query ?? '', 64).replace(/^@/, ''));
    if (query && query.length < 2) return { items: [], nextCursor: null };
    const binding = JSON.stringify([actor, 'search', query]);
    const after = this.cursor(data.cursor, binding);
    let request = this.db.collection('socialProfiles');
    request = query ? request.where('searchPrefixes', 'array-contains', query) : request.where('visibility', '==', 'public');
    request = request.orderBy(FieldPath.documentId());
    if (after) request = request.startAfter(after);
    const docs = (await request.limit(60).get()).docs, items = [];
    const active = await this.activeIds(docs.map(doc => doc.id));
    let last = null, scanned = 0;
    for (const doc of docs) {
      last = doc.id; scanned++;
      const profile = doc.data();
      if (doc.id === actor || profile.schemaVersion !== 1 || !profile.discoverable || !active.has(doc.id)) continue;
      const context = await this.context(actor, doc.id);
      if (!context.blocked) items.push(projection(profile, context.relationship));
      if (items.length === 20) break;
    }
    return { items, nextCursor: last && (scanned < docs.length || docs.length === 60) ? this.next(last, binding) : null };
  }

  async mutateRelation(actor, data) {
    const target = uid(data.target);
    if (actor === target) fail('invalid-argument', 'No podés realizar esta acción sobre tu propio perfil.');
    if (data.action === 'respond' && typeof data.accept !== 'boolean') fail('invalid-argument', 'Respuesta no válida.');
    if (['follow', 'respond'].includes(data.action) && !await this.available(target)) fail('not-found', 'Perfil no disponible.');
    const ownRef = this.profile(actor), otherRef = this.profile(target);
    const ownBlock = this.block(actor, target), otherBlock = this.block(target, actor);
    const outgoing = this.relation(actor, target), incoming = this.relation(target, actor);
    return this.db.runTransaction(async (tx) => {
      const [ownSnap, otherSnap, blocked, blockedBy, out, inc] = await tx.getAll(ownRef, otherRef, ownBlock, otherBlock, outgoing, incoming);
      const own = ownSnap.data(), other = otherSnap.data();
      if (!own) fail('failed-precondition', 'Primero configurá tu identidad social.');
      if (own.schemaVersion !== 1 || (other && other.schemaVersion !== 1)) fail('failed-precondition', 'Este perfil requiere una versión compatible. Los datos se conservan.');
      const action = data.action;
      if (action === 'unblock') { tx.delete(ownBlock); return { relationship: 'none' }; }
      const deltas = { ownFollowers: 0, ownFollowing: 0, otherFollowers: 0, otherFollowing: 0 };
      const remove = (snapshot, ref, reverse) => {
        if (snapshot.data()?.state === 'accepted') {
          if (reverse) { deltas.ownFollowers--; deltas.otherFollowing--; }
          else { deltas.ownFollowing--; deltas.otherFollowers--; }
        }
        if (snapshot.exists) tx.delete(ref);
      };
      let state = 'none';
      if (action === 'block') {
        tx.set(ownBlock, { from: actor, to: target, createdAt: FieldValue.serverTimestamp() });
        remove(out, outgoing, false); remove(inc, incoming, true); state = 'blocked';
      } else if (action === 'unfollow') {
        remove(out, outgoing, false);
      } else {
        if (!other || blocked.exists || blockedBy.exists) fail('not-found', 'Perfil no disponible.');
        if (action === 'follow') {
          if (!other.discoverable && other.visibility !== 'public' && !out.exists) fail('not-found', 'Perfil no disponible.');
          state = out.data()?.state ?? (other.visibility === 'public' ? 'accepted' : 'pending');
          if (!out.exists) {
            tx.set(outgoing, { from: actor, to: target, state, createdAt: FieldValue.serverTimestamp() });
            if (state === 'accepted') { deltas.ownFollowing++; deltas.otherFollowers++; }
          }
        } else {
          state = inc.data()?.state ?? 'none';
          if (state === 'pending') {
            if (data.accept) {
              tx.update(incoming, { state: 'accepted' }); state = 'accepted';
              deltas.ownFollowers++; deltas.otherFollowing++;
            } else { tx.delete(incoming); state = 'none'; }
          }
        }
      }
      if (deltas.ownFollowers || deltas.ownFollowing) tx.update(ownRef, {
        followerCount: Math.max(0, own.followerCount + deltas.ownFollowers),
        followingCount: Math.max(0, own.followingCount + deltas.ownFollowing),
      });
      if (other && (deltas.otherFollowers || deltas.otherFollowing)) tx.update(otherRef, {
        followerCount: Math.max(0, other.followerCount + deltas.otherFollowers),
        followingCount: Math.max(0, other.followingCount + deltas.otherFollowing),
      });
      return { relationship: state };
    });
  }

  async connections(actor, data) {
    const target = uid(data.target ?? actor), type = data.type ?? 'following';
    if (!['following', 'followers', 'requests'].includes(type)) fail('invalid-argument', 'Lista no válida.');
    if (type === 'requests' && target !== actor) fail('permission-denied', 'Solo podés consultar tus solicitudes.');
    const owner = await this.get(actor, { target });
    if (target !== actor && owner.visibility !== 'public' && owner.relationship !== 'accepted') {
      fail('permission-denied', 'Lista privada.');
    }
    const binding = JSON.stringify([actor, type, target]), after = this.cursor(data.cursor, binding);
    const from = type === 'following';
    let query = this.db.collection('socialFollows')
      .where(from ? 'from' : 'to', '==', target)
      .where('state', '==', type === 'requests' ? 'pending' : 'accepted')
      .orderBy(FieldPath.documentId());
    if (after) query = query.startAfter(after);
    const docs = (await query.limit(60).get()).docs, items = [];
    const active = await this.activeIds(docs.map(doc => doc.data()[from ? 'to' : 'from']));
    let last = null, scanned = 0;
    for (const doc of docs) {
      scanned++; last = doc.id;
      const id = doc.data()[from ? 'to' : 'from'];
      if (!active.has(id)) continue;
      const context = await this.context(actor, id);
      if (context.blocked) continue;
      const profile = (await this.profile(id).get()).data();
      if (profile?.schemaVersion === 1 && (target === actor || id === actor || profile.discoverable || context.relationship === 'accepted')) {
        items.push(projection(profile, context.relationship, actor === id));
      }
      if (items.length === 20) break;
    }
    return { items, nextCursor: last && (scanned < docs.length || docs.length === 60) ? this.next(last, binding) : null };
  }
}

module.exports = { SocialIdentity, normalize, profileInput };
