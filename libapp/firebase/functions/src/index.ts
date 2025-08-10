import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import fetch from 'node-fetch';

admin.initializeApp();
const db = admin.firestore();

export const setRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const requesterUid = context.auth.uid;
  const requester = await admin.auth().getUser(requesterUid);
  const reqClaims = requester.customClaims || {};
  if (!reqClaims['admin']) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }
  const { uid, role, value } = data as { uid: string; role: 'admin' | 'mod'; value: boolean };
  const user = await admin.auth().getUser(uid);
  const newClaims = { ...(user.customClaims || {}), [role]: !!value };
  await admin.auth().setCustomUserClaims(uid, newClaims);
  return { ok: true, claims: newClaims };
});

export const nominatimSearch = functions.https.onCall(async (data) => {
  const q = (data?.q as string | undefined)?.trim();
  const limit = Math.min(Number(data?.limit ?? 5), 5);
  if (!q) return [];
  const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)}&format=json&limit=${limit}`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'puffpoint/0.1 (contact: support@puffpoint.app)',
      'Accept-Language': 'de,en;q=0.8',
      'Cache-Control': 'max-age=3600',
    },
  });
  const json = await res.json();
  return json;
});

export const moderatePhoto = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  const uid = context.auth.uid;
  const user = await admin.auth().getUser(uid);
  const claims = user.customClaims || {};
  if (!claims['admin'] && !claims['mod']) throw new functions.https.HttpsError('permission-denied', 'Mod/Admin only');

  const { photoId, action } = data as { photoId: string; action: 'approve' | 'reject' };
  const photoRef = db.collection('spotPhotos').doc(photoId);
  const snap = await photoRef.get();
  if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Photo not found');
  const photo = snap.data()!;

  if (action === 'approve') {
    // Stub: simulate approve by setting approved and moving path under spots/{spotId}
    const srcPath = photo.storagePath as string;
    const destPath = `spots/${photo.spotId}/${srcPath.split('/').pop()}`;
    // NOTE: In real impl, copy in Storage and generate thumb
    await photoRef.update({
      storagePath: destPath,
      'moderation.status': 'approved',
      'moderation.reason': null,
    });
  } else {
    await photoRef.update({ 'moderation.status': 'rejected', 'moderation.reason': 'Rejected by admin' });
  }

  return { ok: true };
});