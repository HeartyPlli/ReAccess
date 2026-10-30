import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../widgets/admin_widgets.dart';

final supportInboxProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  ref.watch(authControllerProvider);
  final response = await ref
      .read(apiClientProvider)
      .get<Map<String, dynamic>>('/admin/support');
  return (response.data!['tickets'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

class SupportInbox extends ConsumerWidget {
  const SupportInbox({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(supportInboxProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'CISO support inbox',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh inbox',
              onPressed: () => ref.invalidate(supportInboxProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 24),
        tickets.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error is AppException
                    ? error.message
                    : 'Unable to load the inbox.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(supportInboxProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? const AdminEmptyState(
                  title: 'No support conversations yet',
                  message: 'New public help requests will appear here.',
                  icon: Icons.support_agent_outlined,
                )
              : Column(
                  children: [
                    for (final ticket in items) _Ticket(ticket: ticket),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Ticket extends ConsumerStatefulWidget {
  const _Ticket({required this.ticket});
  final Map<String, dynamic> ticket;
  @override
  ConsumerState<_Ticket> createState() => _TicketState();
}

class _TicketState extends ConsumerState<_Ticket> {
  final _reply = TextEditingController();
  bool _sending = false, _deleting = false;
  String? _error;
  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty || _sending || _deleting) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/admin/support/${widget.ticket['id']}/reply',
            data: {'reply': _reply.text.trim()},
          );
      if (!mounted) return;
      _reply.clear();
      ref.invalidate(supportInboxProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Reply was not sent. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete() async {
    if (_sending || _deleting) return;
    final username = TextEditingController(
      text: ref.read(authControllerProvider).user?.username ?? '',
    );
    final password = TextEditingController();
    final form = GlobalKey<FormState>();
    final values = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently delete this conversation?'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 460,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'The support conversation for ID ${widget.ticket['person_id']} will be removed from the chat list and database. The visitor will no longer be able to check its reply. The audit record will be kept.',
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
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your username.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Admin password',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
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
          FilledButton.icon(
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
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Confirm permanent delete'),
          ),
        ],
      ),
    );
    username.dispose();
    password.dispose();
    if (values == null || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/admin/support/${widget.ticket['id']}/delete',
            data: values,
          );
      ref.invalidate(supportInboxProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support conversation permanently deleted.'),
          ),
        );
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The conversation was not deleted. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final transcript = ticket['transcript'] as List;
    final questions = transcript.where((e) => e['role'] == 'user');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          title: Text(
            questions.isEmpty
                ? 'Support question'
                : questions.last['text'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'ID ${ticket['person_id']} · ${ticket['status']} · ${ticket['created_at']}',
          ),
          trailing: IconButton(
            tooltip: 'Permanently delete conversation',
            onPressed: _sending || _deleting ? null : _delete,
            color: Theme.of(context).colorScheme.error,
            icon: _deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
          childrenPadding: const EdgeInsets.all(20),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Visitor-submitted conversation',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            for (final message in transcript)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    '${message['role']}: ${message['text']}',
                  ),
                ),
              ),
            if (ticket['reply'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Office reply'),
                subtitle: Text(ticket['reply'] as String),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _reply,
              enabled: !_sending,
              maxLength: 4000,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Office reply',
                helperText:
                    'Do not include passwords, codes, or personal records.',
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Sending...' : 'Send reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
