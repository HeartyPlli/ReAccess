import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../requests/presentation/request_widgets.dart';
import '../../data/portal_repository.dart';
import '../widgets/admin_widgets.dart';

class PortalSettingsPage extends ConsumerStatefulWidget {
  const PortalSettingsPage({super.key});

  @override
  ConsumerState<PortalSettingsPage> createState() => _PortalSettingsPageState();
}

class _PortalSettingsPageState extends ConsumerState<PortalSettingsPage> {
  final _username = TextEditingController();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _year = TextEditingController();
  final _requestLimit = TextEditingController();
  String _semester = '1st Semester';
  String _start = '';
  String _end = '';
  bool _busy = false;
  bool _limitInitialized = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _username.text = ref.read(authControllerProvider).user?.username ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _username,
      _oldPassword,
      _newPassword,
      _confirmPassword,
      _year,
      _requestLimit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    if (_oldPassword.text.isEmpty ||
        _username.text.trim().isEmpty ||
        (_newPassword.text.isNotEmpty &&
            (_newPassword.text.length < 8 ||
                _newPassword.text != _confirmPassword.text))) {
      setState(() {
        _message = 'Enter the current password and confirm a new password of at least 8 characters.';
      });
      return;
    }
    await _run(() async {
      await ref
          .read(apiClientProvider)
          .post(
            '/auth/credentials',
            data: {
              'username': _username.text.trim(),
              'oldPassword': _oldPassword.text,
              'newPassword': _newPassword.text,
              'confirmPassword': _confirmPassword.text,
            },
          );
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go('/admin/login');
    });
  }

  Future<void> _chooseDate(bool start) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (value == null) return;
    setState(() {
      final date = value.toIso8601String().substring(0, 10);
      if (start) {
        _start = date;
      } else {
        _end = date;
      }
    });
  }

  Future<void> _savePeriod() => _run(() async {
    await portalPost(ref, 'settings', {
      'semester': _semester,
      'academicYear': _year.text.trim(),
      'start': _start,
      'end': _end,
    });
    _refreshSettings();
    if (mounted) setState(() => _message = 'Academic period saved.');
  });

  Future<void> _editAcademicPeriod(Map period) async {
    final form = GlobalKey<FormState>();
    final year = TextEditingController(
      text: period['academic_year']?.toString() ?? '',
    );
    var semester = period['semester']?.toString() ?? '1st Semester';
    var start = period['start_date']?.toString() ?? '';
    var end = period['end_date']?.toString() ?? '';
    String? dateError;
    final values = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> chooseDate(bool choosingStart) async {
            final existing = DateTime.tryParse(choosingStart ? start : end);
            final value = await showDatePicker(
              context: dialogContext,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDate: existing ?? DateTime.now(),
            );
            if (value == null) return;
            setDialogState(() {
              final date = value.toIso8601String().substring(0, 10);
              if (choosingStart) {
                start = date;
              } else {
                end = date;
              }
              dateError = null;
            });
          }

          return AlertDialog(
            title: const Text('Edit academic period'),
            content: SizedBox(
              width: 500,
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Change the saved timeline. Requests already connected to this period keep the same period record.',
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: semester,
                      decoration: const InputDecoration(
                        labelText: 'Semester',
                        border: OutlineInputBorder(),
                      ),
                      items: ['1st Semester', '2nd Semester', 'Summer']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => semester = value!),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: year,
                      decoration: const InputDecoration(
                        labelText: 'Academic year',
                        hintText: '2026-2027',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value != null &&
                              RegExp(r'^\d{4}-\d{4}$').hasMatch(value.trim())
                          ? null
                          : 'Use the format 2026-2027.',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => chooseDate(true),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(start.isEmpty ? 'Start date' : start),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => chooseDate(false),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(end.isEmpty ? 'End date' : end),
                        ),
                      ],
                    ),
                    if (dateError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dateError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState?.validate() != true) return;
                  if (start.isEmpty ||
                      end.isEmpty ||
                      start.compareTo(end) > 0) {
                    setDialogState(() {
                      dateError =
                          'Choose a start date on or before the end date.';
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'semester': semester,
                    'academicYear': year.text.trim(),
                    'start': start,
                    'end': end,
                  });
                },
                child: const Text('Save changes'),
              ),
            ],
          );
        },
      ),
    );
    year.dispose();
    if (values == null) return;
    await _run(() async {
      await portalPost(ref, 'settings/periods/${period['id']}/update', values);
      _refreshSettings();
      if (mounted) setState(() => _message = 'Academic period updated.');
    });
  }

  Future<void> _saveLimit() async {
    final limit = int.tryParse(_requestLimit.text.trim());
    if (limit == null || limit < 0 || limit > 100) {
      setState(() => _message = 'Enter a request limit from 0 to 100.');
      return;
    }
    await _run(() async {
      await portalPost(ref, 'settings/student-request-limit', {'limit': limit});
      _refreshSettings();
      if (mounted) {
        setState(() {
          _message = limit == 0
              ? 'Student request limit disabled and its counter restarted.'
              : 'Student request limit set to $limit per request type.';
        });
      }
    });
  }

  Future<void> _addInstitution() async {
    final values = await _confirmationDialog(
      title: 'Add institution',
      nameLabel: 'Institution name',
      confirmLabel: 'Add institution',
    );
    if (values == null) return;
    await _catalogAction('settings/institutions', values, 'Institution added.');
  }

  Future<void> _removeInstitution(Map institution) async {
    final values = await _confirmationDialog(
      title: 'Delete ${institution['name']}?',
      description: 'The institution and its programs will stop appearing in request forms. Existing requests are kept.',
      confirmLabel: 'Delete institution',
      destructive: true,
    );
    if (values == null) return;
    await _catalogAction(
      'settings/institutions/${institution['id']}/remove',
      values,
      'Institution removed.',
    );
  }

  Future<void> _addProgram(Map institution) async {
    final values = await _confirmationDialog(
      title: 'Add program to ${institution['name']}',
      nameLabel: 'Program name',
      confirmLabel: 'Add program',
    );
    if (values == null) return;
    await _catalogAction(
      'settings/institutions/${institution['id']}/programs',
      values,
      'Program added.',
    );
  }

  Future<void> _removeProgram(Map institution, Map program) async {
    final values = await _confirmationDialog(
      title: 'Delete ${program['name']}?',
      description:
          'This program will stop appearing under ${institution['name']}. Existing requests are kept.',
      confirmLabel: 'Delete program',
      destructive: true,
    );
    if (values == null) return;
    await _catalogAction(
      'settings/programs/${program['id']}/remove',
      values,
      'Program removed.',
    );
  }

  Future<void> _catalogAction(
    String path,
    Map<String, String> values,
    String success,
  ) => _run(() async {
    await portalPost(ref, path, values);
    _refreshSettings();
    if (mounted) setState(() => _message = success);
  });

  Future<Map<String, String>?> _confirmationDialog({
    required String title,
    required String confirmLabel,
    String? description,
    String? nameLabel,
    bool destructive = false,
  }) async {
    final name = TextEditingController();
    final username = TextEditingController(text: _username.text);
    final password = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (description != null) ...[
                Text(description),
                const SizedBox(height: 16),
              ],
              if (nameLabel != null) ...[
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: nameLabel),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Confirm this change with your current admin credentials.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                onSubmitted: (_) => Navigator.pop(dialogContext, {
                  if (nameLabel != null) 'name': name.text.trim(),
                  'username': username.text.trim(),
                  'password': password.text,
                }),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, {
              if (nameLabel != null) 'name': name.text.trim(),
              'username': username.text.trim(),
              'password': password.text,
            }),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    name.dispose();
    username.dispose();
    password.dispose();
    if (result == null ||
        (nameLabel != null && (result['name'] ?? '').isEmpty) ||
        (result['username'] ?? '').isEmpty ||
        (result['password'] ?? '').isEmpty) {
      return null;
    }
    return result;
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await work();
    } on AppException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'The settings change could not be completed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshSettings() {
    _limitInitialized = false;
    ref.invalidate(portalDataProvider('settings'));
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
    bool initiallyExpanded = false,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      children: [Align(alignment: Alignment.centerLeft, child: child)],
    ),
  );

  Widget _credentials(bool mustChange) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (mustChange)
        const RequestNotice(
          'Change your temporary password before accessing the other admin settings.',
        ),
      TextField(
        controller: _username,
        decoration: const InputDecoration(labelText: 'Username'),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _oldPassword,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Current password'),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _newPassword,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'New password (at least 8 characters)',
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _confirmPassword,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm new password'),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: _busy ? null : _saveCredentials,
          child: const Text('Save credentials and sign out'),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Leave both new-password fields empty to change only the username.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );

  Widget _institutions(List institutions) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _busy ? null : _addInstitution,
          icon: const Icon(Icons.add),
          label: const Text('Add institution'),
        ),
      ),
      const SizedBox(height: 16),
      if (institutions.isEmpty)
        const Text(
          'No active institutions. Add one to show it in request forms.',
        ),
      for (final institution in institutions.cast<Map>())
        ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_balance_outlined),
          title: Text(institution['name'].toString()),
          subtitle: Text(
            '${(institution['programs'] as List? ?? const []).length} program(s)',
          ),
          trailing: IconButton(
            tooltip: 'Delete institution',
            onPressed: _busy ? null : () => _removeInstitution(institution),
            icon: const Icon(Icons.delete_outline),
          ),
          childrenPadding: const EdgeInsets.only(left: 24, bottom: 18),
          children: [
            for (final program
                in (institution['programs'] as List? ?? const []).cast<Map>())
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined, size: 20),
                title: Text(program['name'].toString()),
                trailing: IconButton(
                  tooltip: 'Delete program',
                  onPressed: _busy
                      ? null
                      : () => _removeProgram(institution, program),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _addProgram(institution),
                icon: const Icon(Icons.add),
                label: const Text('Add program'),
              ),
            ),
          ],
        ),
    ],
  );

  Widget _academicPeriods(List periods) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final period in periods.cast<Map>())
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text('${period['semester']}, AY ${period['academic_year']}'),
          subtitle: Text('${period['start_date']} to ${period['end_date']}'),
          trailing: IconButton(
            tooltip: 'Edit academic period',
            onPressed: _busy ? null : () => _editAcademicPeriod(period),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: _semester,
        decoration: const InputDecoration(labelText: 'Semester'),
        items: ['1st Semester', '2nd Semester', 'Summer']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => _semester = value!),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _year,
        decoration: const InputDecoration(
          labelText: 'Academic year',
          hintText: '2026-2027',
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => _chooseDate(true),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_start.isEmpty ? 'Start date' : _start),
          ),
          OutlinedButton.icon(
            onPressed: () => _chooseDate(false),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_end.isEmpty ? 'End date' : _end),
          ),
          FilledButton(
            onPressed: _busy ? null : _savePeriod,
            child: const Text('Add academic period'),
          ),
        ],
      ),
    ],
  );

  Widget _studentLimit(int currentLimit) {
    if (!_limitInitialized) {
      _limitInitialized = true;
      _requestLimit.text = '$currentLimit';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          currentLimit == 0
              ? 'The student request limit is disabled.'
              : 'Current limit: $currentLimit request(s) per student and request type.',
        ),
        const SizedBox(height: 12),
        const Text(
          'When the next request goes beyond this number, the student is told to download the formal letter. Faculty requests are not counted. Setting 0 disables the limit and restarts student counting from zero.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _requestLimit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Student request limit',
              hintText: '0 to 100',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _busy ? null : _saveLimit,
            child: const Text('Save request limit'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user!;
    final settings = ref.watch(portalDataProvider('settings'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminHeading(
          'Settings',
          'System configuration and account security.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RequestNotice(_message!),
          ),
        _section(
          title: 'General',
          subtitle: 'Current system and office information',
          initiallyExpanded: true,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System name: ReAccess Hub'),
              SizedBox(height: 8),
              Text('Institution: Tangub City Global College'),
              SizedBox(height: 8),
              Text('Office: CISO Office'),
            ],
          ),
        ),
        _section(
          title: 'Change Credentials',
          subtitle: 'Username and password',
          initiallyExpanded: user.mustChangePassword,
          child: _credentials(user.mustChangePassword),
        ),
        if (!user.mustChangePassword && user.hasPermission('manage_settings'))
          settings.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
            error: (_, _) => const RequestNotice(
              'Unable to load configuration. Apply migration 006, restart the API, and try again.',
            ),
            data: (data) => Column(
              children: [
                _section(
                  title: 'Institution',
                  subtitle: 'Institutions and their available programs',
                  initiallyExpanded: true,
                  child: _institutions(
                    data['institutions'] as List? ?? const [],
                  ),
                ),
                _section(
                  title: 'Academic Period',
                  subtitle: 'Current and historical semester dates',
                  child: _academicPeriods(data['periods'] as List? ?? const []),
                ),
                _section(
                  title: 'Student Request Limit',
                  subtitle: 'Limit repeated student requests by service type',
                  child: _studentLimit(
                    data['studentRequestLimit'] as int? ?? 0,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
