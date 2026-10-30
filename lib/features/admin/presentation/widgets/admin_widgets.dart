import 'package:flutter/material.dart';

String display(Object? value) => value?.toString() ?? '';
String requestName(Map<String, dynamic> row) {
  final f = (row['payload'] as Map?)?['fields'] as Map? ?? {};
  return [
    f['firstName'],
    f['middleName'],
    f['lastName'],
  ].where((v) => v != null && v.toString().isNotEmpty).join(' ');
}

String requestType(Object? value) => switch (value) {
  'SSPR' => 'SSPR Enrollment',
  'RECOVERY' => 'Account Recovery',
  'UPDATE' => 'Account Update',
  _ => display(value),
};

class StatusLabel extends StatelessWidget {
  const StatusLabel(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'APPROVED' || 'COMPLETED' => Colors.green,
      'REJECTED' => Colors.red,
      'PENDING' => Colors.amber.shade800,
      _ => const Color(0xFF6663AB),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminHeading extends StatelessWidget {
  const AdminHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 560;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: compact && action != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: copy),
                  ?action,
                ],
              ),
      );
    },
  );
}

class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.padding,
    this.margin = const EdgeInsets.only(bottom: 20),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Card(
    margin: margin,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth < 560 ? 16.0 : 22.0;
        return Padding(
          padding: padding ?? EdgeInsets.all(inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null || action != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ?action,
                  ],
                ),
                const SizedBox(height: 20),
              ],
              child,
            ],
          ),
        );
      },
    ),
  );
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
  });
  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          children: [
            Icon(
              icon,
              size: 34,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class AdminPagination extends StatelessWidget {
  const AdminPagination({
    super.key,
    required this.page,
    required this.onPrevious,
    required this.onNext,
  });
  final int page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Page ${page + 1}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class AdminTable extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onSelect,
  });
  final List<String> columns;
  final List<List<Widget>> rows;
  final List<VoidCallback?>? onSelect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainer,
              ),
              dataRowMinHeight: 54,
              dataRowMaxHeight: 76,
              columnSpacing: 28,
              columns: columns
                  .map(
                    (c) => DataColumn(
                      label: Text(
                        c.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              rows: [
                for (var index = 0; index < rows.length; index++)
                  DataRow(
                    onSelectChanged:
                        onSelect != null && onSelect![index] != null
                        ? (_) => onSelect![index]!()
                        : null,
                    cells: rows[index]
                        .map((widget) => DataCell(widget))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SummaryStrip extends StatelessWidget {
  const SummaryStrip(this.summary, {super.key});
  final Map summary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth < 520
          ? 1
          : c.maxWidth < 900
          ? 2
          : 4;
      final width = (c.maxWidth - ((columns - 1) * 12)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in [
            ('total', 'Total Requests', Icons.list_alt, Colors.deepPurple),
            ('pending', 'Pending Review', Icons.schedule, Colors.amber),
            ('approved', 'Approved', Icons.check_circle_outline, Colors.green),
            ('rejected', 'Rejected', Icons.cancel_outlined, Colors.red),
          ])
            Container(
              width: width,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.$4.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.$3, color: item.$4, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display(summary[item.$1] ?? 0),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(item.$2, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
