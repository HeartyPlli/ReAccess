import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/theme_toggle.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import 'portal_list_page.dart';
import 'request_review_page.dart';
import 'portal_settings_page.dart';
import 'portal_messages_page.dart';
import 'user_management_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({
    super.key,
    this.section = 'dashboard',
    this.requestId,
    this.status = '',
  });
  final String section, status;
  final String? requestId;
  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _collapsed = false;
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final mobile = screenWidth < 900;
    Widget navigation({bool compact = false}) => Material(
      color: const Color(0xFF242424),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 18,
              vertical: 18,
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF52517D),
                  child: Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Administrator',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user?.username ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              children: [
                for (final item in [
                  ('dashboard', 'Home', Icons.home_outlined),
                  ('requests', 'Requests', Icons.format_list_bulleted),
                  ('messages', 'Messages', Icons.chat_bubble_outline),
                  ('reports', 'Reports', Icons.bar_chart),
                  ('audit', 'Audit Logs', Icons.manage_search),
                  ('users', 'Users', Icons.people_outline),
                  ('settings', 'Settings', Icons.settings_outlined),
                ])
                  if (item.$1 == 'requests' && !compact)
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: widget.section == 'requests',
                        iconColor: Colors.white60,
                        collapsedIconColor: Colors.white60,
                        leading: const Icon(
                          Icons.format_list_bulleted,
                          color: Colors.white70,
                          size: 20,
                        ),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        title: const Text(
                          'Requests',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        children: [
                          for (final status in [
                            ('', 'All Requests'),
                            ('PENDING', 'Pending Review'),
                            ('APPROVED', 'Approved'),
                            ('REJECTED', 'Rejected'),
                            ('COMPLETED', 'Completed'),
                          ])
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(
                                left: 48,
                                right: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              title: Text(
                                status.$2,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              selected:
                                  widget.section == 'requests' &&
                                  widget.status == status.$1,
                              selectedTileColor: const Color(0xFF393849),
                              onTap: () => context.go(
                                '/admin/requests?status=${status.$1}',
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Tooltip(
                      message: compact ? item.$2 : '',
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 12,
                        ),
                        leading: Icon(item.$3, color: Colors.white70, size: 20),
                        title: compact
                            ? null
                            : Text(
                                item.$2,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                        selected: widget.section == item.$1,
                        selectedTileColor: const Color(0xFF393849),
                        onTap: () => context.go('/admin/${item.$1}'),
                      ),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: const Icon(
                Icons.logout,
                color: Colors.white60,
                size: 20,
              ),
              title: compact
                  ? null
                  : const Text(
                      'Sign out',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
              onTap: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/admin/login');
              },
            ),
          ),
        ],
      ),
    );
    final content = widget.requestId != null
        ? RequestReviewPage(
            key: ValueKey(widget.requestId),
            id: widget.requestId!,
          )
        : switch (widget.section) {
            'settings' => const PortalSettingsPage(),
            'messages' => const PortalMessagesPage(),
            'users' => const UserManagementPage(),
            _ => PortalListPage(
              key: ValueKey('${widget.section}:${widget.status}'),
              section: widget.section,
              status: widget.status,
            ),
          };
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF18242B),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/school_pic_top_view.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Color(0xE518242B),
                BlendMode.srcATop,
              ),
            ),
          ),
        ),
        leading: mobile
            ? null
            : IconButton(
                tooltip: _collapsed ? 'Expand menu' : 'Collapse menu',
                onPressed: () => setState(() => _collapsed = !_collapsed),
                icon: const Icon(Icons.menu),
              ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/reaccess_logo.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'ReAccess Hub',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 16),
            Image.asset('assets/images/tcgc_logo.png', width: 26, height: 26),
          ],
        ),
        actions: const [
          ThemeToggle(onDarkBackground: true),
          SizedBox(width: 8),
        ],
      ),
      drawer: mobile
          ? Drawer(
              width: screenWidth < 420 ? screenWidth * .86 : 320,
              child: SafeArea(child: navigation()),
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!mobile)
            SizedBox(
              width: _collapsed ? 76 : 248,
              child: navigation(compact: _collapsed),
            ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: mobile
                      ? 16
                      : screenWidth < 1200
                      ? 24
                      : 32,
                  vertical: mobile ? 20 : 28,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: SizedBox(width: double.infinity, child: content),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
