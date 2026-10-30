import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/portal_repository.dart';
import '../widgets/admin_widgets.dart';
import 'support_inbox.dart';

class PortalMessagesPage extends ConsumerStatefulWidget {
  const PortalMessagesPage({super.key});
  @override
  ConsumerState<PortalMessagesPage> createState() => _PortalMessagesPageState();
}

class _PortalMessagesPageState extends ConsumerState<PortalMessagesPage> {
  String? _id, _notice;
  String _kind = '';
  bool _priority = false, _busy = false;
  int _page = 0;
  final _input = TextEditingController();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_id == null || _input.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/admin/portal/requests/$_id/message',
            data: {'body': _input.text.trim()},
          );
      _input.clear();
      ref.invalidate(portalDataProvider('requests/$_id'));
      if (mounted) {
        setState(
          () => _notice = 'Message saved. Email is queued for delivery.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _notice = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AdminHeading(
        'Messages',
        'Communications about submitted account-service requests.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '', label: Text('All')),
              ButtonSegment(value: 'STUDENT', label: Text('Students')),
              ButtonSegment(value: 'FACULTY', label: Text('Faculty')),
            ],
            selected: {_kind},
            onSelectionChanged: (v) => setState(() {
              _kind = v.first;
              _page = 0;
            }),
          ),
          FilterChip(
            label: const Text('Priority'),
            selected: _priority,
            onSelected: (v) => setState(() {
              _priority = v;
              _page = 0;
            }),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ref
          .watch(
            portalDataProvider(
              'requests?kind=$_kind&priority=${_priority ? 'true' : ''}&page=$_page',
            ),
          )
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Unable to load conversations.'),
            data: (d) => LayoutBuilder(
              builder: (context, c) {
                final rows = (d['rows'] as List).cast<Map<String, dynamic>>();
                final list = Column(
                  children: [
                    for (final r in rows)
                      ListTile(
                        selected: _id == r['id'],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: .45),
                        title: Text(requestName(r)),
                        subtitle: Text(display(r['reference'])),
                        trailing: r['priority'] == true
                            ? const Icon(
                                Icons.flag,
                                color: Colors.red,
                                size: 18,
                              )
                            : null,
                        onTap: () => setState(() {
                          _id = r['id'] as String;
                          _notice = null;
                        }),
                      ),
                    if (rows.isEmpty)
                      const AdminEmptyState(
                        title: 'No matching conversations',
                        icon: Icons.forum_outlined,
                      ),
                    AdminPagination(
                      page: _page,
                      onPrevious: _page == 0
                          ? null
                          : () => setState(() => _page--),
                      onNext: rows.length < 25
                          ? null
                          : () => setState(() => _page++),
                    ),
                  ],
                );
                final conversation = _id == null
                    ? const AdminEmptyState(
                        title: 'Select a request',
                        message: 'Choose a conversation from the list to read and reply.',
                        icon: Icons.mark_chat_unread_outlined,
                      )
                    : ref
                          .watch(portalDataProvider('requests/$_id'))
                          .when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) =>
                                const Text('Unable to open conversation.'),
                            data: (r) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SwitchListTile(
                                  title: Text(requestName(r)),
                                  subtitle: const Text('Priority conversation'),
                                  value: r['priority'] == true,
                                  onChanged: (value) async {
                                    try {
                                      await ref
                                          .read(apiClientProvider)
                                          .post(
                                            '/admin/portal/requests/$_id/priority',
                                            data: {'priority': value},
                                          );
                                      ref.invalidate(portalDataProvider);
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => _notice = e.toString());
                                      }
                                    }
                                  },
                                ),
                                const Divider(),
                                if ((r['messages'] as List).isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No staff messages yet.'),
                                  ),
                                for (final m in r['messages'] as List)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SelectableText(display(m['body'])),
                                        const SizedBox(height: 6),
                                        Text(
                                          display(m['created_at']),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: _input,
                                  maxLines: 3,
                                  maxLength: 4000,
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message to the user...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                if (_notice != null) Text(_notice!),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: _busy ? null : _send,
                                    icon: const Icon(Icons.send, size: 16),
                                    label: const Text('Send'),
                                  ),
                                ),
                              ],
                            ),
                          );
                if (c.maxWidth < 750) {
                  return Column(
                    children: [list, const SizedBox(height: 24), conversation],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 300, child: list),
                    const SizedBox(width: 28),
                    Expanded(child: conversation),
                  ],
                );
              },
            ),
          ),
      const Divider(height: 48),
      const Text(
        'Public Help Chat',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      const SupportInbox(),
    ],
  );
}
