import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:request_contract/request_contract.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/config/app_config.dart';
import '../data/request_repository.dart';
import 'request_widgets.dart';
import '../../../shared/widgets/theme_toggle.dart';

class RequestPage extends ConsumerStatefulWidget {
  const RequestPage({super.key, required this.person});
  final PersonKind person;
  @override
  ConsumerState<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends ConsumerState<RequestPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _fields = <String, TextEditingController>{
    for (final key in [...RequestData.personalKeys, ...RequestData.detailKeys])
      key: TextEditingController(),
  };
  int _step = 0;
  RequestKind? _kind;
  Verification? _verification;
  String? _error, _reference;
  bool _busy = false;
  final _touched = <String>{};
  Map<String, List<String>> _catalog = {
    for (final entry in institutePrograms.entries)
      entry.key: List<String>.from(entry.value),
  };
  int _studentRequestLimit = 0;

  @override
  void initState() {
    super.initState();
    _loadRequestSettings();
  }

  Future<void> _loadRequestSettings() async {
    try {
      final settings = await ref.read(requestRepositoryProvider).settings();
      if (!mounted || settings.institutions.isEmpty) return;
      setState(() {
        _catalog = settings.institutions;
        _studentRequestLimit = settings.studentRequestLimit;
      });
    } catch (_) {
      // Keep the bundled catalog available while the configuration service is
      // starting. Submission is still validated by the backend.
    }
  }

  RequestData get _data => RequestData.fromJson({
    'personKind': widget.person.code,
    'requestKind': (_kind ?? RequestKind.sspr).code,
    'fields': {
      for (final entry in _fields.entries) entry.key: entry.value.text,
    },
  });
  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _move(int step) {
    setState(() {
      _step = step;
      _error = null;
      if (step < 2) _verification = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0) {
      if (_kind == null) {
        setState(() => _error = 'Choose a request type.');
        return;
      }
      _move(1);
    } else if (_step == 1 || _step == 3) {
      setState(() => _touched.addAll(_fields.keys));
      if (!_form.currentState!.validate()) return;
      _move(_step + 1);
    } else {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final repository = ref.read(requestRepositoryProvider);
        if (_step == 2) {
          final verification = await repository.verify(_data);
          if (!mounted) return;
          _verification = verification;
          _move(3);
        } else {
          if (_verification == null) {
            _move(2);
            return;
          }
          final reference = await repository.submit(
            _data,
            _verification!.token,
          );
          if (!mounted) return;
          setState(() => _reference = reference);
          _scroll.jumpTo(0);
        }
      } on AppException catch (e) {
        if (mounted) setState(() => _error = e.message);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'The request could not be completed. Please try again. Nothing is confirmed until you receive a reference ID.',
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    bool name = false,
    int lines = 1,
    bool optional = false,
  }) {
    final error = _data.validate(
      details: _step == 3,
      instituteCatalog: _catalog,
    )[key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        key: ValueKey(key),
        controller: _fields[key],
        enabled: !_busy,
        minLines: lines,
        maxLines: lines,
        maxLength: key == 'personId' ? 6 : (lines > 1 ? 2000 : 254),
        inputFormatters: name ? [NameCapitalizer()] : null,
        textCapitalization: name
            ? TextCapitalization.words
            : TextCapitalization.none,
        keyboardType:
            key.toLowerCase().contains('gmail') || key == 'schoolEmail'
            ? TextInputType.emailAddress
            : (key == 'personId' && widget.person == PersonKind.student) ||
                  key.toLowerCase().contains('contact')
            ? TextInputType.phone
            : TextInputType.text,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) => setState(() => _touched.add(key)),
        style: TextStyle(
          fontSize: 14,
          color: _touched.contains(key) && error != null
              ? Theme.of(context).colorScheme.error
              : null,
        ),
        decoration: InputDecoration(
          labelText: '$label${optional ? '' : ' *'}',
          hintText: hint,
          counterText: '',
          errorMaxLines: 3,
          alignLabelWithHint: lines > 1,
          border: const OutlineInputBorder(),
        ),
        validator: (_) => _data.validate(
          details: _step == 3,
          instituteCatalog: _catalog,
        )[key],
      ),
    );
  }

  Widget _dropdown(
    String key,
    String label,
    List<String> values, {
    bool disabled = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$key:${_fields[key]!.text}'),
      initialValue: values.contains(_fields[key]!.text)
          ? _fields[key]!.text
          : null,
      isExpanded: true,
      isDense: false,
      itemHeight: null,
      decoration: InputDecoration(
        labelText: '$label *',
        border: const OutlineInputBorder(),
        errorMaxLines: 3,
      ),
      hint: Text(
        disabled
            ? 'Select an institute first'
            : 'Select ${label.toLowerCase()}',
      ),
      items: values
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(value, style: const TextStyle(fontSize: 13)),
              ),
            ),
          )
          .toList(),
      onChanged: disabled || _busy
          ? null
          : (value) => setState(() {
              _fields[key]!.text = value ?? '';
              if (key == 'institute') {
                final programs = _catalog[value] ?? [];
                _fields['program']!.text = programs.length == 1
                    ? programs.single
                    : '';
              }
            }),
      validator: (_) =>
          _data.validate(details: false, instituteCatalog: _catalog)[key],
    ),
  );

  Widget _personal() => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            _field('firstName', 'First Name', hint: 'Juan', name: true),
            _field(
              'middleName',
              'Middle Name',
              hint: 'Optional',
              name: true,
              optional: true,
            ),
            _field('lastName', 'Last Name', hint: 'Dela Cruz', name: true),
          ];
          if (constraints.maxWidth < 480) return Column(children: fields);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: fields[i]),
              ],
            ],
          );
        },
      ),
      _field(
        'personId',
        '${widget.person.label} ID',
        hint: widget.person == PersonKind.student ? '123456' : 'AB1234',
      ),
      _dropdown(
        'institute',
        widget.person == PersonKind.student
            ? 'Institute'
            : 'Institute / Department',
        _catalog.keys.toList(),
      ),
      if (widget.person == PersonKind.student)
        _dropdown(
          'program',
          'Program',
          _catalog[_fields['institute']!.text] ?? [],
          disabled: _fields['institute']!.text.isEmpty,
        )
      else
        _dropdown('position', 'Position', facultyPositions),
      if (_data.requiresSchoolEmail)
        _field(
          'schoolEmail',
          'School Email',
          hint: 'lastnamefirstname@gadtc.edu.ph',
        ),
      if (_data.requiresContact) ...[
        _field('contact', 'Contact Number', hint: '09XXXXXXXXX'),
        _field('gmail', 'Gmail Address', hint: 'yourname@gmail.com'),
      ],
    ],
  );

  Map<String, String> get _personalRows => {
    'Name': [
      'firstName',
      'middleName',
      'lastName',
    ].map((k) => _data[k]).where((s) => s.isNotEmpty).join(' '),
    '${widget.person.label} ID': _data['personId'],
    'Institute': _data['institute'],
    if (widget.person == PersonKind.student)
      'Program': _data['program']
    else
      'Position': _data['position'],
    if (_data.requiresSchoolEmail) 'School email': _data['schoolEmail'],
    if (_data.requiresContact) ...{
      'Contact': _data['contact'],
      'Gmail': _data['gmail'],
    },
  };

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_verification != null) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            widget.person == PersonKind.student &&
                    _verification!.studentRequestLimit > 0
                ? 'Request ${_verification!.previousRequests + 1} for this service · limit ${_verification!.studentRequestLimit}'
                : 'Previous requests submitted: ${_verification!.previousRequests}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (_verification!.requiresFormalLetter) ...[
          const RequestNotice(
            'You have reached the student request limit for this service. Download the formal letter, complete it without passwords or verification codes, and bring it with your supporting documents to the CISO Office.',
          ),
          OutlinedButton.icon(
            onPressed: _openTemplate,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download formal letter'),
          ),
          const SizedBox(height: 20),
        ],
      ],
      if (_kind == RequestKind.recovery) ...[
        _field(
          'reason',
          'Reason for Account Recovery',
          hint: 'Describe what happened to your account...',
          lines: 3,
        ),
        if (widget.person == PersonKind.student &&
            _verification?.requiresFormalLetter != true) ...[
          const RequestNotice(
            'Submit a formal letter and supporting documents to the CISO Office for review. Do not include your password or verification codes.',
          ),
          OutlinedButton.icon(
            onPressed: _openTemplate,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open formal letter template'),
          ),
        ],
      ],
      if (_kind == RequestKind.update) ...[
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'Provide a new alternative Gmail address, a contact number, or both.',
          ),
        ),
        _field(
          'alternativeGmail',
          'Alternative Gmail Address',
          hint: 'yourname@gmail.com',
          optional: true,
        ),
        _field(
          'newContact',
          'Contact Number',
          hint: '09XXXXXXXXX',
          optional: true,
        ),
      ],
      _field(
        'notes',
        'Additional Notes',
        hint: 'Any additional information...',
        optional: true,
        lines: 3,
      ),
    ],
  );

  Future<void> _openTemplate() async {
    final uri = Uri.base.resolve(AppConfig.recoveryLetterUrl);
    if (!['https', 'http'].contains(uri.scheme)) {
      return;
    }
    if (!await launchUrl(uri, webOnlyWindowName: '_blank') && mounted) {
      setState(() => _error = 'The template could not be opened.');
    }
  }

  Widget _content() {
    if (_step == 0) {
      return Column(
        children: [
          if (widget.person == PersonKind.student && _studentRequestLimit > 0)
            RequestNotice(
              'Student request limit: $_studentRequestLimit per request type. A formal letter is required starting with request ${_studentRequestLimit + 1}.',
            ),
          for (final kind in RequestKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: _kind == kind
                    ? Theme.of(context).colorScheme.surfaceContainer
                    : Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: _kind == kind
                        ? requestAccent
                        : const Color(0xFFD7D8E8),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() {
                    _kind = kind;
                    _verification = null;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kind.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                kind.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_kind == kind)
                          const Icon(
                            Icons.check_circle,
                            color: requestAccent,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    if (_step == 1) return _personal();
    if (_step == 2) {
      return RequestSummary(
        title: 'Confirm your information',
        rows: _personalRows,
      );
    }
    if (_step == 3) return _details();
    return Column(
      children: [
        RequestSummary(title: 'Request Type', rows: {'Type': _kind!.label}),
        RequestSummary(
          title: '${widget.person.label} Information',
          rows: _personalRows,
        ),
        RequestSummary(
          title: 'Request Details',
          rows: {
            if (_kind == RequestKind.recovery) 'Reason': _data['reason'],
            if (_kind == RequestKind.update) ...{
              'New Gmail': _data['alternativeGmail'],
              'New contact': _data['newContact'],
            },
            'Notes': _data['notes'],
          },
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'Your information is sent to the CISO Office for staff review. Submitting this request does not automatically change your account.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _success() => Column(
    children: [
      const CircleAvatar(
        radius: 30,
        backgroundColor: Color(0xFFD8EFDC),
        child: Icon(Icons.check_circle_outline, color: Colors.green, size: 30),
      ),
      const SizedBox(height: 20),
      const Text(
        'Request Submitted!',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      const Text(
        'Your request has been submitted to the CISO Office.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      const Text('Reference ID', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      SelectableText(
        _reference!,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: requestAccent,
        ),
      ),
      RequestNotice(switch (_kind!) {
        RequestKind.sspr => 'Your SSPR enrollment is awaiting staff review. Keep your reference ID and contact the CISO Office for updates.',
        RequestKind.recovery =>
          widget.person == PersonKind.student
              ? 'Bring your formal letter and supporting documents to the CISO Office. Keep this reference ID for your account recovery follow-up.'
              : 'The CISO Office will review your account recovery request and verify your identity before taking action. Keep this reference ID.',
        RequestKind.update => 'Your requested contact changes are awaiting staff review. Your registered details will not change until the CISO Office approves them.',
      }),
      if (_verification?.requiresFormalLetter == true) ...[
        OutlinedButton.icon(
          onPressed: _openTemplate,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download formal letter'),
        ),
        const SizedBox(height: 16),
      ],
      const Text(
        'Email and SMS notifications are not enabled yet.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => context.go('/'),
          child: const Text('Return to Home'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF232325)
        : const Color(0xFFF1F0F0),
    appBar: AppBar(
      actions: const [ThemeToggle(onDarkBackground: true), SizedBox(width: 12)],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/school_pic_top_view.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Color(0xDD14212A), BlendMode.srcATop),
          ),
        ),
      ),
      backgroundColor: const Color(0xFF202B32),
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: 'Back to home',
        onPressed: _busy ? null : () => context.go('/'),
        icon: const Icon(Icons.arrow_back),
      ),
      title: Row(
        children: [
          Image.asset('assets/images/reaccess_logo.png', width: 30, height: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ReAccess Hub',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${widget.person.label} Request - CISO Office',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    body: SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              if (_reference == null) ...[
                RequestProgress(step: _step, kind: _kind),
                const SizedBox(height: 26),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD7D8E8)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: _reference != null
                    ? _success()
                    : Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              requestStages[_step],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(switch (_step) {
                              0 => 'Choose the type of Office 365 account service you need.',
                              1 => 'Enter your information carefully. Required fields are marked *.',
                              2 =>
                                _kind == RequestKind.sspr
                                    ? 'Confirm your information. We will check for an existing account or pending enrollment.'
                                    : 'We will check your information against registered records.',
                              3 =>
                                'Provide the information needed for your ${_kind!.label}.',
                              _ => 'Review your request before submitting.',
                            }, style: const TextStyle(fontSize: 13, height: 1.5)),
                            const SizedBox(height: 26),
                            _content(),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            if (_busy)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: LinearProgressIndicator(),
                              ),
                            Row(
                              children: [
                                if (_step > 0) ...[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _move(_step - 1),
                                      child: const Text('Back'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: requestAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _busy ? null : _next,
                                    child: Text(switch (_step) {
                                      2 => 'Verify Identity',
                                      3 => 'Review',
                                      4 => 'Submit Request',
                                      _ => 'Next',
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
