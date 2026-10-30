import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/services/download.dart';
import '../../data/portal_repository.dart';
import '../widgets/admin_widgets.dart';

class PortalListPage extends ConsumerStatefulWidget {
  const PortalListPage({super.key, required this.section, this.status = ''});
  final String section, status;
  @override
  ConsumerState<PortalListPage> createState() => _PortalListPageState();
}

class _PortalListPageState extends ConsumerState<PortalListPage> {
  final _search = TextEditingController();
  String _kind = '',
      _type = '',
      _status = '',
      _semester = '',
      _role = '',
      _activity = '',
      _start = '',
      _end = '';
  int _page = 0;
  bool _exporting = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _status = widget.status;
    if (widget.section == 'users') _kind = 'STUDENT';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => Uri(
    queryParameters: {
      'kind': _kind,
      'type': _type,
      'status': _status,
      'semester': _semester,
      'search': _search.text,
      'page': '$_page',
      'role': _role,
      'activity': _activity,
      'start': _start,
      'end': _end,
      if (widget.section == 'users') 'scope': 'work',
    },
  ).query;
  String get _path =>
      '${widget.section == 'audit'
          ? 'audit'
          : widget.section == 'reports'
          ? 'reports'
          : 'requests'}?$_query';
  Widget _select(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> change,
  ) => SizedBox(
    width: 185,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      key: ValueKey('$label:$value'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: choices.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() {
        change(v!);
        _page = 0;
      }),
    ),
  );
  Future<void> _export({bool preview = false}) async {
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final audit = widget.section == 'audit';
      final bytes = await portalDownload(
        ref,
        '${audit ? 'audit/csv' : 'reports/pdf'}?$_query',
      );
      saveDownload(
        bytes,
        audit ? 'reaccess-audit.csv' : 'reaccess-report.pdf',
        audit ? 'text/csv' : 'application/pdf',
        preview: preview,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not export. Check permissions or narrow your filters.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _date(bool start) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (value != null) {
      setState(() {
        final text = value.toIso8601String().substring(0, 10);
        if (start) {
          _start = text;
        } else {
          _end = text;
        }
        _page = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = widget.section == 'dashboard',
        audit = widget.section == 'audit',
        reports = widget.section == 'reports',
        users = widget.section == 'users';
    final title = switch (widget.section) {
      'dashboard' => 'Dashboard',
      'audit' => 'Audit Logs',
      'reports' => 'Reports',
      'users' => 'Users',
      _ => 'All Requests',
    };
    final data = ref.watch(portalDataProvider(_path));
    final settings = ref.watch(portalDataProvider('settings')).asData?.value;
    final periods = (settings?['periods'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminHeading(
          title,
          switch (widget.section) {
            'dashboard' => 'Office 365 account service overview.',
            'users' => 'Approved student and faculty work queue.',
            'audit' => 'Recorded system and administrative activity.',
            _ => 'Review Office 365 account service requests.',
          },
          action: IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(portalDataProvider(_path)),
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (users)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'STUDENT', label: Text('Students')),
                ButtonSegment(value: 'FACULTY', label: Text('Faculty')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() {
                _kind = v.first;
                _page = 0;
              }),
            ),
          ),
        if (!dashboard)
          AdminSectionCard(
            title: 'Filters',
            subtitle: 'Narrow the records shown below.',
            child: Wrap(
              spacing: 12,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!users)
                  _select('User Type', _kind, {
                    '': 'All',
                    'STUDENT': 'Student',
                    'FACULTY': 'Faculty',
                  }, (v) => _kind = v),
                if (!audit)
                  _select('Request Type', _type, {
                    '': 'All',
                    'SSPR': 'SSPR Enrollment',
                    'RECOVERY': 'Account Recovery',
                    'UPDATE': 'Account Update',
                  }, (v) => _type = v),
                if (!audit && !users)
                  _select('Status', _status, {
                    '': 'All',
                    'PENDING': 'Pending Review',
                    'IN_REVIEW': 'Under Review',
                    'APPROVED': 'Approved',
                    'REJECTED': 'Rejected',
                    'COMPLETED': 'Completed',
                  }, (v) => _status = v),
                _select('Semester', _semester, {
                  '': 'All',
                  for (final p in periods)
                    display(p['id']): '${p['semester']} ${p['academic_year']}',
                }, (v) => _semester = v),
                if (audit) ...[
                  _select('Role', _role, {
                    '': 'All',
                    'SUPER_ADMIN': 'Super Admin',
                    'ADMIN': 'Admin',
                  }, (v) => _role = v),
                  _select('Activity', _activity, {
                    '': 'All',
                    for (final v in [
                      'ADMIN_LOGIN',
                      'ADMIN_LOGOUT',
                      'REQUEST_SUBMITTED',
                      'REQUEST_APPROVE',
                      'REQUEST_REJECT',
                      'REQUEST_DONE',
                      'REQUEST_REGISTER',
                      'MESSAGE_SENT',
                      'CREDENTIALS_CHANGED',
                      'SEMESTER_CREATED',
                      'SEMESTER_UPDATED',
                      'REGISTRY_USER_ADDED',
                      'REGISTRY_USER_UPDATED',
                      'REGISTRY_USER_DELETED',
                      'REGISTRY_BULK_IMPORTED',
                      'SUPPORT_DELETED',
                    ])
                      v: v.replaceAll('_', ' '),
                  }, (v) => _activity = v),
                ],
                SizedBox(
                  width: 230,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => setState(() => _page = 0),
                    decoration: InputDecoration(
                      hintText: 'Name, ID or reference',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Apply search',
                        onPressed: () => setState(() => _page = 0),
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                if (reports) ...[
                  OutlinedButton.icon(
                    onPressed: () => _date(true),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_start.isEmpty ? 'Start date' : _start),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _date(false),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_end.isEmpty ? 'End date' : _end),
                  ),
                ],
                IconButton(
                  tooltip: 'Reset filters',
                  onPressed: () => setState(() {
                    _kind = users ? 'STUDENT' : '';
                    _type = '';
                    _status = '';
                    _semester = '';
                    _role = '';
                    _activity = '';
                    _start = '';
                    _end = '';
                    _search.clear();
                    _page = 0;
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
                if (reports || audit)
                  FilledButton.icon(
                    onPressed: _exporting ? null : () => _export(),
                    icon: const Icon(Icons.download, size: 17),
                    label: Text(audit ? 'Export CSV' : 'Export Report'),
                  ),
                if (reports)
                  OutlinedButton.icon(
                    onPressed: _exporting ? null : () => _export(preview: true),
                    icon: const Icon(Icons.print, size: 17),
                    label: const Text('Print PDF'),
                  ),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (audit)
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Audit logs are read-only.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        data.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Unable to load data. Check the database connection and your permissions.',
            ),
          ),
          data: (value) {
            final rows = (value['rows'] as List).cast<Map<String, dynamic>>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dashboard || reports) ...[
                  SummaryStrip(value['summary'] as Map),
                  const SizedBox(height: 24),
                ],
                if (dashboard) ...[
                  AdminSectionCard(
                    title: 'Request overview',
                    child: Wrap(
                      spacing: 32,
                      runSpacing: 12,
                      children: [
                        Text(
                          'Student requests: ${(value['summary'] as Map)['students']}',
                        ),
                        Text(
                          'Faculty requests: ${(value['summary'] as Map)['faculty']}',
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Recent Requests',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                ],
                if (rows.isEmpty)
                  const AdminEmptyState(
                    title: 'No matching records',
                    message: 'Try changing or clearing the filters above.',
                  )
                else
                  audit
                      ? AdminTable(
                          columns: const [
                            'Timestamp',
                            'User',
                            'Role',
                            'Semester',
                            'Activity',
                            'Reference',
                          ],
                          rows: [
                            for (final r in rows)
                              [
                                Text(display(r['created_at'])),
                                Text(display(r['username'])),
                                Text(display(r['actor_role'])),
                                Text(display(r['semester_label'])),
                                Text(display(r['action'])),
                                Text(display(r['reference'])),
                              ],
                          ],
                        )
                      : AdminTable(
                          columns: [
                            'Reference ID',
                            'Name',
                            'User Type',
                            'Request Type',
                            'Status',
                            if (!reports) 'Action',
                          ],
                          rows: [
                            for (final r in (dashboard ? rows.take(8) : rows))
                              [
                                Text(
                                  display(r['reference']),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                                SizedBox(
                                  width: 160,
                                  child: Text(requestName(r)),
                                ),
                                Text(display(r['person_kind'])),
                                Text(requestType(r['request_type'])),
                                StatusLabel(display(r['status'])),
                                if (!reports)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed: () => context.go(
                                          '/admin/requests/${r['id']}',
                                        ),
                                        child: const Text('View'),
                                      ),
                                      if (users)
                                        TextButton(
                                          onPressed: () => context.go(
                                            '/admin/requests/${r['id']}?work=true',
                                          ),
                                          child: Text(
                                            r['status'] == 'COMPLETED'
                                                ? 'Add ${_kind == 'STUDENT' ? 'Student' : 'Faculty'}'
                                                : 'Done',
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                          ],
                        ),
                if (!dashboard)
                  AdminPagination(
                    page: _page,
                    onPrevious: _page == 0
                        ? null
                        : () => setState(() => _page--),
                    onNext: rows.length < 25
                        ? null
                        : () => setState(() => _page++),
                  ),
                if (dashboard)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/admin/requests'),
                      child: const Text('View All Requests'),
                    ),
                  ),
                if (dashboard) ...[
                  const SizedBox(height: 24),
                  AdminSectionCard(
                    title: 'Recent Activity',
                    child: ref
                        .watch(portalDataProvider('audit?page=0'))
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const Text('Activity unavailable.'),
                          data: (a) => Column(
                            children: [
                              for (final item in (a['rows'] as List).take(6))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.history, size: 18),
                                  title: Text(
                                    display(item['action'])
                                        .replaceAll('_', ' '),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    '${item['username']} - ${item['created_at']}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
