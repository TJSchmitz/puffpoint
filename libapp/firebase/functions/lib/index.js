import * as admin from 'firebase-admin';
import fetch from 'node-fetch';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onObjectFinalized } from 'firebase-functions/v2/storage';
admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();
export const setRole = onCall(async (request) => {
    if (!request.auth)
        throw new HttpsError('unauthenticated', 'Auth required');
    const requesterUid = request.auth.uid;
    const requester = await admin.auth().getUser(requesterUid);
    const reqClaims = requester.customClaims || {};
    if (!reqClaims['admin']) {
        throw new HttpsError('permission-denied', 'Admin only');
    }
    const { uid, role, value } = request.data;
    const user = await admin.auth().getUser(uid);
    const newClaims = { ...(user.customClaims || {}), [role]: !!value };
    await admin.auth().setCustomUserClaims(uid, newClaims);
    return { ok: true, claims: newClaims };
});
export const nominatimSearch = onCall(async (request) => {
    const q = request.data?.q?.trim();
    const limit = Math.min(Number(request.data?.limit ?? 5), 5);
    if (!q)
        return [];
    const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)}&format=json&limit=${limit}`;
    const res = await fetch(url, {
        headers: {
            'User-Agent': 'puffpoint/1.0 (+support@puffpoint.app) Functions/Node',
            'Accept-Language': 'de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7',
            'Cache-Control': 'max-age=3600',
        },
    });
    const json = await res.json();
    return json;
});
export const moderatePhoto = onCall(async (request) => {
    if (!request.auth)
        throw new HttpsError('unauthenticated', 'Auth required');
    const uid = request.auth.uid;
    const user = await admin.auth().getUser(uid);
    const claims = user.customClaims || {};
    if (!claims['admin'] && !claims['mod'])
        throw new HttpsError('permission-denied', 'Mod/Admin only');
    const { photoId, action } = request.data;
    const photoRef = db.collection('spotPhotos').doc(photoId);
    const snap = await photoRef.get();
    if (!snap.exists)
        throw new HttpsError('not-found', 'Photo not found');
    const photo = snap.data();
    if (action === 'approve') {
        const srcPath = photo.storagePath;
        const destPath = `spots/${photo.spotId}/${srcPath.split('/').pop()}`;
        await copyStorageObject(srcPath, destPath);
        const thumbPath = await generateThumbnail(destPath);
        await photoRef.update({
            storagePath: destPath,
            thumbPath,
            'moderation.status': 'approved',
            'moderation.reason': null,
        });
        // best-effort cleanup of tmp source
        await deleteStorageObject(srcPath).catch(() => undefined);
    }
    else {
        await photoRef.update({ 'moderation.status': 'rejected', 'moderation.reason': 'Rejected by admin' });
    }
    return { ok: true };
});
export const onPhotoUploaded = onObjectFinalized(async (event) => {
    const filePath = event.data.name;
    if (!filePath)
        return;
    // Only act on tmp uploads. Metadata linking to spot is in Firestore doc
    if (!filePath.startsWith('tmp/'))
        return;
    // No-op here; moderation flow will move/copy after approval.
});
async function copyStorageObject(srcPath, destPath) {
    const bucket = storage.bucket();
    await bucket.file(srcPath).copy(bucket.file(destPath));
}
async function deleteStorageObject(path) {
    const bucket = storage.bucket();
    await bucket.file(path).delete({ ignoreNotFound: true });
}
async function generateThumbnail(path) {
    const bucket = storage.bucket();
    const file = bucket.file(path);
    const [exists] = await file.exists();
    if (!exists)
        return path;
    const tmp = `/tmp/${Date.now()}_${path.split('/').pop()}`;
    const tmpOut = `${tmp}_thumb.jpg`;
    await file.download({ destination: tmp });
    const sharp = (await import('sharp')).default;
    await sharp(tmp).resize(500, 500, { fit: 'inside' }).jpeg({ quality: 80 }).toFile(tmpOut);
    const thumbPath = path.replace(/(\.[a-zA-Z0-9]+)?$/, (m) => `_thumb${m || '.jpg'}`);
    await bucket.upload(tmpOut, { destination: thumbPath, contentType: 'image/jpeg' });
    return thumbPath;
}
