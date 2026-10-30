import 'dart:io';
import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:request_contract/request_contract.dart';

import '../../database/database.dart';
import '../../errors/api_error.dart';
import 'notification_queue.dart';
import 'portal_filters.dart';

const requestLabels = {
  'SSPR': 'SSPR Enrollment',
  'RECOVERY': 'Account Recovery',
  'UPDATE': 'Account Update',
};
bool transitionAllowed(String status, String action) => switch (action) {
  'approve' => ['PENDING', 'IN_REVIEW', 'REJECTED'].contains(status),
  'reject' => ['PENDING', 'IN_REVIEW', 'APPROVED'].contains(status),
  'done' => status == 'APPROVED',
  'register' => status == 'COMPLETED',
  _ => false,
};

class RequestActions {
  RequestActions(this.database, {this.letterPath = '', this.letterUrl = ''});
  final Database database;
  final String letterPath, letterUrl;
  Future<void> editContacts(
    String id,
    String actor,
    Map<String, dynamic> body,
  ) async {
    requireUuid(id);
    if (body['gmail'] is! String || body['contact'] is! String) {
      throw const ApiError(
        statusCode: 400,
        message: 'Enter valid contact details.',
      );
    }
    await database.connection.runTx((s) async {
      final rows = await s.execute(
        Sql.named('SELECT * FROM account_requests WHERE id=@id FOR UPDATE'),
        parameters: {'id': id},
      );
      if (rows.isEmpty) {
        throw const ApiError(statusCode: 404, message: 'Request not found.');
      }
      final row = rows.single.toColumnMap();
      if (row['status'] != 'APPROVED' ||
          !['SSPR', 'UPDATE'].contains(row['request_type'])) {
        throw const ApiError(
          statusCode: 409,
          message: 'Only approved SSPR and update work can be edited.',
        );
      }
      final original = RequestData.fromJson(
        Map<String, dynamic>.from(
          (row['work_payload'] ?? row['payload']) as Map,
        ),
      );
      final update = original.requestKind == RequestKind.update;
      final edited = RequestData.fromJson({
        ...original.toJson(),
        'fields': {
          ...original.fields,
          (update ? 'alternativeGmail' : 'gmail'): body['gmail'],
          (update ? 'newContact' : 'contact'): body['contact'],
        },
      });
      final errors = edited.validate();
      if (errors.isNotEmpty) {
        throw ApiError(statusCode: 400, message: errors.values.first);
      }
      await s.execute(
        Sql.named(
          'UPDATE account_requests SET work_payload=@payload::jsonb,updated_at=now() WHERE id=@id',
        ),
        parameters: {'id': id, 'payload': jsonEncode(edited.toJson())},
      );
      await auditEvent(
        s,
        actor,
        'WORK_CONTACTS_EDITED',
        id,
        description:
            'Approved contact details corrected; original submission retained.',
      );
    });
  }

  Future<void> decide(
    String id,
    String actor,
    Map<String, dynamic> body,
  ) async {
    requireUuid(id);
    final action = body['action'];
    final notes = body['notes'] ?? '';
    final letter = body['requiresLetter'] ?? false;
    if (action is! String ||
        !['approve', 'reject', 'done', 'register'].contains(action) ||
        notes is! String ||
        notes.length > 2000 ||
        letter is! bool) {
      throw const ApiError(statusCode: 400, message: 'Invalid decision.');
    }
    if (action == 'approve' &&
        letter &&
        (letterPath.isEmpty ||
            !File(letterPath).existsSync() ||
            !letterPath.toLowerCase().endsWith('.docx') ||
            (letterUrl.isNotEmpty &&
                !letterUrl.startsWith('https://') &&
                !letterUrl.startsWith('/')))) {
      throw const ApiError(
        statusCode: 409,
        message: 'Configure the approved Word letter template before requiring a letter.',
      );
    }
    await database.connection.runTx((s) async {
      final rows = await s.execute(
        Sql.named('SELECT * FROM account_requests WHERE id=@id FOR UPDATE'),
        parameters: {'id': id},
      );
      if (rows.isEmpty) {
        throw const ApiError(statusCode: 404, message: 'Request not found.');
      }
      final row = rows.single.toColumnMap();
      final current = row['status'] as String;
      if ((action == 'approve' && current == 'APPROVED') ||
          (action == 'reject' && current == 'REJECTED') ||
          (action == 'done' && current == 'COMPLETED') ||
          (action == 'register' && row['registry_applied'] == true)) {
        return;
      }
      if (!transitionAllowed(current, action) ||
          (action == 'register' && row['request_type'] != 'SSPR')) {
        throw const ApiError(
          statusCode: 409,
          message: 'This request changed. Refresh before taking action.',
        );
      }
      final data = RequestData.fromJson(
        Map<String, dynamic>.from(
          (row['work_payload'] ?? row['payload']) as Map,
        ),
      );
      await s.execute(
        Sql.named('SELECT pg_advisory_xact_lock(hashtextextended(@key,0))'),
        parameters: {'key': data.identity},
      );
      final registry = await s.execute(
        Sql.named(
          'SELECT * FROM school_registry WHERE person_id=@id FOR UPDATE',
        ),
        parameters: {'id': data['personId']},
      );
      String email = data['gmail'], phone = data['contact'];
      if (registry.isNotEmpty) {
        final old = registry.single.toColumnMap();
        email = (old['gmail'] as String?) ?? '';
        phone = (old['contact'] as String?) ?? '';
        if (email.isEmpty) email = data['gmail'];
        if (phone.isEmpty) phone = data['contact'];
      }
      if (action == 'done' && data.requestKind == RequestKind.update) {
        if (registry.isEmpty) {
          throw const ApiError(
            statusCode: 409,
            message: 'Registered account not found.',
          );
        }
        await s.execute(
          Sql.named("""
     UPDATE school_registry SET gmail=CASE WHEN @email='' THEN gmail ELSE @email END,
     contact=CASE WHEN @phone='' THEN contact ELSE @phone END,updated_at=now()
     WHERE person_kind=@kind AND person_id=@id
    """),
          parameters: {
            'email': data['alternativeGmail'],
            'phone': data['newContact'],
            'kind': data.personKind.code,
            'id': data['personId'],
          },
        );
        // Completion goes to the approved contact only after staff completes the change.
        if (data['alternativeGmail'].isNotEmpty) {
          email = data['alternativeGmail'];
        }
        if (data['newContact'].isNotEmpty) phone = data['newContact'];
      }
      if (action == 'register') {
        if (registry.isEmpty ||
            registry.single.toColumnMap()['person_kind'] !=
                data.personKind.code) {
          throw const ApiError(
            statusCode: 409,
            message: 'Registered user data was not found. Add the user before completing SSPR enrollment.',
          );
        }
        email = data['gmail'];
        phone = data['contact'];
        await s.execute(
          Sql.named("""
     UPDATE school_registry SET
       contact=CASE WHEN @phone='' THEN contact ELSE @phone END,
       gmail=CASE WHEN @email='' THEN gmail ELSE @email END,
       updated_at=now()
     WHERE person_id=@id
    """),
          parameters: {'id': data['personId'], 'phone': phone, 'email': email},
        );
      }
      final status = switch (action) {
        'approve' => 'APPROVED',
        'reject' => 'REJECTED',
        _ => 'COMPLETED',
      };
      await s.execute(
        Sql.named("""
    UPDATE account_requests SET status=@status,reviewed_by=@actor,updated_at=now(),
     reviewed_at=now(),reviewer_notes=CASE WHEN @review THEN @notes ELSE reviewer_notes END,
     requires_letter=CASE WHEN @review THEN @letter ELSE requires_letter END,
     completed_at=CASE WHEN @done THEN now() ELSE completed_at END,
     registry_applied=registry_applied OR @registered WHERE id=@id
   """),
        parameters: {
          'status': status,
          'actor': actor,
          'id': id,
          'notes': notes,
          'letter': letter,
          'review': ['approve', 'reject'].contains(action),
          'done': ['done', 'register'].contains(action),
          'registered': action == 'register',
        },
      );
      await auditEvent(
        s,
        actor,
        'REQUEST_${action.toUpperCase()}',
        id,
        description: notes.isEmpty ? null : notes,
      );
      if (action == 'approve' ||
          action == 'reject' ||
          action == 'register' ||
          (action == 'done' && data.requestKind != RequestKind.sspr)) {
        final event = 'request:$id:$action:${row['updated_at']}';
        final label = requestLabels[row['request_type']]!;
        final outcome = action == 'approve'
            ? 'approved'
            : action == 'reject'
            ? 'not approved'
            : 'completed';
        final message =
            'Your $label request ${row['reference']} has been $outcome by the CISO Office.'
            '${action == 'approve' && letter ? ' Please complete the attached formal letter.${letterUrl.isNotEmpty ? ' Template: $letterUrl' : ''}' : ''}'
            ' Contact the CISO Office for assistance. Never share passwords or verification codes.';
        await queueNotification(
          s,
          event: event,
          email: email,
          phone: phone,
          subject: 'ReAccess Hub - $label $outcome',
          body: message,
          attachment: action == 'approve' && letter ? letterPath : null,
        );
      }
    });
  }

  Future<void> message(
    String id,
    String actor,
    Map<String, dynamic> body,
  ) async {
    requireUuid(id);
    final text = body['body'];
    if (text is! String || text.trim().isEmpty || text.length > 4000) {
      throw const ApiError(
        statusCode: 400,
        message: 'Enter a message of up to 4,000 characters.',
      );
    }
    await database.connection.runTx((s) async {
      final rows = await s.execute(
        Sql.named("""
    SELECT r.payload, r.reference, g.gmail FROM account_requests r
    LEFT JOIN school_registry g ON g.person_kind=r.person_kind AND g.person_id=r.person_id
    WHERE r.id=@id FOR UPDATE OF r
   """),
        parameters: {'id': id},
      );
      if (rows.isEmpty) {
        throw const ApiError(statusCode: 404, message: 'Request not found.');
      }
      final row = rows.single.toColumnMap();
      final data = RequestData.fromJson(
        Map<String, dynamic>.from(row['payload'] as Map),
      );
      final email = (row['gmail'] as String?)?.isNotEmpty == true
          ? row['gmail'] as String
          : data['gmail'];
      if (email.isEmpty) {
        throw const ApiError(
          statusCode: 409,
          message: 'No registered notification email is available. Update the trusted registry contact first.',
        );
      }
      final saved = await s.execute(
        Sql.named(
          'INSERT INTO request_messages(request_id,sender_id,body) VALUES(@id,@actor,@body) RETURNING id',
        ),
        parameters: {'id': id, 'actor': actor, 'body': text.trim()},
      );
      await queueNotification(
        s,
        event: 'request:$id:message:${saved.single[0]}',
        email: email,
        phone: '',
        subject: 'CISO Office message - ${row['reference']}',
        body: text.trim(),
      );
      await auditEvent(s, actor, 'MESSAGE_SENT', id);
    });
  }

  Future<void> priority(String id, String actor, bool value) async {
    requireUuid(id);
    await database.connection.runTx((s) async {
      final r = await s.execute(
        Sql.named(
          'UPDATE account_requests SET priority=@value WHERE id=@id RETURNING id',
        ),
        parameters: {'id': id, 'value': value},
      );
      if (r.isEmpty) {
        throw const ApiError(statusCode: 404, message: 'Request not found.');
      }
      await auditEvent(
        s,
        actor,
        'PRIORITY_CHANGED',
        id,
        description: value ? 'Priority enabled' : 'Priority disabled',
      );
    });
  }
}
