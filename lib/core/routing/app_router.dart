import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/auth/presentation/pages/access_denied_page.dart';
import '../../features/auth/presentation/pages/admin_login_page.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/public_site/presentation/pages/public_landing_page.dart';
import '../constants/app_routes.dart';

import 'package:request_contract/request_contract.dart';

import '../../features/requests/presentation/request_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: '/request/student',
        builder: (context, state) =>
            const RequestPage(person: PersonKind.student),
      ),
      GoRoute(
        path: '/request/faculty',
        builder: (context, state) =>
            const RequestPage(person: PersonKind.faculty),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const PublicLandingPage(),
      ),
      GoRoute(
        path: AppRoutes.about,
        redirect: (context, state) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.programs,
        redirect: (context, state) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.announcements,
        redirect: (context, state) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.contact,
        redirect: (context, state) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.adminLogin,
        builder: (context, state) => const AdminLoginPage(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      for (final section in [
        'requests',
        'messages',
        'reports',
        'audit',
        'users',
        'settings',
      ])
        GoRoute(
          path: '/admin/$section',
          builder: (context, state) => AdminDashboardPage(
            section: section,
            status: state.uri.queryParameters['status'] ?? '',
          ),
        ),
      GoRoute(
        path: '/admin/requests/:id',
        builder: (context, state) => AdminDashboardPage(
          section: 'requests',
          requestId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.accessDenied,
        builder: (context, state) => const AccessDeniedPage(),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isAdminRoute = location.startsWith('/admin');
      final isLoginRoute = location == AppRoutes.adminLogin;

      if (isAdminRoute && !isLoginRoute) {
        if (!auth.isAuthenticated) {
          final from = Uri.encodeComponent(state.uri.toString());
          return '${AppRoutes.adminLogin}?from=$from';
        }

        if (!auth.user!.canAccessAdmin) {
          return AppRoutes.accessDenied;
        }
        if (auth.user!.mustChangePassword && location != '/admin/settings') {
          return '/admin/settings';
        }
      }

      if (isLoginRoute &&
          auth.isAuthenticated &&
          auth.user?.canAccessAdmin == true) {
        return AppRoutes.adminDashboard;
      }

      return null;
    },
  );
});

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this.ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref ref;
  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
