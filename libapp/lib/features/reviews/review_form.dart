import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReviewForm extends StatefulWidget {
  final String spotId;
  const ReviewForm({super.key, required this.spotId});

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  final formKey = GlobalKey<FormState>();
  int rating = 5;
  final controller = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => submitting = true);
    final fs = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await fs.runTransaction((txn) async {
      final spotRef = fs.collection('spots').doc(widget.spotId);
      final spotSnap = await txn.get(spotRef);
      final ratingsCount = (spotSnap.get('ratingsCount') as num?)?.toInt() ?? 0;
      final avgRating = (spotSnap.get('avgRating') as num?)?.toDouble() ?? 0.0;
      final newCount = ratingsCount + 1;
      final newAvg = ((avgRating * ratingsCount) + rating) / newCount;

      final reviewRef = fs.collection('reviews').doc();
      txn.set(reviewRef, {
        'spotId': widget.spotId,
        'userId': uid,
        'rating': rating,
        'text': controller.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      txn.update(spotRef, {'ratingsCount': newCount, 'avgRating': newAvg});
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: rating,
            items: [1, 2, 3, 4, 5]
                .map(
                  (e) => DropdownMenuItem(value: e, child: Text('$e Sterne')),
                )
                .toList(),
            onChanged: (v) => setState(() => rating = v ?? 5),
            decoration: const InputDecoration(labelText: 'Bewertung'),
          ),
          TextFormField(
            controller: controller,
            maxLength: 140,
            decoration: const InputDecoration(labelText: 'Kurzer Text'),
            validator: (v) => null,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: submitting ? null : _submit,
            child: submitting
                ? const CircularProgressIndicator()
                : const Text('Senden'),
          ),
        ],
      ),
    );
  }
}
