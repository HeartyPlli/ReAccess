import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reaccess_hub/app.dart';
import 'package:reaccess_hub/core/constants/app_routes.dart';
import 'package:reaccess_hub/features/public_site/presentation/pages/public_landing_page.dart';
import 'package:reaccess_hub/features/admin/presentation/widgets/admin_widgets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
  for (final width in [360.0, 768.0, 1440.0]) {
    testWidgets('public home and chat fit at $width pixels', (tester) async {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1;
      await tester.pumpWidget(
        const ProviderScope(child: SchoolManagementApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('How can we help you?'), findsOneWidget);
      expect(find.text('Account Services'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Open support chat'));
      await tester.pumpAndSettle();
      expect(find.text('ReAccess Hub Assistant'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close support chat'));
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('admin access opens the real login route', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(const ProviderScope(child: SchoolManagementApp()));
    await tester.pumpAndSettle();
    expect(find.text('Admin Access'), findsNothing);
    GoRouter.of(tester.element(find.byType(PublicLandingPage)))
        .go(AppRoutes.adminLogin);
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsNWidgets(2));
    expect(find.text('Authorized school personnel only.'), findsOneWidget);
    expect(find.textContaining('Prototype credentials'), findsNothing);
  });
  testWidgets('admin dashboard redirects unauthenticated visitors', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SchoolManagementApp()));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(PublicLandingPage)))
        .go(AppRoutes.adminDashboard);
    await tester.pumpAndSettle();
    expect(find.text('Authorized school personnel only.'), findsOneWidget);
    expect(find.text('CISO support inbox'), findsNothing);
  });
  testWidgets('admin table rows can open an edit action', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminTable(
            columns: const ['ID number', 'Action'],
            rows: const [
              [Text('123456'), Icon(Icons.delete_outline)],
            ],
            onSelect: [() => selected++],
          ),
        ),
      ),
    );
    await tester.tap(find.text('123456'));
    await tester.pump();
    expect(selected, 1);
  });
  testWidgets('admin shared widgets fit a narrow layout', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 760)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AdminHeading(
                  'Dashboard',
                  'Office 365 account service overview.',
                  action: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                const SummaryStrip({
                  'total': 12,
                  'pending': 3,
                  'approved': 7,
                  'rejected': 2,
                }),
                const AdminEmptyState(
                  title: 'No matching records',
                  message: 'Try another filter.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Total Requests'), findsOneWidget);
    expect(find.text('No matching records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('FAQ answer survives close, reopen, and app recreation', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(const ProviderScope(child: SchoolManagementApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open support chat'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'What is SSPR Enrollment?'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close support chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open support chat'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Self-Service Password Reset (SSPR)'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const ProviderScope(child: SchoolManagementApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open support chat'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Self-Service Password Reset (SSPR)'),
      findsOneWidget,
    );
  });
}
