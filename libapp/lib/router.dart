import 'package:go_router/go_router.dart';
import 'features/map/map_page.dart';
import 'features/spots/spot_form_page.dart';
import 'features/admin/admin_dashboard_page.dart';

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
      ],
    ),
  ],
);
