import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import fetch from 'node-fetch';
import { randomBytes } from 'crypto';
admin.initializeApp();
const db = admin.firestore();
export const setRole = functions.https.onCall(async (req) => {
    if (!req.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    const requesterUid = req.auth.uid;
    const requester = await admin.auth().getUser(requesterUid);
    const reqClaims = requester.customClaims || {};
    if (!reqClaims['admin']) {
        throw new functions.https.HttpsError('permission-denied', 'Admin only');
    }
    const { uid, role, value } = (req.data ?? {});
    if (!uid || (role !== 'admin' && role !== 'mod')) {
        throw new functions.https.HttpsError('invalid-argument', 'uid and role required');
    }
    const user = await admin.auth().getUser(uid);
    const newClaims = { ...(user.customClaims || {}), [role]: !!value };
    await admin.auth().setCustomUserClaims(uid, newClaims);
    return { ok: true, claims: newClaims };
});
export const nominatimSearch = functions.https.onCall(async (req) => {
    const q = req.data?.q?.trim();
    const limit = Math.min(Number(req.data?.limit ?? 5), 5);
    if (!q)
        return [];
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
export const moderatePhoto = functions.https.onCall(async (req) => {
    if (!req.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    const uid = req.auth.uid;
    const user = await admin.auth().getUser(uid);
    const claims = user.customClaims || {};
    if (!claims['admin'] && !claims['mod'])
        throw new functions.https.HttpsError('permission-denied', 'Mod/Admin only');
    const { photoId, action } = (req.data ?? {});
    if (!photoId || (action !== 'approve' && action !== 'reject')) {
        throw new functions.https.HttpsError('invalid-argument', 'photoId and action required');
    }
    const photoRef = db.collection('spotPhotos').doc(photoId);
    const snap = await photoRef.get();
    if (!snap.exists)
        throw new functions.https.HttpsError('not-found', 'Photo not found');
    const photo = snap.data();
    if (action === 'approve') {
        const srcPath = photo.storagePath;
        const destPath = `spots/${photo.spotId}/${srcPath.split('/').pop()}`;
        await photoRef.update({
            storagePath: destPath,
            'moderation.status': 'approved',
            'moderation.reason': null,
        });
    }
    else {
        await photoRef.update({ 'moderation.status': 'rejected', 'moderation.reason': 'Rejected by admin' });
    }
    return { ok: true };
});
export const createInvite = functions.https.onCall(async (req) => {
    if (!req.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    const { listId, role } = (req.data ?? {});
    if (!listId || (role !== 'view' && role !== 'edit')) {
        throw new functions.https.HttpsError('invalid-argument', 'listId and role required');
    }
    const listRef = db.collection('lists').doc(listId);
    const listSnap = await listRef.get();
    if (!listSnap.exists)
        throw new functions.https.HttpsError('not-found', 'List not found');
    const list = listSnap.data();
    const uid = req.auth.uid;
    if (list.ownerId !== uid && (list.members?.[uid] !== 'edit')) {
        throw new functions.https.HttpsError('permission-denied', 'Only owner or editor can invite');
    }
    const today = new Date();
    const ymd = `${today.getUTCFullYear()}-${today.getUTCMonth() + 1}-${today.getUTCDate()}`;
    const counterRef = db.collection('listInviteCounters').doc(`${listId}_${ymd}`);
    const counterSnap = await counterRef.get();
    const count = (counterSnap.exists ? counterSnap.data().count : 0) + 1;
    if (count > 20)
        throw new functions.https.HttpsError('resource-exhausted', 'Invite limit reached');
    await counterRef.set({ count, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    const token = randomBytes(16).toString('hex');
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 1000 * 60 * 60 * 24 * 7));
    const inviteRef = db.collection('listInvites').doc();
    await inviteRef.set({
        listId,
        createdBy: uid,
        role,
        token,
        expiresAt,
        usesRemaining: 5,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const url = `puffpoint://invite?token=${token}`;
    return { token, expiresAt: expiresAt.toDate().toISOString(), url };
});
export const redeemInvite = functions.https.onCall(async (req) => {
    if (!req.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    const { token } = (req.data ?? {});
    if (!token)
        throw new functions.https.HttpsError('invalid-argument', 'token required');
    const inviteSnap = await db.collection('listInvites').where('token', '==', token).limit(1).get();
    if (inviteSnap.empty)
        throw new functions.https.HttpsError('not-found', 'Invite not found');
    const inviteDoc = inviteSnap.docs[0];
    const invite = inviteDoc.data();
    const now = admin.firestore.Timestamp.now();
    if (invite.expiresAt && invite.expiresAt.toMillis() < now.toMillis()) {
        throw new functions.https.HttpsError('failed-precondition', 'Invite expired');
    }
    if (invite.usesRemaining !== undefined && invite.usesRemaining <= 0) {
        throw new functions.https.HttpsError('failed-precondition', 'Invite exhausted');
    }
    const listRef = db.collection('lists').doc(invite.listId);
    const uid = req.auth.uid;
    await db.runTransaction(async (tx) => {
        const listSnap = await tx.get(listRef);
        if (!listSnap.exists)
            throw new functions.https.HttpsError('not-found', 'List missing');
        const list = listSnap.data();
        const members = { ...(list.members || {}) };
        if (list.ownerId === uid) {
            // owner already has access; still decrement token
        }
        else {
            members[uid] = invite.role;
            tx.update(listRef, { members });
        }
        const inviteRef = inviteDoc.ref;
        const uses = (invite.usesRemaining ?? 1) - 1;
        if (uses <= 0) {
            tx.update(inviteRef, { usesRemaining: 0, invalidatedAt: admin.firestore.FieldValue.serverTimestamp() });
        }
        else {
            tx.update(inviteRef, { usesRemaining: uses });
        }
    });
    return { ok: true };
});
