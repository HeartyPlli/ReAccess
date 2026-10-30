import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../requests/presentation/request_widgets.dart';
import '../../data/portal_repository.dart';
import '../widgets/admin_widgets.dart';

class RequestReviewPage extends ConsumerStatefulWidget {
  const RequestReviewPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<RequestReviewPage> createState() => _RequestReviewPageState();
}

class _RequestReviewPageState extends ConsumerState<RequestReviewPage> {
  final _notes = TextEditingController();
  bool _letter = false, _loaded = false, _busy = false;
  String? _message;
  Future<void> _edit(Map row) async {
    final update = row['request_type'] == 'UPDATE';
    final fields =
        ((row['work_payload'] ?? row['payload']) as Map)['fields'] as Map;
    final gmail = TextEditingController(
      text: display(fields[update ? 'alternativeGmail' : 'gmail']),
    );
    final contact = TextEditingController(
      text: display(fields[update ? 'newContact' : 'contact']),
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Approved Contacts'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: gmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Gmail Address'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contact,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final values = {'gmail': gmail.text, 'contact': contact.text};
    // Dialog fields may still be mounted during their closing animation.
    Future<void>.delayed(const Duration(seconds: 1), () {
      gmail.dispose();
      contact.dispose();
    });
    if (save != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .post('/admin/portal/requests/${widget.id}/contacts', data: values);
      ref.invalidate(portalDataProvider);
      if (mounted) {
        setState(
          () => _message =
              'Approved contacts saved. Original submission retained.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _act(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(switch (action) {
          'approve' => 'Approve this request?',
          'reject' => 'Reject this request?',
          'done' => 'Mark the work as done?',
          _ => 'Add this account to the registry?',
        }),
        content: const Text(
          'Confirm only after reviewing the identity and completing the required office checks. This action will be recorded in the audit log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/admin/portal/requests/${widget.id}/decision',
            data: {
              'action': action,
              'notes': _notes.text,
              'requiresLetter': _letter,
            },
          );
      ref.invalidate(portalDataProvider);
      if (mounted) {
        setState(
          () => _message = 'Saved. Notification delivery is tracked below.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go('/admin/requests'),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Back to Requests'),
        ),
      ),
      const AdminHeading(
        'Review Request',
        'Review the details before making a decision.',
      ),
      ref
          .watch(portalDataProvider('requests/${widget.id}'))
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text(
              'Unable to load this request. Check your connection and permissions.',
            ),
            data: (row) {
              if (!_loaded) {
                _notes.text = display(row['reviewer_notes']);
                _letter = row['requires_letter'] == true;
                _loaded = true;
              }
              final fields = ((row['payload'] as Map)['fields'] as Map);
              final workFields =
                  ((row['work_payload'] ?? row['payload']) as Map)['fields']
                      as Map;
              final status = display(row['status']);
              final history = (row['history'] as List).cast<Map>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RequestSummary(
                    title: 'Request Details',
                    rows: {
                      'Reference': display(row['reference']),
                      'Request type': requestType(row['request_type']),
                      'User type': display(row['person_kind']),
                      'Status': status,
                      'Submitted': display(row['created_at']),
                      'Requests submitted': display(row['requestCount']),
                    },
                  ),
                  RequestSummary(
                    title: 'Personal Information',
                    rows: {
                      'Name': requestName(row),
                      'ID': display(row['person_id']),
                      'Institute': display(fields['institute']),
                      if (display(fields['program']).isNotEmpty)
                        'Program': display(fields['program']),
                      if (display(fields['position']).isNotEmpty)
                        'Position': display(fields['position']),
                      'School email': display(fields['schoolEmail']),
                      'Gmail': display(fields['gmail']),
                      'Contact': display(fields['contact']),
                    },
                  ),
                  RequestSummary(
                    title: 'Request Information',
                    rows: {
                      if (row['request_type'] == 'RECOVERY')
                        'Reason': display(fields['reason']),
                      if (row['request_type'] == 'UPDATE') ...{
                        'New Gmail': display(fields['alternativeGmail']),
                        'New contact': display(fields['newContact']),
                      },
                      'Notes': display(fields['notes']),
                    },
                  ),
                  AdminSectionCard(
                    title: 'Review decision',
                    subtitle:
                        'Add an internal note and choose the next action.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _notes,
                          maxLines: 3,
                          maxLength: 2000,
                          enabled: !_busy && status != 'COMPLETED',
                          decoration: const InputDecoration(
                            labelText: 'Reviewer Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Provide letter'),
                          subtitle: const Text(
                            'Include the formal-letter requirement and configured template.',
                          ),
                          value: _letter,
                          onChanged: _busy || status == 'COMPLETED'
                              ? null
                              : (v) => setState(() => _letter = v),
                        ),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(_message!),
                          ),
                        if (_busy) const LinearProgressIndicator(),
                        if (row['work_payload'] != null)
                          RequestSummary(
                            title: 'Approved Contact Corrections',
                            rows: {
                              'Gmail': display(
                                workFields[row['request_type'] == 'UPDATE'
                                    ? 'alternativeGmail'
                                    : 'gmail'],
                              ),
                              'Contact': display(
                                workFields[row['request_type'] == 'UPDATE'
                                    ? 'newContact'
                                    : 'contact'],
                              ),
                            },
                          ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (status == 'APPROVED' &&
                                [
                                  'SSPR',
                                  'UPDATE',
                                ].contains(row['request_type']))
                              OutlinedButton.icon(
                                onPressed: _busy ? null : () => _edit(row),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit Contacts'),
                              ),
                            if ([
                              'PENDING',
                              'IN_REVIEW',
                              'REJECTED',
                            ].contains(status))
                              FilledButton.icon(
                                onPressed: _busy ? null : () => _act('approve'),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve Request'),
                              ),
                            if ([
                              'PENDING',
                              'IN_REVIEW',
                              'APPROVED',
                            ].contains(status))
                              OutlinedButton.icon(
                                onPressed: _busy ? null : () => _act('reject'),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject Request'),
                              ),
                            if (status == 'APPROVED')
                              FilledButton.icon(
                                onPressed: _busy ? null : () => _act('done'),
                                icon: const Icon(Icons.task_alt),
                                label: const Text('Done'),
                              ),
                            if (status == 'COMPLETED' &&
                                row['request_type'] == 'SSPR' &&
                                row['registry_applied'] != true)
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _act('register'),
                                icon: const Icon(Icons.verified_user_outlined),
                                label: const Text('Complete SSPR enrollment'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AdminSectionCard(
                    title: 'Request History',
                    child: Column(
                      children: [
                        for (final event in history)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history, size: 18),
                            title: Text(
                              display(event['action']).replaceAll('_', ' '),
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '${event['created_at']}\n${event['description'] ?? ''}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  AdminSectionCard(
                    title: 'Notification Delivery',
                    child: (row['delivery'] as List).isEmpty
                        ? const AdminEmptyState(
                            title: 'No notification deliveries queued',
                            icon: Icons.notifications_none_outlined,
                          )
                        : Column(
                            children: [
                              for (final delivery in row['delivery'] as List)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${delivery['channel']} - ${delivery['status']}',
                                  ),
                                  subtitle: Text(
                                    'Attempts: ${delivery['attempts']}',
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
    ],
  );
}
