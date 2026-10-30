import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:request_contract/request_contract.dart';

import '../../../../core/network/api_client.dart';
import '../../../requests/presentation/request_widgets.dart';
import '../widgets/admin_widgets.dart';

class RequestInbox extends ConsumerStatefulWidget {
  const RequestInbox({super.key});
  @override
  ConsumerState<RequestInbox> createState() => _RequestInboxState();
}

class _RequestInboxState extends ConsumerState<RequestInbox> {
  String _kind = '', _type = '';
  int _page = 0;
  late Future<List<Map<String, dynamic>>> _requests;
  @override
  void initState() {
    super.initState();
    _requests = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/admin/requests?kind=$_kind&type=$_type&page=$_page',
        );
    return (result.data!['requests'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  void _refresh({bool reset = false}) => setState(() {
    if (reset) _page = 0;
    _requests = _load();
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Account Requests',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          DropdownButton<String>(
            value: _kind,
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Students and faculty'),
              ),
              ...PersonKind.values.map(
                (v) => DropdownMenuItem(value: v.code, child: Text(v.label)),
              ),
            ],
            onChanged: (v) {
              _kind = v!;
              _refresh(reset: true);
            },
          ),
          DropdownButton<String>(
            value: _type,
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('All request types'),
              ),
              ...RequestKind.values.map(
                (v) => DropdownMenuItem(value: v.code, child: Text(v.label)),
              ),
            ],
            onChanged: (v) {
              _type = v!;
              _refresh(reset: true);
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return const Text(
              'Unable to load requests. Check your connection and permissions.',
            );
          }
          final rows = snapshot.data!;
          return Column(
            children: [
              if (rows.isEmpty)
                const AdminEmptyState(
                  title: 'No requests on this page',
                  icon: Icons.inbox_outlined,
                ),
              for (final row in rows)
                ExpansionTile(
                  key: ValueKey(row['id']),
                  title: Text(row['reference'] as String),
                  subtitle: Text(
                    '${row['person_kind']} · ${row['request_type']} · ${row['status']}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: RequestSummary(
                        title: 'Submitted information',
                        rows: {
                          for (final entry
                              in ((row['payload'] as Map)['fields'] as Map)
                                  .entries)
                            if (entry.value.toString().isNotEmpty)
                              entry.key.toString(): entry.value.toString(),
                        },
                      ),
                    ),
                  ],
                ),
              AdminPagination(
                page: _page,
                onPrevious: _page == 0
                    ? null
                    : () {
                        _page--;
                        _refresh();
                      },
                onNext: rows.length < 25
                    ? null
                    : () {
                        _page++;
                        _refresh();
                      },
              ),
            ],
          );
        },
      ),
    ],
  );
}
