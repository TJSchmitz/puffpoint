import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Pending Photos'), Tab(text: 'Reports')]),
            Expanded(
              child: TabBarView(children: [
                _PendingPhotosTab(),
                _ReportsTab(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPhotosTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('spotPhotos')
          .where('moderation.status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return ListTile(
              title: Text(d['storagePath'] ?? ''),
              subtitle: Text('spotId: ${d['spotId']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _moderate(docs[i].id, 'approve'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _moderate(docs[i].id, 'reject'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _moderate(String docId, String action) async {
    final callable = FirebaseFunctions.instance.httpsCallable('moderatePhoto');
    await callable.call({'photoId': docId, 'action': action});
  }
}

class _ReportsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        return ListView(
          children: docs
              .map((d) => ListTile(
                    title: Text('${d['targetType']} ${d['targetId']}'),
                    subtitle: Text('${d['reason']} • status: ${d['status']}'),
                  ))
              .toList(),
        );
      },
    );
  }
}
