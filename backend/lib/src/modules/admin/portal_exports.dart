import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

String csvCell(Object? value) {
  var text = value?.toString() ?? '';
  // Prevent spreadsheet formula execution, including leading whitespace controls.
  if (RegExp(r'^[\s]*[=+@-]').hasMatch(text) ||
      text.startsWith('\t') ||
      text.startsWith('\r')) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}

Uint8List auditCsv(List<Map<String, Object?>> rows) {
  const columns = [
    'created_at',
    'username',
    'actor_role',
    'person_kind',
    'semester_label',
    'action',
    'reference',
    'description',
  ];
  return Uint8List.fromList(
    utf8.encode(
      '\uFEFF${columns.join(',')}\r\n${rows.map((r) => columns.map((c) => csvCell(r[c])).join(',')).join('\r\n')}',
    ),
  );
}

Future<Uint8List> reportPdf(
  List<Map<String, Object?>> rows,
  Map<String, String> filters, {
  String fontPath = '',
}) async {
  final font = fontPath.isEmpty
      ? pw.Font.helvetica()
      : pw.Font.ttf(ByteData.sublistView(await File(fontPath).readAsBytes()));
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  String printable(Object? value) {
    final text = value?.toString() ?? '';
    if (fontPath.isEmpty && text.runes.any((c) => c > 255)) {
      throw StateError('Configure REPORT_FONT_PATH for Unicode reports.');
    }
    return text;
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 300,
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ReAccess Hub | CISO Office',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Tangub City Global College - Account Service Report'),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${c.pageNumber} of ${c.pagesCount}'),
      ),
      build: (_) => [
        pw.Text(
          'Filters: ${printable(filters.entries.where((e) => e.value.isNotEmpty && e.key != 'page').map((e) => '${e.key}: ${e.value}').join(' | '))}',
        ),
        pw.Text('Matching requests: ${rows.length}'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.all(6),
          headers: [
            'Reference',
            'Name',
            'User type',
            'Request type',
            'Semester',
            'Submitted',
            'Status',
          ],
          data: rows.map((r) {
            final fields = ((r['payload'] as Map?)?['fields'] as Map?) ?? {};
            return [
              r['reference'],
              '${fields['firstName'] ?? ''} ${fields['lastName'] ?? ''}',
              r['person_kind'],
              r['request_type'],
              r['semester_label'],
              r['submitted_at'],
              r['status'],
            ].map(printable).toList();
          }).toList(),
        ),
      ],
    ),
  );
  return doc.save();
}
