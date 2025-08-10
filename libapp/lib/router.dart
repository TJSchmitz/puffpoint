import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/map/map_page.dart';
import 'features/spots/spot_form_page.dart';
import 'features/admin/admin_dashboard_page.dart';
import 'features/lists/ui/lists_page.dart';
import 'features/lists/repo/lists_repository.dart';
import 'features/users/ui/profile_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const MapPage(),
      routes: [
        GoRoute(
          path: 'spot/new',
          builder: (context, state) => const SpotFormPage(),
        ),
        GoRoute(
          path: 'admin',
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(
          path: 'lists',
          builder: (context, state) => const ListsPage(),
        ),
        GoRoute(
          path: 'invite',
          builder: (context, state) => InviteRedeemPage(token: state.uri.queryParameters['token']),
        ),
        GoRoute(
          path: 'profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ),
  ],
);

class InviteRedeemPage extends ConsumerStatefulWidget {
  final String? token;
  const InviteRedeemPage({super.key, required this.token});

  @override
  ConsumerState<InviteRedeemPage> createState() => _InviteRedeemPageState();
}

class _InviteRedeemPageState extends ConsumerState<InviteRedeemPage> {
  String? status;

  @override
  void initState() {
    super.initState();
    _redeem();
  }

  Future<void> _redeem() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => status = 'Ungültiger Link');
      return;
    }
    try {
      await ref.read(invitesApiProvider).redeem(token);
      setState(() => status = 'Einladung erfolgreich eingelöst.');
    } catch (e) {
      setState(() => status = 'Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einladung')),
      body: Center(child: Text(status ?? 'Einlösung...')),
    );
  }
}
