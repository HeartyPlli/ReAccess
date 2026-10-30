import 'package:postgres/postgres.dart';

import '../../database/database.dart';
import '../../errors/api_error.dart';
import 'portal_filters.dart';

class PortalStore {
  PortalStore(this.database);
  final Database database;
  Future<Map<String, Object?>> requests(
    PortalFilters f, {
    bool export = false,
  }) async {
    final totals = await database.connection.execute(
      Sql.named("""
   SELECT count(*)::int AS total,
    count(*) FILTER(WHERE r.status IN ('PENDING','IN_REVIEW'))::int AS pending,
    count(*) FILTER(WHERE r.status='APPROVED')::int AS approved,
    count(*) FILTER(WHERE r.status='REJECTED')::int AS rejected,
    count(*) FILTER(WHERE r.status='COMPLETED')::int AS completed,
    count(*) FILTER(WHERE r.person_kind='STUDENT')::int AS students,
    count(*) FILTER(WHERE r.person_kind='FACULTY')::int AS faculty
   FROM account_requests r WHERE ${f.where}
  """),
      parameters: f.parameters,
    );
    if (export && (totals.single[0] as int) > 5000) {
      throw const ApiError(
        statusCode: 400,
        message:
            'Narrow the filters to 5,000 records or fewer before exporting.',
      );
    }
    final rows = await database.connection.execute(
      Sql.named("""
   SELECT r.*,r.created_at::text AS submitted_at,
    concat(p.semester,' ',p.academic_year) AS semester_label
   FROM account_requests r LEFT JOIN academic_periods p ON p.id=r.semester_id
   WHERE ${f.where} ORDER BY r.created_at DESC,r.id DESC LIMIT @limit OFFSET @offset
  """),
      parameters: {
        ...f.parameters,
        'limit': export ? 5000 : 25,
        'offset': export ? 0 : f.page * 25,
      },
    );
    return {
      'summary': totals.single.toColumnMap(),
      'rows': rows.map((r) => _safe(r.toColumnMap())).toList(),
    };
  }

  Map<String, Object?> _safe(Map<String, dynamic> row) {
    row.remove('payload_hash');
    row.remove('verification_nonce');
    return row.map(
      (k, v) => MapEntry(k, v is DateTime ? v.toIso8601String() : v),
    );
  }

  Future<Map<String, Object?>> detail(String id) async {
    requireUuid(id);
    final rows = await database.connection.execute(
      Sql.named('SELECT * FROM account_requests WHERE id=@id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) {
      throw const ApiError(statusCode: 404, message: 'Request not found.');
    }
    final row = _safe(rows.single.toColumnMap());
    final count = await database.connection.execute(
      Sql.named("""
    SELECT count(*)::int FROM account_requests WHERE person_kind=@kind AND person_id=@person
  """),
      parameters: {'kind': row['person_kind'], 'person': row['person_id']},
    );
    final history = await database.connection.execute(
      Sql.named("""
    SELECT action,description,created_at::text FROM audit_logs
    WHERE resource_type='account_request' AND resource_id=@id ORDER BY created_at
  """),
      parameters: {'id': id},
    );
    final messages = await database.connection.execute(
      Sql.named("""
    SELECT id,body,created_at::text FROM request_messages WHERE request_id=@id ORDER BY created_at
  """),
      parameters: {'id': id},
    );
    final delivery = await database.connection.execute(
      Sql.named("""
    SELECT channel,status,attempts,updated_at::text FROM notification_outbox
    WHERE event_key LIKE @prefix ORDER BY updated_at DESC LIMIT 20
  """),
      parameters: {'prefix': 'request:$id:%'},
    );
    return {
      ...row,
      'requestCount': count.single[0],
      'history': history.map((r) => r.toColumnMap()).toList(),
      'messages': messages.map((r) => r.toColumnMap()).toList(),
      'delivery': delivery.map((r) => r.toColumnMap()).toList(),
    };
  }

  Future<Map<String, Object?>> settings() async {
    final periods = await database.connection.execute(
      'SELECT id,semester,academic_year,start_date::text,end_date::text FROM academic_periods ORDER BY start_date DESC',
    );
    final current = await database.connection.execute(
      'SELECT current_period::text FROM portal_settings WHERE singleton=true',
    );
    return {
      'periods': periods.map((r) => r.toColumnMap()).toList(),
      'currentPeriod': current.isEmpty ? null : current.single[0],
    };
  }

  Future<List<Map<String, Object?>>> audit(
    PortalFilters f, {
    bool export = false,
  }) async {
    final rows = await database.connection.execute(
      Sql.named("""
   SELECT a.id,a.created_at::text,coalesce(u.username,'Public visitor') AS username,
    a.action,a.description,a.resource_id,a.actor_role,a.person_kind,
    coalesce(r.reference,a.resource_id,'') AS reference,
    concat(p.semester,' ',p.academic_year) AS semester_label
   FROM audit_logs a LEFT JOIN users u ON u.id=a.user_id
   LEFT JOIN account_requests r ON a.resource_type='account_request' AND r.id::text=a.resource_id
   LEFT JOIN academic_periods p ON p.id=a.semester_id
   WHERE (@semester='' OR a.semester_id::text=@semester)
    AND (@kind='' OR a.person_kind=@kind)
    AND (@role='' OR a.actor_role=@role)
    AND (@activity='' OR a.action=@activity)
    AND (coalesce(u.username,'') ILIKE @search OR a.action ILIKE @search OR coalesce(r.reference,'') ILIKE @search)
   ORDER BY a.created_at DESC,a.id DESC LIMIT @limit OFFSET @offset
  """),
      parameters: {
        'semester': f.semester,
        'kind': f.kind,
        'role': f.role,
        'activity': f.activity,
        'search': '%${f.search}%',
        'limit': export ? 5001 : 25,
        'offset': export ? 0 : f.page * 25,
      },
    );
    if (export && rows.length > 5000) {
      throw const ApiError(
        statusCode: 400,
        message: 'Narrow the audit filters before exporting.',
      );
    }
    return rows.map((r) => r.toColumnMap()).toList();
  }
}
