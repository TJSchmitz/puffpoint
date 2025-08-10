import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../users/repo/users_repository.dart';

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
            const TabBar(tabs: [Tab(text: 'Pending Photos'), Tab(text: 'Reports'), Tab(text: 'Users')]),
            Expanded(
              child: TabBarView(children: [
                _PendingPhotosTab(),
                _ReportsTab(),
                const _UsersTab(),
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

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final UsersRepository repo = UsersRepository(ProviderContainer());
  List<AdminUser> users = [];
  String? nextPageToken;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await repo.listUsers(pageToken: append ? nextPageToken : null);
      setState(() {
        if (append) {
          users = [...users, ...page.users];
        } else {
          users = page.users;
        }
        nextPageToken = page.nextPageToken;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _toggleClaim(AdminUser u, String role, bool value) async {
    await repo.setRole(uid: u.uid, role: role, value: value);
    setState(() {
      u.customClaims[role] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text('Fehler: $error'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final u = users[index];
              final isAdmin = (u.customClaims['admin'] as bool?) ?? false;
              final isMod = (u.customClaims['mod'] as bool?) ?? false;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: u.photoURL != null ? NetworkImage(u.photoURL!) : null,
                  child: u.photoURL == null ? const Icon(Icons.person) : null,
                ),
                title: Text(u.displayName ?? u.email ?? u.uid),
                subtitle: Text(u.email ?? u.uid),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Admin'),
                        Switch(value: isAdmin, onChanged: (v) => _toggleClaim(u, 'admin', v)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Mod'),
                        Switch(value: isMod, onChanged: (v) => _toggleClaim(u, 'mod', v)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (nextPageToken != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: loading ? null : () => _load(append: true),
              child: const Text('Mehr laden'),
            ),
          ),
      ],
    );
  }
}
