import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoUploader extends StatefulWidget {
  final String spotId;
  const PhotoUploader({super.key, required this.spotId});

  @override
  State<PhotoUploader> createState() => _PhotoUploaderState();
}

class _PhotoUploaderState extends State<PhotoUploader> {
  bool uploading = false;
  final picker = ImagePicker();

  Future<void> _pickAndUpload(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() => uploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final path =
          'tmp/$uid/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final file = File(picked.path);
      final task = await FirebaseStorage.instance.ref(path).putFile(file);
      final storagePath = task.ref.fullPath;
      await FirebaseFirestore.instance.collection('spotPhotos').add({
        'spotId': widget.spotId,
        'storagePath': storagePath,
        'thumbPath': null,
        'uploadedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'moderation': {'status': 'pending', 'reason': null},
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto hochgeladen (pending)')),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: uploading
              ? null
              : () => _pickAndUpload(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Kamera'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: uploading
              ? null
              : () => _pickAndUpload(ImageSource.gallery),
          icon: const Icon(Icons.photo),
          label: const Text('Galerie'),
        ),
      ],
    );
  }
}
