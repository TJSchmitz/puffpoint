import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../spots/models/spot.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final spotsStreamProvider = StreamProvider<List<Spot>>((ref) {
  final fs = ref.watch(firestoreProvider);
  final query = fs.collection('spots').where('status', isEqualTo: 'active');
  return query.snapshots().map(
    (snap) => snap.docs.map((d) => Spot.fromDoc(d)).toList(),
  );
});

final seedSpotsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final fs = ref.read(firestoreProvider);
    final coll = fs.collection('spots');
    final existing = await coll.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'seed';
    final batch = fs.batch();
    final data = [
      {
        'title': 'Brandenburger Tor',
        'description': 'Wahrzeichen in Berlin',
        'coords': const GeoPoint(52.516275, 13.377704),
        'address': 'Pariser Platz, 10117 Berlin',
        'legalStatus': 'allowed',
      },
      {
        'title': 'Tempelhofer Feld',
        'description': 'Weitläufiges Feld',
        'coords': const GeoPoint(52.473, 13.403),
        'address': 'Tempelhof, Berlin',
        'legalStatus': 'restricted',
      },
      {
        'title': 'Mauerpark',
        'description': 'Beliebter Park',
        'coords': const GeoPoint(52.54365, 13.40261),
        'address': 'Mauerpark, Berlin',
        'legalStatus': 'allowed',
      },
    ];
    for (final s in data) {
      final doc = coll.doc();
      batch.set(doc, {
        ...s,
        'timeWindows': [],
        'tags': [],
        'avgRating': 0.0,
        'ratingsCount': 0,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    }
    await batch.commit();
  };
});

final createSpotProvider =
    Provider<
      Future<void> Function({
        required String title,
        required String description,
        required GeoPoint coords,
        String? address,
        required String legalStatus,
        List<Map<String, String>>? timeWindows,
        List<String>? tags,
      })
    >((ref) {
      return ({
        required String title,
        required String description,
        required GeoPoint coords,
        String? address,
        required String legalStatus,
        List<Map<String, String>>? timeWindows,
        List<String>? tags,
      }) async {
        final fs = ref.read(firestoreProvider);
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
        await fs.collection('spots').add({
          'title': title,
          'description': description,
          'coords': coords,
          'address': address,
          'legalStatus': legalStatus,
          'timeWindows': timeWindows ?? [],
          'tags': tags ?? [],
          'avgRating': 0.0,
          'ratingsCount': 0,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        });
      };
    });
