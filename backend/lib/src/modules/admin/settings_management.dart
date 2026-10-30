import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../database/database.dart';
import '../../errors/api_error.dart';
import '../auth/password_hasher.dart';

class SettingsManagement {
  SettingsManagement(this.database);

  final Database database;
  final PasswordHasher _passwordHasher = const PasswordHasher();

  Future<Map<String, Object?>> configuration() async {
    final rows = await database.connection.execute('''
      SELECT i.id::text AS institution_id,i.name AS institution_name,
        p.id::text AS program_id,p.name AS program_name
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
    final settings = await database.connection.execute('''
      SELECT student_request_limit,student_request_limit_reset_at::text
      FROM portal_settings WHERE singleton=true
    ''');
    final institutions = <String, Map<String, Object?>>{};
    for (final row in rows) {
      final values = row.toColumnMap();
      final id = values['institution_id'] as String;
      final institution = institutions.putIfAbsent(
        id,
        () => {
          'id': id,
          'name': values['institution_name'],
          'programs': <Map<String, Object?>>[],
        },
      );
      if (values['program_id'] != null) {
        (institution['programs'] as List<Map<String, Object?>>).add({
          'id': values['program_id'],
          'name': values['program_name'],
        });
      }
    }
    return {
      'institutions': institutions.values.toList(),
      'studentRequestLimit': settings.isEmpty ? 0 : settings.single[0],
      'studentRequestLimitResetAt': settings.isEmpty
          ? null
          : settings.single[1],
    };
  }

  Future<Map<String, Object?>> publicConfiguration() async {
    final data = await configuration();
    return {
      'institutions': data['institutions'],
      'studentRequestLimit': data['studentRequestLimit'],
    };
  }

  Future<void> addInstitution(String actor, Map<String, dynamic> body) async {
    final name = _name(body['name'], 150, 'institution');
    await database.connection.runTx((session) async {
      await _confirm(session, actor, body);
      final existing = await session.execute(
        Sql.named('SELECT id FROM institutions WHERE lower(name)=lower(@name)'),
        parameters: {'name': name},
      );
      String id;
      if (existing.isEmpty) {
        final inserted = await session.execute(
          Sql.named(
            'INSERT INTO institutions(name) VALUES(@name) RETURNING id',
          ),
          parameters: {'name': name},
        );
        id = inserted.single[0].toString();
      } else {
        id = existing.single[0].toString();
        await session.execute(
          Sql.named(
            'UPDATE institutions SET name=@name,active=true,updated_at=now() WHERE id=@id',
          ),
          parameters: {'name': name, 'id': id},
        );
      }
      await _audit(
        session,
        actor,
        'INSTITUTION_SAVED',
        'institution',
        id,
        name,
      );
    });
  }

  Future<void> deleteInstitution(
    String actor,
    String id,
    Map<String, dynamic> body,
  ) async {
    _uuid(id);
    await database.connection.runTx((session) async {
      await _confirm(session, actor, body);
      final rows = await session.execute(
        Sql.named(
          'UPDATE institutions SET active=false,updated_at=now() WHERE id=@id AND active=true RETURNING name',
        ),
        parameters: {'id': id},
      );
      if (rows.isEmpty) throw _notFound('Institution');
      await session.execute(
        Sql.named(
          'UPDATE institution_programs SET active=false,updated_at=now() WHERE institution_id=@id',
        ),
        parameters: {'id': id},
      );
      await _audit(
        session,
        actor,
        'INSTITUTION_REMOVED',
        'institution',
        id,
        rows.single[0].toString(),
      );
    });
  }

  Future<void> addProgram(
    String actor,
    String institutionId,
    Map<String, dynamic> body,
  ) async {
    _uuid(institutionId);
    final name = _name(body['name'], 200, 'program');
    await database.connection.runTx((session) async {
      await _confirm(session, actor, body);
      final institution = await session.execute(
        Sql.named(
          'SELECT name FROM institutions WHERE id=@id AND active=true FOR UPDATE',
        ),
        parameters: {'id': institutionId},
      );
      if (institution.isEmpty) throw _notFound('Institution');
      final existing = await session.execute(
        Sql.named('''
          SELECT id FROM institution_programs
          WHERE institution_id=@institution AND lower(name)=lower(@name)
        '''),
        parameters: {'institution': institutionId, 'name': name},
      );
      String id;
      if (existing.isEmpty) {
        final inserted = await session.execute(
          Sql.named('''
            INSERT INTO institution_programs(institution_id,name)
            VALUES(@institution,@name) RETURNING id
          '''),
          parameters: {'institution': institutionId, 'name': name},
        );
        id = inserted.single[0].toString();
      } else {
        id = existing.single[0].toString();
        await session.execute(
          Sql.named('''
            UPDATE institution_programs
            SET name=@name,active=true,updated_at=now() WHERE id=@id
          '''),
          parameters: {'name': name, 'id': id},
        );
      }
      await _audit(
        session,
        actor,
        'PROGRAM_SAVED',
        'institution_program',
        id,
        '${institution.single[0]}: $name',
      );
    });
  }

  Future<void> deleteProgram(
    String actor,
    String id,
    Map<String, dynamic> body,
  ) async {
    _uuid(id);
    await database.connection.runTx((session) async {
      await _confirm(session, actor, body);
      final rows = await session.execute(
        Sql.named('''
          UPDATE institution_programs SET active=false,updated_at=now()
          WHERE id=@id AND active=true RETURNING name
        '''),
        parameters: {'id': id},
      );
      if (rows.isEmpty) throw _notFound('Program');
      await _audit(
        session,
        actor,
        'PROGRAM_REMOVED',
        'institution_program',
        id,
        rows.single[0].toString(),
      );
    });
  }

  Future<void> setStudentRequestLimit(
    String actor,
    Map<String, dynamic> body,
  ) async {
    final limit = body['limit'];
    if (limit is! int || limit < 0 || limit > 100) {
      throw const ApiError(
        statusCode: 400,
        message: 'Enter a student request limit from 0 to 100.',
      );
    }
    await database.connection.runTx((session) async {
      await session.execute('SELECT singleton FROM portal_settings FOR UPDATE');
      await session.execute(
        Sql.named('''
          UPDATE portal_settings SET student_request_limit=@limit,
            student_request_limit_reset_at=CASE
              WHEN @limit=0 THEN now()
              ELSE student_request_limit_reset_at
            END
          WHERE singleton=true
        '''),
        parameters: {'limit': limit},
      );
      await _audit(
        session,
        actor,
        'STUDENT_REQUEST_LIMIT_CHANGED',
        'portal_settings',
        'student_request_limit',
        'Student request limit set to $limit.',
      );
    });
  }

  Future<void> updateAcademicPeriod(
    String actor,
    String id,
    Map<String, dynamic> body,
  ) async {
    _uuid(id);
    final semester = body['semester'];
    final year = body['academicYear'];
    final start = body['start'];
    final end = body['end'];
    if (!['1st Semester', '2nd Semester', 'Summer'].contains(semester) ||
        year is! String ||
        !RegExp(r'^\d{4}-\d{4}$').hasMatch(year) ||
        start is! String ||
        end is! String ||
        !_validDate(start) ||
        !_validDate(end) ||
        start.compareTo(end) > 0 ||
        int.parse(year.substring(5)) != int.parse(year.substring(0, 4)) + 1) {
      throw const ApiError(
        statusCode: 400,
        message: 'Enter a valid semester, academic year and date range.',
      );
    }
    await database.connection.runTx((session) async {
      final existing = await session.execute(
        Sql.named('SELECT id FROM academic_periods WHERE id=@id FOR UPDATE'),
        parameters: {'id': id},
      );
      if (existing.isEmpty) throw _notFound('Academic period');
      final conflicts = await session.execute(
        Sql.named('''
          SELECT id FROM academic_periods
          WHERE id<>@id AND (
            (semester=@semester AND academic_year=@year) OR
            daterange(start_date,end_date,'[]') &&
              daterange(@start::date,@end::date,'[]')
          )
        '''),
        parameters: {
          'id': id,
          'semester': semester,
          'year': year,
          'start': start,
          'end': end,
        },
      );
      if (conflicts.isNotEmpty) {
        throw const ApiError(
          statusCode: 409,
          message: 'The updated dates overlap another academic period.',
        );
      }
      await session.execute(
        Sql.named('''
          UPDATE academic_periods SET semester=@semester,academic_year=@year,
            start_date=@start::date,end_date=@end::date WHERE id=@id
        '''),
        parameters: {
          'id': id,
          'semester': semester,
          'year': year,
          'start': start,
          'end': end,
        },
      );
      await _audit(
        session,
        actor,
        'SEMESTER_UPDATED',
        'academic_period',
        id,
        '$semester, AY $year: $start to $end',
      );
    });
  }

  Future<void> _confirm(
    Session session,
    String actor,
    Map<String, dynamic> body,
  ) async {
    final username = body['username'];
    final password = body['password'];
    if (username is! String ||
        password is! String ||
        username.length > 254 ||
        password.isEmpty ||
        utf8.encode(password).length > 72) {
      throw const ApiError(
        statusCode: 403,
        message: 'Enter your current username and password to confirm.',
      );
    }
    final rows = await session.execute(
      Sql.named('''
        SELECT username,password_hash,status FROM users WHERE id=@id FOR UPDATE
      '''),
      parameters: {'id': actor},
    );
    if (rows.isEmpty ||
        rows.single[2] != 'ACTIVE' ||
        rows.single[0].toString().toLowerCase() !=
            username.trim().toLowerCase() ||
        !_passwordHasher.verify(
          password: password,
          passwordHash: rows.single[1] as String,
        )) {
      throw const ApiError(
        statusCode: 403,
        message: 'The confirmation username or password is incorrect.',
      );
    }
  }

  Future<void> _audit(
    Session session,
    String actor,
    String action,
    String resourceType,
    String resourceId,
    String description,
  ) => session.execute(
    Sql.named('''
      INSERT INTO audit_logs(user_id,action,resource_type,resource_id,description)
      VALUES(@actor,@action,@type,@id,@description)
    '''),
    parameters: {
      'actor': actor,
      'action': action,
      'type': resourceType,
      'id': resourceId,
      'description': description,
    },
  );

  String _name(Object? value, int max, String label) {
    if (value is! String) {
      throw ApiError(statusCode: 400, message: 'Enter a valid $label name.');
    }
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2 || name.length > max) {
      throw ApiError(
        statusCode: 400,
        message: 'Enter a $label name from 2 to $max characters.',
      );
    }
    return name;
  }

  bool _validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().startsWith(value);
  }

  void _uuid(String value) {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(value)) {
      throw const ApiError(statusCode: 400, message: 'Invalid item.');
    }
  }

  ApiError _notFound(String label) =>
      ApiError(statusCode: 404, message: '$label was not found.');
}
