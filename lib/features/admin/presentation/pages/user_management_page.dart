import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:request_contract/request_contract.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../shared/services/pick_tabular.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/portal_repository.dart';
import '../widgets/admin_widgets.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  final _form = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _controllers = <String, TextEditingController>{
    for (final key in [
      'person_id',
      'first_name',
      'middle_name',
      'last_name',
      'school_email',
      'contact',
      'gmail',
    ])
      key: TextEditingController(),
  };
  String _kind = 'STUDENT';
  String _institute = institutePrograms.keys.first;
  String _program = institutePrograms.values.first.first;
  String _position = facultyPositions.first;
  int _page = 0;
  bool _saving = false, _importing = false, _changingUser = false;
  String? _message, _error;
  List<String> _duplicates = const [], _importErrors = const [];

  @override
  void dispose() {
    _search.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _path =>
      'registry?${Uri(queryParameters: {'kind': _kind, 'search': _search.text, 'page': '$_page'}).query}';

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Widget _textField(
    String key,
    String label, {
    bool optional = false,
    String? hint,
  }) => SizedBox(
    width: 260,
    child: TextFormField(
      controller: _controllers[key],
      maxLength: key == 'person_id' ? 6 : null,
      textCapitalization: key == 'person_id'
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: '$label${optional ? ' (optional)' : ''}',
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: optional
          ? null
          : key == 'person_id'
          ? (value) => idError(
              value?.trim() ?? '',
              _kind == 'STUDENT' ? PersonKind.student : PersonKind.faculty,
            )
          : _required,
    ),
  );

  Widget _select(
    String label,
    String value,
    List<String> choices,
    ValueChanged<String> onChanged,
  ) => SizedBox(
    width: 260,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      key: ValueKey('$label:$value'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: choices
          .map(
            (choice) => DropdownMenuItem(
              value: choice,
              child: Text(choice, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (choice) => onChanged(choice!),
    ),
  );

  Map<String, dynamic> _record() => {
    'person_kind': _kind,
    for (final entry in _controllers.entries)
      entry.key: entry.value.text.trim(),
    'institute': _institute,
    'program': _kind == 'STUDENT' ? _program : '',
    'position': _kind == 'FACULTY' ? _position : '',
    'active': true,
  };

  Future<void> _addUser() async {
    if (_form.currentState?.validate() != true) return;
    setState(() {
      _saving = true;
      _message = null;
      _error = null;
    });
    try {
      final result = await portalPost(ref, 'registry', _record());
      if (!mounted) return;
      setState(
        () => _message = result['message'] as String? ?? 'User data added.',
      );
      for (final controller in _controllers.values) {
        controller.clear();
      }
      ref.invalidate(portalDataProvider(_path));
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _import() async {
    final file = await pickTabularFile();
    if (file == null || !mounted) return;
    if (file.bytes.length > 5 * 1024 * 1024) {
      setState(() => _error = 'Import files must be 5 MB or smaller.');
      return;
    }
    setState(() {
      _importing = true;
      _message = null;
      _error = null;
      _duplicates = const [];
      _importErrors = const [];
    });
    try {
      final result = await portalPost(ref, 'registry/import', {
        'filename': file.name,
        'data': base64Encode(file.bytes),
      });
      if (!mounted) return;
      setState(() {
        _message = '${result['added']} user record(s) added from ${file.name}.';
        _duplicates = (result['duplicates'] as List? ?? []).cast<String>();
        _importErrors = (result['errors'] as List? ?? []).cast<String>();
      });
      ref.invalidate(portalDataProvider(_path));
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _editUser(
    Map<String, dynamic> row,
    Map<String, List<String>> catalog,
  ) async {
    if (_changingUser) return;
    final choices = {
      for (final entry in catalog.entries) entry.key: [...entry.value],
    };
    final currentInstitute = display(row['institute']);
    final currentProgram = display(row['program']);
    if (currentInstitute.isNotEmpty && !choices.containsKey(currentInstitute)) {
      choices[currentInstitute] = [
        if (currentProgram.isNotEmpty) currentProgram,
      ];
    }
    final form = GlobalKey<FormState>();
    final fields = <String, TextEditingController>{
      for (final key in [
        'first_name',
        'middle_name',
        'last_name',
        'school_email',
        'contact',
        'gmail',
      ])
        key: TextEditingController(text: display(row[key])),
    };
    final username = TextEditingController(
      text: ref.read(authControllerProvider).user?.username ?? '',
    );
    final password = TextEditingController();
    var institute = choices.containsKey(row['institute'])
        ? row['institute'] as String
        : choices.keys.first;
    var programs = choices[institute] ?? const <String>[];
    var program = programs.contains(row['program'])
        ? row['program'] as String
        : programs.firstOrNull ?? '';
    var position = facultyPositions.contains(row['position'])
        ? row['position'] as String
        : facultyPositions.first;
    var active = row['active'] == true;
    final kind = display(row['person_kind']);
    final id = display(row['person_id']);

    Widget field(
      TextEditingController controller,
      String label, {
      bool optional = false,
      bool secret = false,
    }) => SizedBox(
      width: 250,
      child: TextFormField(
        controller: controller,
        obscureText: secret,
        decoration: InputDecoration(
          labelText: '$label${optional ? ' (optional)' : ''}',
          border: const OutlineInputBorder(),
        ),
        validator: optional ? null : _required,
      ),
    );

    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit $kind $id'),
          content: SizedBox(
            width: 790,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The ID number and user type cannot be changed. Edit the information below.',
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 250,
                          child: TextFormField(
                            initialValue: id,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'ID number',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 250,
                          child: TextFormField(
                            initialValue: kind,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'User type',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        field(fields['first_name']!, 'First name'),
                        field(
                          fields['middle_name']!,
                          'Middle name',
                          optional: true,
                        ),
                        field(fields['last_name']!, 'Last name'),
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<String>(
                            initialValue: institute,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Institute',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final choice in choices.keys)
                                DropdownMenuItem(
                                  value: choice,
                                  child: Text(
                                    choice,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (choice) => setDialogState(() {
                              institute = choice!;
                              programs = choices[institute] ?? const [];
                              program = programs.firstOrNull ?? '';
                            }),
                          ),
                        ),
                        if (kind == 'STUDENT')
                          SizedBox(
                            width: 250,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('$institute:$program'),
                              initialValue: program.isEmpty ? null : program,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Program',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final choice in programs)
                                  DropdownMenuItem(
                                    value: choice,
                                    child: Text(
                                      choice,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Choose a program.'
                                  : null,
                              onChanged: (choice) =>
                                  setDialogState(() => program = choice!),
                            ),
                          )
                        else
                          SizedBox(
                            width: 250,
                            child: DropdownButtonFormField<String>(
                              initialValue: position,
                              decoration: const InputDecoration(
                                labelText: 'Position',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final choice in facultyPositions)
                                  DropdownMenuItem(
                                    value: choice,
                                    child: Text(choice),
                                  ),
                              ],
                              onChanged: (choice) =>
                                  setDialogState(() => position = choice!),
                            ),
                          ),
                        field(fields['school_email']!, 'School email'),
                        field(
                          fields['contact']!,
                          'Contact number',
                          optional: true,
                        ),
                        field(
                          fields['gmail']!,
                          'Gmail address',
                          optional: true,
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active user'),
                      subtitle: const Text(
                        'Turn this off to stop this ID from using request and support forms.',
                      ),
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Confirm the database change with your current admin credentials.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        field(username, 'Admin username'),
                        field(password, 'Admin password', secret: true),
                      ],
                    ),
                  ],
                ),
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
                Navigator.pop(dialogContext, {
                  'person_kind': kind,
                  'person_id': id,
                  for (final entry in fields.entries)
                    entry.key: entry.value.text.trim(),
                  'institute': institute,
                  'program': kind == 'STUDENT' ? program : '',
                  'position': kind == 'FACULTY' ? position : '',
                  'active': active,
                  'username': username.text.trim(),
                  'password': password.text,
                });
              },
              child: const Text('Confirm and save'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [...fields.values, username, password]) {
      controller.dispose();
    }
    if (values == null) return;
    await _changeUser(
      'registry/${Uri.encodeComponent(id)}/update',
      values,
      'User data updated in the database.',
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> row) async {
    if (_changingUser) return;
    final username = TextEditingController(
      text: ref.read(authControllerProvider).user?.username ?? '',
    );
    final password = TextEditingController();
    final id = display(row['person_id']);
    final name = [
      row['first_name'],
      row['middle_name'],
      row['last_name'],
    ].where((value) => value != null && value.toString().isNotEmpty).join(' ');
    final form = GlobalKey<FormState>();
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Permanently delete $name?'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ID $id will be removed from the database. This cannot be undone. Old requests and audit history will be kept.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'Enter your current admin credentials to confirm.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: username,
                  decoration: const InputDecoration(
                    labelText: 'Admin username',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Admin password',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              if (form.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, {
                'username': username.text.trim(),
                'password': password.text,
              });
            },
            child: const Text('Confirm permanent delete'),
          ),
        ],
      ),
    );
    username.dispose();
    password.dispose();
    if (values == null) return;
    await _changeUser(
      'registry/${Uri.encodeComponent(id)}/delete',
      values,
      'User data permanently deleted from the database.',
    );
  }

  Future<void> _changeUser(
    String path,
    Map<String, dynamic> values,
    String success,
  ) async {
    setState(() {
      _changingUser = true;
      _message = null;
      _error = null;
    });
    try {
      await portalPost(ref, path, values);
      ref.invalidate(portalDataProvider(_path));
      if (mounted) setState(() => _message = success);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _changingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(portalDataProvider(_path));
    final settingData = ref.watch(portalDataProvider('settings')).asData?.value;
    final catalog = <String, List<String>>{
      for (final institution
          in (settingData?['institutions'] as List? ?? const []))
        if (institution is Map && institution['name'] is String)
          institution['name'] as String: [
            for (final program
                in (institution['programs'] as List? ?? const []))
              if (program is Map && program['name'] is String)
                program['name'] as String,
          ],
    };
    if (catalog.isEmpty) {
      catalog.addAll(institutePrograms);
    }
    if (!catalog.containsKey(_institute)) {
      _institute = catalog.keys.first;
      _program = catalog[_institute]!.firstOrNull ?? '';
    } else if (!(catalog[_institute] ?? const []).contains(_program)) {
      _program = catalog[_institute]!.firstOrNull ?? '';
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminHeading(
          'Manage Users',
          'Add trusted student and faculty records used for chat and account-request verification.',
          action: IconButton(
            tooltip: 'Refresh users',
            onPressed: () => ref.invalidate(portalDataProvider(_path)),
            icon: const Icon(Icons.refresh),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add one user',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The ID number is the primary key and must be unique.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _select('User type', _kind, const [
                        'STUDENT',
                        'FACULTY',
                      ], (value) => setState(() => _kind = value)),
                      _textField(
                        'person_id',
                        'ID number',
                        hint: _kind == 'STUDENT' ? '123456' : 'AB1234',
                      ),
                      _textField('first_name', 'First name'),
                      _textField('middle_name', 'Middle name', optional: true),
                      _textField('last_name', 'Last name'),
                      _select(
                        'Institute',
                        _institute,
                        catalog.keys.toList(),
                        (value) => setState(() {
                          _institute = value;
                          _program = catalog[value]!.firstOrNull ?? '';
                        }),
                      ),
                      if (_kind == 'STUDENT')
                        _select(
                          'Program',
                          _program,
                          catalog[_institute] ?? const [],
                          (value) => setState(() => _program = value),
                        )
                      else
                        _select(
                          'Position',
                          _position,
                          facultyPositions,
                          (value) => setState(() => _position = value),
                        ),
                      _textField('school_email', 'School email'),
                      _textField('contact', 'Contact number', optional: true),
                      _textField('gmail', 'Gmail address', optional: true),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _addUser,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(_saving ? 'Adding user...' : 'Add user data'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mass import',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload CSV or Excel (.xlsx), up to 1,000 rows and 5 MB. Existing IDs are reported and skipped while other valid rows continue.',
                ),
                const SizedBox(height: 8),
                const SelectableText(
                  'Required columns: person_kind, person_id, first_name, last_name, institute, school_email\nOptional: middle_name, program, position, contact, gmail, active',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _importing ? null : _import,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _importing ? 'Importing...' : 'Upload Excel or CSV',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _message!,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),
        if (_duplicates.isNotEmpty || _importErrors.isNotEmpty)
          Card(
            color: scheme.errorContainer.withValues(alpha: .35),
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rows not added',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final item in [..._duplicates, ..._importErrors])
                    Text('• $item'),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'STUDENT', label: Text('Students')),
                ButtonSegment(value: 'FACULTY', label: Text('Faculty')),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => setState(() {
                _kind = value.first;
                _page = 0;
              }),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                onSubmitted: (_) => setState(() => _page = 0),
                decoration: InputDecoration(
                  hintText: 'Search name or ID number',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: () => setState(() => _page = 0),
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Tap a student or faculty row to edit it. Use the delete button on the right to permanently remove it.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        if (_changingUser) const LinearProgressIndicator(),
        data.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Unable to load user records.'),
          data: (value) {
            final rows = (value['rows'] as List).cast<Map<String, dynamic>>();
            if (rows.isEmpty) {
              return const AdminEmptyState(
                title: 'No matching users',
                message: 'Try another name, ID number, or user type.',
                icon: Icons.people_outline,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminTable(
                  columns: const [
                    'ID number',
                    'Name',
                    'Type',
                    'Institute',
                    'School email',
                    'Status',
                    'Action',
                  ],
                  rows: [
                    for (final row in rows)
                      [
                        Text(display(row['person_id'])),
                        Text(
                          [
                                row['first_name'],
                                row['middle_name'],
                                row['last_name'],
                              ]
                              .where(
                                (value) =>
                                    value != null &&
                                    value.toString().isNotEmpty,
                              )
                              .join(' '),
                        ),
                        Text(display(row['person_kind'])),
                        SizedBox(
                          width: 180,
                          child: Text(display(row['institute'])),
                        ),
                        Text(display(row['school_email'])),
                        Text(row['active'] == true ? 'Active' : 'Inactive'),
                        IconButton(
                          tooltip: 'Permanently delete this user',
                          onPressed: _changingUser
                              ? null
                              : () => _deleteUser(row),
                          color: scheme.error,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                  ],
                  onSelect: [
                    for (final row in rows)
                      _changingUser ? null : () => _editUser(row, catalog),
                  ],
                ),
                AdminPagination(
                  page: _page,
                  onPrevious: _page == 0 ? null : () => setState(() => _page--),
                  onNext: rows.length < 25
                      ? null
                      : () => setState(() => _page++),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
