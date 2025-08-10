import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repo/lists_repository.dart';

class AddToListSheet extends ConsumerWidget {
  final String spotId;
  const AddToListSheet({super.key, required this.spotId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(userListsStreamProvider);
    return SafeArea(
      child: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Keine Listen. Lege zuerst eine Liste an.'),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final l in lists)
                ListTile(
                  title: Text(l.name),
                  onTap: () async {
                    await ref.read(listsRepoProvider).addSpot(listId: l.id, spotId: spotId);
                    if (context.mounted) Navigator.pop(context, l.id);
                  },
                ),
            ],
          );
        },
        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $e'),
        ),
      ),
    );
  }
}