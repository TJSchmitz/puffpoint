import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repo/lists_repository.dart';

class InviteRedeemBanner extends ConsumerStatefulWidget {
  final String token;
  const InviteRedeemBanner({super.key, required this.token});

  @override
  ConsumerState<InviteRedeemBanner> createState() => _InviteRedeemBannerState();
}

class _InviteRedeemBannerState extends ConsumerState<InviteRedeemBanner> {
  bool done = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    if (done) return const SizedBox.shrink();
    return MaterialBanner(
      content: Text(error == null ? 'Einladung gefunden. Einlösen?' : 'Fehler: $error'),
      leading: const Icon(Icons.mail),
      actions: [
        if (error == null)
          TextButton(
            onPressed: () async {
              try {
                await ref.read(invitesApiProvider).redeem(widget.token);
                setState(() => done = true);
              } catch (e) {
                setState(() => error = '$e');
              }
            },
            child: const Text('Einlösen'),
          ),
        TextButton(onPressed: () => setState(() => done = true), child: const Text('Schließen')),
      ],
    );
  }
}