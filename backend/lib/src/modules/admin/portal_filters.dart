import '../../errors/api_error.dart';

class PortalFilters {
  PortalFilters(Map<String, String> query)
    : kind = query['kind'] ?? '',
      type = query['type'] ?? '',
      status = query['status'] ?? '',
      semester = query['semester'] ?? '',
      search = query['search'] ?? '',
      start = query['start'] ?? '',
      end = query['end'] ?? '',
      scope = query['scope'] ?? '',
      page = int.tryParse(query['page'] ?? '0') ?? -1,
      role = query['role'] ?? '',
      activity = query['activity'] ?? '',
      priority = query['priority'] ?? '' {
    if (!['', 'STUDENT', 'FACULTY'].contains(kind) ||
        !['', 'SSPR', 'RECOVERY', 'UPDATE'].contains(type) ||
        ![
          '',
          'PENDING',
          'IN_REVIEW',
          'APPROVED',
          'REJECTED',
          'COMPLETED',
        ].contains(status) ||
        !['', 'work'].contains(scope) ||
        !['', 'true', 'false'].contains(priority) ||
        page < 0 ||
        page > 100000 ||
        (semester.isNotEmpty && !uuidPattern.hasMatch(semester)) ||
        search.length > 100 ||
        role.length > 50 ||
        activity.length > 80 ||
        [start, end].any((s) => s.isNotEmpty && !validDate(s)) ||
        (start.isNotEmpty && end.isNotEmpty && start.compareTo(end) > 0)) {
      throw const ApiError(statusCode: 400, message: 'Invalid filters.');
    }
  }
  final String kind,
      type,
      status,
      semester,
      search,
      start,
      end,
      scope,
      role,
      activity,
      priority;
  final int page;
  Map<String, Object?> get parameters => {
    'kind': kind,
    'type': type,
    'status': status,
    'semester': semester,
    'search': '%$search%',
    'start': start,
    'end': end,
    'priority': priority,
  };
  String get where =>
      """
 (@kind='' OR r.person_kind=@kind) AND (@type='' OR r.request_type=@type)
 AND (@priority='' OR r.priority::text=@priority)
 AND (@status='' OR r.status=@status) AND (@semester='' OR r.semester_id::text=@semester)
 AND (r.reference ILIKE @search OR r.person_id ILIKE @search
  OR concat(r.payload->'fields'->>'firstName',' ',r.payload->'fields'->>'lastName') ILIKE @search)
 AND (@start='' OR (r.created_at AT TIME ZONE 'Asia/Manila')::date >= NULLIF(@start,'')::date)
 AND (@end='' OR (r.created_at AT TIME ZONE 'Asia/Manila')::date <= NULLIF(@end,'')::date)
 ${scope == 'work' ? "AND r.request_type IN ('SSPR','UPDATE') AND (r.status='APPROVED' OR (r.request_type='SSPR' AND r.status='COMPLETED' AND NOT r.registry_applied))" : ''}
 """;
}

bool validDate(String value) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
    DateTime.tryParse(value)?.toIso8601String().substring(0, 10) == value;
final uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
void requireUuid(String id) {
  if (!uuidPattern.hasMatch(id)) {
    throw const ApiError(statusCode: 400, message: 'Invalid record ID.');
  }
}
