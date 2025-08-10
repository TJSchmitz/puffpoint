import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String spotId;
  final String userId;
  final int rating; // 1-5
  final String text;
  final Timestamp createdAt;

  Review({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.rating,
    required this.text,
    required this.createdAt,
  });

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Review(
      id: doc.id,
      spotId: d['spotId'] as String,
      userId: d['userId'] as String,
      rating: (d['rating'] as num).toInt(),
      text: d['text'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'spotId': spotId,
    'userId': userId,
    'rating': rating,
    'text': text,
    'createdAt': createdAt,
  };
}
