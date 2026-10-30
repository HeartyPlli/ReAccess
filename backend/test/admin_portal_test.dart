import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';
import 'package:reaccess_hub_backend/src/routing/app_router.dart';
import 'package:reaccess_hub_backend/src/modules/admin/portal_filters.dart';
import 'package:reaccess_hub_backend/src/modules/admin/portal_exports.dart';
import 'package:reaccess_hub_backend/src/modules/admin/request_actions.dart';
import 'package:reaccess_hub_backend/src/modules/admin/registry_management.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test(
    'request transitions include reconsideration and protect completion',
    () {
      expect(transitionAllowed('REJECTED', 'approve'), isTrue);
      expect(transitionAllowed('APPROVED', 'done'), isTrue);
      expect(transitionAllowed('COMPLETED', 'register'), isTrue);
      for (final action in ['approve', 'reject', 'done']) {
        expect(transitionAllowed('COMPLETED', action), isFalse);
      }
      expect(transitionAllowed('PENDING', 'done'), isFalse);
      expect(transitionAllowed('APPROVED', 'register'), isFalse);
    },
  );
  test('filters reject invalid dates and values', () {
    for (final query in [
      {'start': '2026-02-30'},
      {'kind': 'ADMIN'},
      {'page': '-1'},
      {'semester': 'invalid'},
      {'start': '2026-09-02', 'end': '2026-09-01'},
      {'priority': 'yes'},
    ]) {
      expect(() => PortalFilters(query), throwsA(anything));
    }
    expect(validDate('2024-02-29'), isTrue);
  });
  test('report and list share parameterized filtering, including priority', () {
    final f = PortalFilters({
      'kind': 'STUDENT',
      'type': 'SSPR',
      'search': "O'Neil",
      'priority': 'true',
      'scope': 'work',
    });
    expect(f.parameters['search'], "%O'Neil%");
    expect(f.where, contains('@search'));
    expect(f.where, isNot(contains("O'Neil")));
    expect(f.where, contains('registry_applied'));
    expect(f.parameters['priority'], 'true');
  });
  test('CSV escapes formula injection, quotes and Unicode', () {
    expect(csvCell('=1+1'), '"\'=1+1"');
    expect(csvCell('  @SUM(A1)'), startsWith('"\''));
    final csv = utf8.decode(
      auditCsv([
        {'description': 'Peña, "record"'},
      ]),
    );
    expect(csv, contains('Peña, ""record""'));
    expect(auditCsv([]).take(3).toList(), [239, 187, 191]);
  });
  test('registry CSV supports friendly headers and quoted values', () {
    final records = tabularRegistryRecords(
      'users.csv',
      Uint8List.fromList(
        utf8.encode(
          'User Type,ID Number,First Name,Last Name,Institute,School Email,Program\r\n'
          'STUDENT,123456,Ana,Santos,"Institute of Art and Sciences",santosana@gadtc.edu.ph,Bachelor of Arts in Communication\r\n',
        ),
      ),
    );
    expect(records.single['person_id'], '123456');
    expect(records.single['institute'], 'Institute of Art and Sciences');
  });
  test('registry Excel import reads the first worksheet', () {
    String cell(String reference, String value) =>
        '<c r="$reference" t="inlineStr"><is><t>$value</t></is></c>';
    final sheet =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
        '<row r="1">${cell('A1', 'person_kind')}${cell('B1', 'person_id')}${cell('C1', 'first_name')}${cell('D1', 'last_name')}${cell('E1', 'institute')}${cell('F1', 'school_email')}${cell('G1', 'program')}</row>'
        '<row r="2">${cell('A2', 'STUDENT')}${cell('B2', '123456')}${cell('C2', 'Ana')}${cell('D2', 'Santos')}${cell('E2', 'Institute of Computer Studies')}${cell('F2', 'santosana@gadtc.edu.ph')}${cell('G2', 'Bachelor of Science in Computer Science')}</row>'
        '</sheetData></worksheet>';
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'xl/worksheets/sheet1.xml',
          utf8.encode(sheet).length,
          utf8.encode(sheet),
        ),
      );
    final records = tabularRegistryRecords(
      'users.xlsx',
      ZipEncoder().encodeBytes(archive),
    );
    expect(records.single['person_id'], '123456');
    expect(
      records.single['program'],
      'Bachelor of Science in Computer Science',
    );
  });
  test('PDF exports matching rows with accented names', () async {
    final bytes = await reportPdf(
      [
        {
          'reference': 'REQ-S-2026-09-0001',
          'payload': {
            'fields': {'firstName': 'Ana', 'lastName': 'Peña'},
          },
          'person_kind': 'STUDENT',
          'request_type': 'SSPR',
          'status': 'APPROVED',
        },
      ],
      {'type': 'SSPR'},
    );
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    final directory = Directory('../build/test-artifacts')
      ..createSync(recursive: true);
    await File('${directory.path}/admin-report.pdf').writeAsBytes(bytes);
  });
  test(
    'Unicode outside built-in font fails rather than corrupting names',
    () async {
      await expectLater(
        reportPdf([
          {
            'payload': {
              'fields': {'firstName': '李'},
            },
          },
        ], {}),
        throwsStateError,
      );
    },
  );
  test('all administrative endpoints reject anonymous callers before database access', () async {
    final config = ServerConfig(
      environment: 'test',
      host: 'localhost',
      port: 8080,
      databaseHost: 'localhost',
      databasePort: 5432,
      databaseName: 'test',
      databaseUser: 'test',
      databasePassword: 'unused',
      databaseSsl: false,
      jwtSecret: 'test-secret-with-more-than-32-characters',
      accessTokenMinutes: 15,
      refreshTokenDays: 7,
      allowedOrigins: const [],
      skipDatabaseConnection: true,
    );
    final handler = buildHandler(config: config, database: Database(config));
    const id = '11111111-1111-4111-8111-111111111111';
    for (final path in [
      'requests',
      'requests/$id',
      'reports',
      'reports/pdf',
      'audit',
      'audit/csv',
      'settings',
      'registry',
    ]) {
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/v1/admin/portal/$path')),
      );
      expect(response.statusCode, 401, reason: path);
    }
    for (final path in [
      'registry',
      'registry/import',
      'registry/123456/update',
      'registry/123456/delete',
      'settings/institutions',
      'settings/institutions/$id/remove',
      'settings/institutions/$id/programs',
      'settings/programs/$id/remove',
      'settings/student-request-limit',
      'settings/periods/$id/update',
    ]) {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/v1/admin/portal/$path'),
          body: '{}',
        ),
      );
      expect(response.statusCode, 401, reason: path);
    }
    for (final action in ['decision', 'contacts', 'message', 'priority']) {
      final response = await handler(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/api/v1/admin/portal/requests/$id/$action',
          ),
          body: '{}',
        ),
      );
      expect(response.statusCode, 401, reason: action);
    }
  });
}
