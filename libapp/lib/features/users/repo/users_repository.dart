import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';

final usersCollectionProvider = Provider<CollectionReference<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('users');
});

final currentUserProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(usersCollectionProvider).doc(uid).snapshots().map((doc) {
    if (!doc.exists) return null;
    return UserProfile.fromDoc(doc);
  });
});

final usersRepoProvider = Provider<UsersRepository>((ref) => UsersRepository(ref));

class UsersRepository {
  final Ref ref;
  UsersRepository(this.ref);

  Future<void> ensureCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = ref.read(usersCollectionProvider).doc(user.uid);
    await docRef.set({
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateDisplayName(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await ref.read(usersCollectionProvider).doc(user.uid).set({
      'displayName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.updateDisplayName(name);
  }

  Future<String> uploadAvatar(File file) async {
    final user = FirebaseAuth.instance.currentUser!;
    final storageRef = FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
    await storageRef.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await storageRef.getDownloadURL();
    await ref.read(usersCollectionProvider).doc(user.uid).set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.updatePhotoURL(url);
    return url;
  }

  // Admin APIs
  final HttpsCallable _setRole = FirebaseFunctions.instance.httpsCallable('setRole');
  final HttpsCallable _listUsers = FirebaseFunctions.instance.httpsCallable('listUsers');

  Future<void> setRole({required String uid, required String role, required bool value}) async {
    await _setRole.call({'uid': uid, 'role': role, 'value': value});
  }

  Future<AdminUsersPage> listUsers({String? pageToken, int pageSize = 20}) async {
    final res = await _listUsers.call({'pageToken': pageToken, 'pageSize': pageSize});
    final data = Map<String, dynamic>.from(res.data as Map);
    final users = (data['users'] as List)
        .map((u) => AdminUser.fromMap(Map<String, dynamic>.from(u as Map)))
        .toList();
    return AdminUsersPage(users: users, nextPageToken: data['pageToken'] as String?);
  }
}

class AdminUsersPage {
  final List<AdminUser> users;
  final String? nextPageToken;
  AdminUsersPage({required this.users, required this.nextPageToken});
}

class AdminUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool disabled;
  final Map<String, dynamic> customClaims;
  final String? creationTime;
  final String? lastSignInTime;

  AdminUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.disabled,
    required this.customClaims,
    this.creationTime,
    this.lastSignInTime,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    final metadata = Map<String, dynamic>.from((map['metadata'] as Map? ?? {}));
    return AdminUser(
      uid: map['uid'] as String,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      photoURL: map['photoURL'] as String?,
      disabled: (map['disabled'] as bool?) ?? false,
      customClaims: Map<String, dynamic>.from((map['customClaims'] as Map? ?? {})),
      creationTime: metadata['creationTime'] as String?,
      lastSignInTime: metadata['lastSignInTime'] as String?,
    );
  }
}