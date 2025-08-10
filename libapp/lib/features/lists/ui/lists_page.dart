import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repo/lists_repository.dart';

class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(userListsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Listen')),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return const Center(child: Text('Noch keine Listen'));
          }
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, i) {
              final l = lists[i];
              return ListTile(
                title: Text(l.name),
                subtitle: Text('Mitglieder: ${l.members.length}')
                    ,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ListDetailPage(listId: l.id, listName: l.name)),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'share_view' || value == 'share_edit') {
                      final role = value == 'share_view' ? 'view' : 'edit';
                      final url = await ref.read(invitesApiProvider).createInvite(listId: l.id, role: role);
                      if (context.mounted) {
                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Einladungslink'),
                            content: SelectableText(url),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'share_view', child: Text('Teilen: View-Link')),
                    PopupMenuItem(value: 'share_edit', child: Text('Teilen: Edit-Link')),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await _promptName(context);
          if (name == null || name.trim().isEmpty) return;
          await ref.read(listsRepoProvider).createList(name.trim());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> _promptName(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Neue Liste'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Name')), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Anlegen')),
        ],
      ),
    );
  }
}

class ListDetailPage extends ConsumerWidget {
  final String listId;
  final String listName;
  const ListDetailPage({super.key, required this.listId, required this.listName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(listItemsStreamProvider(listId));
    return Scaffold(
      appBar: AppBar(
        title: Text(listName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final role = value == 'share_view' ? 'view' : 'edit';
              final url = await ref.read(invitesApiProvider).createInvite(listId: listId, role: role);
              if (!context.mounted) return;
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Einladungslink'),
                  content: SelectableText(url),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                ),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'share_view', child: Text('Teilen: View-Link')),
              PopupMenuItem(value: 'share_edit', child: Text('Teilen: Edit-Link')),
            ],
          )
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('Keine Spots in dieser Liste'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              return ListTile(
                title: Text(it.spotId),
                subtitle: it.note != null ? Text(it.note!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => ref.read(listsRepoProvider).removeSpot(listId: listId, spotId: it.spotId),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}