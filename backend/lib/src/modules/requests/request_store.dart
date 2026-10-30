import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:request_contract/request_contract.dart';

import '../../database/database.dart';
import '../../errors/api_error.dart';

String requestHash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

abstract class RequestStore {
  Future<RequestConfiguration> configuration();
  Future<int> verify(RequestData data);
  Future<String> submit(RequestData data, String nonce);
  Future<List<Map<String, Object?>>> list(String kind, String type, int page);
}

class RequestConfiguration {
  const RequestConfiguration({
    required this.institutions,
    required this.studentRequestLimit,
  });

  final Map<String, List<String>> institutions;
  final int studentRequestLimit;
}

class PostgresRequestStore implements RequestStore {
  PostgresRequestStore(this.database);
  final Database database;

  @override
  Future<RequestConfiguration> configuration() async {
    final rows = await database.connection.execute('''
      SELECT i.name AS institution,p.name AS program
      FROM institutions i
      LEFT JOIN institution_programs p
        ON p.institution_id=i.id AND p.active=true
      WHERE i.active=true
      ORDER BY CASE i.name
        WHEN 'Institute of Computer Studies' THEN 1
        WHEN 'Institute of Health Sciences' THEN 2
        WHEN 'Institute of Art and Sciences' THEN 3
        WHEN 'Institute of Teacher Education' THEN 4
        WHEN 'Institute of Business and Financial Services' THEN 5
        WHEN 'Institute of Criminal Justice Education' THEN 6
        ELSE 99
      END,i.name,p.name
    ''');
    final catalog = <String, List<String>>{};
    for (final row in rows) {
      final name = row[0] as String;
      final programs = catalog.putIfAbsent(name, () => []);
      if (row[1] != null) programs.add(row[1] as String);
    }
    final settings = await database.connection.execute(
      'SELECT student_request_limit FROM portal_settings WHERE singleton=true',
    );
    return RequestConfiguration(
      institutions: catalog,
      studentRequestLimit: settings.isEmpty ? 0 : settings.single[0] as int,
    );
  }

  Future<int> _verify(Session session, RequestData data) async {
    final params = {'kind': data.personKind.code, 'id': data['personId']};
    final records = await session.execute(
      Sql.named(
        'SELECT * FROM school_registry WHERE person_id = @id AND active = true',
      ),
      parameters: {'id': data['personId']},
    );
    if (data.requestKind == RequestKind.sspr) {
      final pending = await session.execute(
        Sql.named("""
        SELECT 1 FROM account_requests WHERE person_kind = @kind AND person_id = @id
        AND request_type = 'SSPR' AND status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'COMPLETED')
        AND registry_applied=false LIMIT 1
      """),
        parameters: params,
      );
      if (pending.isNotEmpty) {
        throw const ApiError(
          statusCode: 409,
          message: 'This ID already has a pending SSPR enrollment. Contact the CISO Office if you need help.',
        );
      }
    }
    final row = records.isEmpty ? null : records.single.toColumnMap();
    final mapping = <String, String>{
      'firstName': 'first_name',
      'middleName': 'middle_name',
      'lastName': 'last_name',
      'institute': 'institute',
      'program': 'program',
      'position': 'position',
      if (data.requestKind != RequestKind.sspr) 'schoolEmail': 'school_email',
    };
    if (row == null ||
        row['active'] != true ||
        row['person_kind'] != data.personKind.code ||
        mapping.entries.any(
          (e) =>
              normalizeName(data[e.key]) !=
              normalizeName(row[e.value]?.toString() ?? ''),
        )) {
      throw const ApiError(
        statusCode: 422,
        message: 'The information could not be verified against our records. Check your details or contact the CISO Office.',
      );
    }
    final count = data.personKind == PersonKind.student
        ? await session.execute(
            Sql.named('''
              SELECT count(*) FROM account_requests,portal_settings
              WHERE portal_settings.singleton=true
                AND portal_settings.student_request_limit>0
                AND person_kind='STUDENT' AND person_id=@id
                AND request_type=@type
                AND account_requests.created_at>=portal_settings.student_request_limit_reset_at
            '''),
            parameters: {'id': data['personId'], 'type': data.requestKind.code},
          )
        : await session.execute(
            Sql.named(
              'SELECT count(*) FROM account_requests WHERE person_id = @id',
            ),
            parameters: {'id': data['personId']},
          );
    return count.single[0] as int;
  }

  @override
  Future<int> verify(RequestData data) => _verify(database.connection, data);

  @override
  Future<String> submit(
    RequestData data,
    String nonce,
  ) => database.connection.runTx((session) async {
    // Serialize eligibility checks and inserts for the same institutional identity.
    await session.execute(
      Sql.named('SELECT pg_advisory_xact_lock(hashtextextended(@identity, 0))'),
      parameters: {'identity': data.identity},
    );
    final hash = requestHash(data.toJson());
    final existing = await session.execute(
      Sql.named(
        'SELECT reference, payload_hash FROM account_requests WHERE verification_nonce = @nonce',
      ),
      parameters: {'nonce': nonce},
    );
    if (existing.isNotEmpty) {
      if (existing.single[1] != hash) {
        throw const ApiError(
          statusCode: 409,
          message: 'This verification was already used. Start a new request.',
        );
      }
      return existing.single[0] as String;
    }
    final previousRequests = await _verify(session, data);
    final limits = await session.execute(
      'SELECT student_request_limit FROM portal_settings WHERE singleton=true',
    );
    final studentLimit = limits.isEmpty ? 0 : limits.single[0] as int;
    final requiresLetter =
        data.personKind == PersonKind.student &&
        studentLimit > 0 &&
        previousRequests >= studentLimit;
    final counter = await session.execute(
      Sql.named("""
      INSERT INTO request_monthly_counters (person_kind, request_month, last_value)
      VALUES (@kind, to_char(now() AT TIME ZONE 'Asia/Manila', 'YYYY-MM'), 1)
      ON CONFLICT (person_kind, request_month)
      DO UPDATE SET last_value = request_monthly_counters.last_value + 1
      RETURNING request_month, last_value
    """),
      parameters: {'kind': data.personKind.code},
    );
    final reference =
        'REQ-${data.personKind.prefix}-${counter.single[0]}-${counter.single[1].toString().padLeft(4, '0')}';
    final saved = await session.execute(
      Sql.named("""
      INSERT INTO account_requests
        (reference, person_kind, person_id, request_type, payload, payload_hash,
         verification_nonce,requires_letter)
      VALUES (@reference, @kind, @id, @type, CAST(@payload AS jsonb), @hash,
        @nonce,@requiresLetter) RETURNING id
    """),
      parameters: {
        'reference': reference,
        'kind': data.personKind.code,
        'id': data['personId'],
        'type': data.requestKind.code,
        'payload': jsonEncode(data.toJson()),
        'hash': hash,
        'nonce': nonce,
        'requiresLetter': requiresLetter,
      },
    );
    await session.execute(
      Sql.named("""
      INSERT INTO audit_logs (action, resource_type, resource_id)
      VALUES ('REQUEST_SUBMITTED', 'account_request', @id)
    """),
      parameters: {'id': saved.single[0]},
    );
    return reference;
  });

  @override
  Future<List<Map<String, Object?>>> list(
    String kind,
    String type,
    int page,
  ) async {
    final rows = await database.connection.execute(
      Sql.named("""
      SELECT id, reference, person_kind, request_type, payload, status, created_at::text
      FROM account_requests WHERE (@kind = '' OR person_kind = @kind)
        AND (@type = '' OR request_type = @type)
      ORDER BY created_at DESC, id DESC LIMIT 25 OFFSET @offset
    """),
      parameters: {'kind': kind, 'type': type, 'offset': page * 25},
    );
    return rows.map((r) => r.toColumnMap()).toList();
  }
}
