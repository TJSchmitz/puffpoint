import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:async/async.dart';
import '../models/list_models.dart';

final listsCollectionProvider = Provider<CollectionReference<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('lists');
});

final userListsStreamProvider = StreamProvider<List<SpotList>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final coll = ref.watch(listsCollectionProvider);
  if (uid == null) {
    return const Stream.empty();
  }
  final owned = coll.where('ownerId', isEqualTo: uid).snapshots();
  final memberView = coll.where('members.$uid', isEqualTo: 'view').snapshots();
  final memberEdit = coll.where('members.$uid', isEqualTo: 'edit').snapshots();
  return StreamZip([owned, memberView, memberEdit]).map((snaps) {
    final docs = <String, SpotList>{};
    for (final snap in snaps) {
      for (final d in snap.docs) {
        docs[d.id] = SpotList.fromDoc(d);
      }
    }
    return docs.values.toList();
  });
});

final listItemsStreamProvider = StreamProvider.family<List<ListItem>, String>((ref, listId) {
  final itemsColl = FirebaseFirestore.instance.collection('lists').doc(listId).collection('items');
  return itemsColl.orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs.map((d) => ListItem.fromDoc(listId, d)).toList(),
      );
});

final listsRepoProvider = Provider<ListsRepo>((ref) => ListsRepo(ref));

class ListsRepo {
  final Ref ref;
  ListsRepo(this.ref);

  Future<String> createList(String name) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await ref.read(listsCollectionProvider).add({
      'name': name,
      'ownerId': uid,
      'visibility': 'private',
      'members': {},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> addSpot({required String listId, required String spotId, String? note}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final itemRef = FirebaseFirestore.instance
        .collection('lists')
        .doc(listId)
        .collection('items')
        .doc(spotId);
    await itemRef.set({
      'spotId': spotId,
      'addedBy': uid,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('lists').doc(listId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeSpot({required String listId, required String spotId}) async {
    final itemRef = FirebaseFirestore.instance
        .collection('lists')
        .doc(listId)
        .collection('items')
        .doc(spotId);
    await itemRef.delete();
    await FirebaseFirestore.instance.collection('lists').doc(listId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final invitesApiProvider = Provider<InvitesApi>((ref) => InvitesApi());

class InvitesApi {
  final HttpsCallable _createInvite = FirebaseFunctions.instance.httpsCallable('createInvite');
  final HttpsCallable _redeemInvite = FirebaseFunctions.instance.httpsCallable('redeemInvite');

  Future<String> createInvite({required String listId, required String role}) async {
    final res = await _createInvite.call({'listId': listId, 'role': role});
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['url'] as String;
  }

  Future<void> redeem(String token) async {
    await _redeemInvite.call({'token': token});
  }
}