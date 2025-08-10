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
        length: 3,
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Pending Photos'), Tab(text: 'Reports'), Tab(text: 'Roles')]),
            Expanded(
              child: TabBarView(children: [
                _PendingPhotosTab(),
                _ReportsTab(),
                _RolesTab(),
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

class _RolesTab extends StatefulWidget {
  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  final uidController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    uidController.dispose();
    super.dispose();
  }

  Future<void> _setRole(String role, bool value) async {
    if (uidController.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('setRole');
      await callable.call({
        'uid': uidController.text.trim(),
        'role': role,
        'value': value,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role updated')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: uidController,
            decoration: const InputDecoration(labelText: 'User UID'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: loading ? null : () => _setRole('admin', true),
                child: const Text('Grant admin'),
              ),
              ElevatedButton(
                onPressed: loading ? null : () => _setRole('admin', false),
                child: const Text('Revoke admin'),
              ),
              ElevatedButton(
                onPressed: loading ? null : () => _setRole('mod', true),
                child: const Text('Grant mod'),
              ),
              ElevatedButton(
                onPressed: loading ? null : () => _setRole('mod', false),
                child: const Text('Revoke mod'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
