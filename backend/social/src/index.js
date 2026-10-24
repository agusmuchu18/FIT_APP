'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { SocialIdentity } = require('./social_identity');

initializeApp();
const service = new SocialIdentity(getFirestore(), getAuth());

// Production requires attestation; only the actual local emulator bypasses it.
exports.socialIdentity = onCall({
  region: 'us-central1', maxInstances: 3, timeoutSeconds: 30, memory: '256MiB',
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true',
}, async (request) => {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Iniciá sesión con una cuenta para usar funciones sociales.');
  }
  // A token minted before deletion/disablement must not keep social access.
  try {
    const user = await getAuth().getUser(request.auth.uid);
    if (user.disabled || (user.tokensValidAfterTime &&
        request.auth.token.auth_time * 1000 < new Date(user.tokensValidAfterTime).getTime())) {
      throw new Error('disabled-or-revoked');
    }
  } catch {
    throw new HttpsError('unauthenticated', 'La cuenta no está disponible. Volvé a iniciar sesión.');
  }
  return service.execute(request.auth.uid, request.data);
});
