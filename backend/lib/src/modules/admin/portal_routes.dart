import 'dart:convert';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../config/server_config.dart';
import '../../database/database.dart';
import '../../errors/api_error.dart';
import '../auth/token_service.dart';
import '../support/support_access.dart';
import 'portal_filters.dart';
import 'portal_store.dart';
import 'portal_exports.dart';
import 'request_actions.dart';
import 'registry_management.dart';
import 'settings_management.dart';

Future<Map<String, dynamic>> readPortalBody(
  Request request, {
  int maxBytes = 32768,
}) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    if (bytes.length + chunk.length > maxBytes) {
      throw const ApiError(statusCode: 413, message: 'Request too large.');
    }
    bytes.addAll(chunk);
  }
  try {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is Map<String, dynamic>) return value;
  } catch (_) {}
  throw const ApiError(statusCode: 400, message: 'Invalid JSON.');
}

Response portalJson(Object data) => Response.ok(
  jsonEncode(data),
  headers: {'content-type': 'application/json', 'cache-control': 'no-store'},
);

class PortalRoutes {
  PortalRoutes(this.database, this.config);
  final Database database;
  final ServerConfig config;
  void register(Router router) {
    final store = PortalStore(database);
    final registry = RegistryManagement(database);
    final settings = SettingsManagement(database);
    final environment = ServerConfig.environmentValues();
    final actions = RequestActions(
      database,
      letterPath: (environment['LETTER_TEMPLATE_PATH'] ?? '').isNotEmpty
          ? environment['LETTER_TEMPLATE_PATH']!
          : 'templates/formal-letter.docx',
      letterUrl: environment['LETTER_TEMPLATE_URL'] ?? '',
    );
    Future<String> access(Request r, String permission) => supportAccess(
      database,
      TokenService(config),
      permission: permission,
    )(r);
    router.get('/api/v1/admin/portal/registry', (Request r) async {
      await access(r, 'manage_registry');
      return portalJson(await registry.list(r.url.queryParameters));
    });
    router.post('/api/v1/admin/portal/registry', (Request r) async {
      final actor = await access(r, 'manage_registry');
      await registry.create(actor, await readPortalBody(r));
      return portalJson({'success': true, 'message': 'User data added.'});
    });
    router.post('/api/v1/admin/portal/registry/<personId>/update', (
      Request r,
      String personId,
    ) async {
      final actor = await access(r, 'manage_registry');
      await registry.update(actor, personId, await readPortalBody(r));
      return portalJson({'success': true, 'message': 'User data updated.'});
    });
    router.post('/api/v1/admin/portal/registry/<personId>/delete', (
      Request r,
      String personId,
    ) async {
      final actor = await access(r, 'manage_registry');
      await registry.delete(actor, personId, await readPortalBody(r));
      return portalJson({
        'success': true,
        'message': 'User data permanently deleted.',
      });
    });
    router.post('/api/v1/admin/portal/registry/import', (Request r) async {
      final actor = await access(r, 'manage_registry');
      final body = await readPortalBody(r, maxBytes: 8 * 1024 * 1024);
      final filename = body['filename'];
      final encoded = body['data'];
      if (filename is! String ||
          encoded is! String ||
          filename.length > 180 ||
          encoded.length > 7 * 1024 * 1024) {
        throw const ApiError(statusCode: 400, message: 'Invalid import file.');
      }
      Uint8List bytes;
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        throw const ApiError(statusCode: 400, message: 'Invalid import file.');
      }
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        throw const ApiError(
          statusCode: 400,
          message: 'Import files must be 5 MB or smaller.',
        );
      }
      return portalJson(await registry.bulk(actor, filename, bytes));
    });
    router.post('/api/v1/admin/portal/requests/<id>/contacts', (
      Request r,
      String id,
    ) async {
      final actor = await access(r, 'manage_registry');
      await access(r, 'manage_requests');
      await actions.editContacts(id, actor, await readPortalBody(r));
      return portalJson({'success': true});
    });
    router.get('/api/v1/admin/portal/requests', (Request r) async {
      await access(r, 'manage_requests');
      return portalJson(
        await store.requests(PortalFilters(r.url.queryParameters)),
      );
    });
    router.get('/api/v1/admin/portal/requests/<id>', (
      Request r,
      String id,
    ) async {
      await access(r, 'manage_requests');
      return portalJson(await store.detail(id));
    });
    router.post('/api/v1/admin/portal/requests/<id>/decision', (
      Request r,
      String id,
    ) async {
      final actor = await access(r, 'manage_requests');
      final body = await readPortalBody(r);
      if (body['action'] == 'register' || body['action'] == 'done') {
        await access(r, 'manage_registry');
      }
      await actions.decide(id, actor, body);
      return portalJson({
        'success': true,
        'message': 'Decision saved. Any notifications are queued for delivery.',
      });
    });
    router.post('/api/v1/admin/portal/requests/<id>/message', (
      Request r,
      String id,
    ) async {
      final actor = await access(r, 'manage_requests');
      await actions.message(id, actor, await readPortalBody(r));
      return portalJson({
        'success': true,
        'message': 'Message saved and email queued.',
      });
    });
    router.post('/api/v1/admin/portal/requests/<id>/priority', (
      Request r,
      String id,
    ) async {
      final actor = await access(r, 'manage_requests');
      final body = await readPortalBody(r);
      if (body['priority'] is! bool) {
        throw const ApiError(statusCode: 400, message: 'Invalid priority.');
      }
      await actions.priority(id, actor, body['priority'] as bool);
      return portalJson({'success': true});
    });
    router.get('/api/v1/admin/portal/reports', (Request r) async {
      await access(r, 'view_reports');
      return portalJson(
        await store.requests(PortalFilters(r.url.queryParameters)),
      );
    });
    router.get('/api/v1/admin/portal/reports/pdf', (Request r) async {
      await access(r, 'view_reports');
      final data = await store.requests(
        PortalFilters(r.url.queryParameters),
        export: true,
      );
      final bytes = await reportPdf(
        (data['rows'] as List).cast<Map<String, Object?>>(),
        r.url.queryParameters,
        fontPath: environment['REPORT_FONT_PATH'] ?? '',
      );
      return Response.ok(
        bytes,
        headers: {
          'content-type': 'application/pdf',
          'cache-control': 'no-store',
          'content-disposition': 'inline; filename="reaccess-report.pdf"',
        },
      );
    });
    router.get('/api/v1/admin/portal/audit', (Request r) async {
      await access(r, 'view_audit');
      return portalJson({
        'rows': await store.audit(PortalFilters(r.url.queryParameters)),
      });
    });
    router.get('/api/v1/admin/portal/audit/csv', (Request r) async {
      await access(r, 'view_audit');
      return Response.ok(
        auditCsv(
          await store.audit(PortalFilters(r.url.queryParameters), export: true),
        ),
        headers: {
          'content-type': 'text/csv; charset=utf-8',
          'cache-control': 'no-store',
          'content-disposition': 'attachment; filename="reaccess-audit.csv"',
        },
      );
    });
    router.get('/api/v1/admin/portal/settings', (Request r) async {
      await access(r, '');
      return portalJson({
        ...await store.settings(),
        ...await settings.configuration(),
      });
    });
    router.post('/api/v1/admin/portal/settings/institutions', (
      Request r,
    ) async {
      final actor = await access(r, 'manage_settings');
      await settings.addInstitution(actor, await readPortalBody(r));
      return portalJson({'success': true, 'message': 'Institution saved.'});
    });
    router.post('/api/v1/admin/portal/settings/institutions/<id>/remove', (
      Request r,
      String id,
    ) async {
      final actor = await access(r, 'manage_settings');
      await settings.deleteInstitution(actor, id, await readPortalBody(r));
      return portalJson({'success': true, 'message': 'Institution removed.'});
    });
    router.post('/api/v1/admin/portal/settings/institutions/<id>/programs', (
      Request r,
      String id,
    ) async {
      final actor = await access(r, 'manage_settings');
      await settings.addProgram(actor, id, await readPortalBody(r));
      return portalJson({'success': true, 'message': 'Program saved.'});
    });
    router.post('/api/v1/admin/portal/settings/programs/<id>/remove', (
      Request r,
      String id,
    ) async {
      final actor = await access(r, 'manage_settings');
      await settings.deleteProgram(actor, id, await readPortalBody(r));
      return portalJson({'success': true, 'message': 'Program removed.'});
    });
    router.post('/api/v1/admin/portal/settings/student-request-limit', (
      Request r,
    ) async {
      final actor = await access(r, 'manage_settings');
      await settings.setStudentRequestLimit(actor, await readPortalBody(r));
      return portalJson({
        'success': true,
        'message': 'Student request limit saved.',
      });
    });
    router.post('/api/v1/admin/portal/settings/periods/<id>/update', (
      Request r,
      String id,
    ) async {
      final actor = await access(r, 'manage_settings');
      await settings.updateAcademicPeriod(actor, id, await readPortalBody(r));
      return portalJson({
        'success': true,
        'message': 'Academic period updated.',
      });
    });
    router.post('/api/v1/admin/portal/settings', (Request r) async {
      final actor = await access(r, 'manage_settings');
      final b = await readPortalBody(r);
      final semester = b['semester'],
          year = b['academicYear'],
          start = b['start'],
          end = b['end'];
      if (!['1st Semester', '2nd Semester', 'Summer'].contains(semester) ||
          year is! String ||
          !RegExp(r'^\d{4}-\d{4}$').hasMatch(year) ||
          start is! String ||
          end is! String ||
          !validDate(start) ||
          !validDate(end) ||
          start.compareTo(end) > 0 ||
          int.parse(year.substring(5)) != int.parse(year.substring(0, 4)) + 1) {
        throw const ApiError(
          statusCode: 400,
          message: 'Enter a valid semester, academic year and date range.',
        );
      }
      await database.connection.runTx((s) async {
        await s.execute('SELECT singleton FROM portal_settings FOR UPDATE');
        final conflicts = await s.execute(
          Sql.named("""
     SELECT id FROM academic_periods WHERE (semester=@semester AND academic_year=@year)
      OR daterange(start_date,end_date,'[]') && daterange(@start::date,@end::date,'[]')
    """),
          parameters: {
            'semester': semester,
            'year': year,
            'start': start,
            'end': end,
          },
        );
        if (conflicts.isNotEmpty) {
          throw const ApiError(
            statusCode: 409,
            message: 'This semester already exists or overlaps another period. Existing periods are retained for audit history.',
          );
        }
        final row = await s.execute(
          Sql.named("""
     INSERT INTO academic_periods(semester,academic_year,start_date,end_date)
     VALUES(@semester,@year,@start::date,@end::date) RETURNING id
    """),
          parameters: {
            'semester': semester,
            'year': year,
            'start': start,
            'end': end,
          },
        );
        await s.execute(
          Sql.named('UPDATE portal_settings SET current_period=@id'),
          parameters: {'id': row.single[0]},
        );
        await s.execute(
          Sql.named(
            "INSERT INTO audit_logs(user_id,action,resource_type,resource_id) VALUES(@actor,'SEMESTER_CREATED','academic_period',@id)",
          ),
          parameters: {'actor': actor, 'id': row.single[0]},
        );
      });
      return portalJson({'success': true});
    });
  }
}
