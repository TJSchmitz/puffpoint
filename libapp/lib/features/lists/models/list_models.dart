import 'package:cloud_firestore/cloud_firestore.dart';

class SpotList {
  final String id;
  final String name;
  final String ownerId;
  final Map<String, String> members; // uid -> role ("view"|"edit")
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpotList({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPrivate => true;

  bool canEdit(String uid) {
    if (uid == ownerId) return true;
    final role = members[uid];
    return role == 'edit';
  }

  static SpotList fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SpotList(
      id: doc.id,
      name: data['name'] as String? ?? 'Liste',
      ownerId: data['ownerId'] as String? ?? '',
      members: Map<String, String>.from((data['members'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      )),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ListItem {
  final String id; // we will use spotId as itemId for idempotency
  final String listId;
  final String spotId;
  final String addedBy;
  final String? note;
  final DateTime? createdAt;

  const ListItem({
    required this.id,
    required this.listId,
    required this.spotId,
    required this.addedBy,
    this.note,
    this.createdAt,
  });

  static ListItem fromDoc(String listId, DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ListItem(
      id: doc.id,
      listId: listId,
      spotId: data['spotId'] as String? ?? doc.id,
      addedBy: data['addedBy'] as String? ?? '',
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}