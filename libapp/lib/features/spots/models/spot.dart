import 'package:cloud_firestore/cloud_firestore.dart';

class Spot {
  final String id;
  final String title;
  final String description;
  final GeoPoint coords;
  final String? address;
  final String legalStatus; // allowed|restricted|forbidden
  final List<Map<String, String>> timeWindows; // [{start,end}]
  final List<String> tags;
  final double avgRating;
  final int ratingsCount;
  final String createdBy;
  final Timestamp createdAt;
  final String status; // active|pending|flagged

  Spot({
    required this.id,
    required this.title,
    required this.description,
    required this.coords,
    required this.address,
    required this.legalStatus,
    required this.timeWindows,
    required this.tags,
    required this.avgRating,
    required this.ratingsCount,
    required this.createdBy,
    required this.createdAt,
    required this.status,
  });

  factory Spot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Spot(
      id: doc.id,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      coords: data['coords'] as GeoPoint,
      address: data['address'] as String?,
      legalStatus: data['legalStatus'] as String? ?? 'allowed',
      timeWindows:
          (data['timeWindows'] as List?)
              ?.map(
                (e) => {
                  'start': (e['start'] as String?) ?? '',
                  'end': (e['end'] as String?) ?? '',
                },
              )
              .toList() ??
          const [],
      tags: (data['tags'] as List?)?.cast<String>() ?? const [],
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: (data['ratingsCount'] as num?)?.toInt() ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'coords': coords,
    'address': address,
    'legalStatus': legalStatus,
    'timeWindows': timeWindows,
    'tags': tags,
    'avgRating': avgRating,
    'ratingsCount': ratingsCount,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'status': status,
  };
}
