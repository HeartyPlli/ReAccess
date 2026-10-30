import 'package:postgres/postgres.dart';

Future<void> queueNotification(
  Session session, {
  required String event,
  required String email,
  required String phone,
  required String subject,
  required String body,
  String? attachment,
}) async {
  for (final target in [('EMAIL', email), ('SMS', phone)]) {
    if (target.$2.isEmpty) continue;
    await session.execute(
      Sql.named("""
   INSERT INTO notification_outbox(event_key,channel,recipient,subject,body,attachment_path)
   VALUES(@event,@channel,@recipient,@subject,@body,@attachment)
   ON CONFLICT(event_key,channel,recipient) DO NOTHING
  """),
      parameters: {
        'event': event,
        'channel': target.$1,
        'recipient': target.$2,
        'subject': subject,
        'body': body,
        'attachment': target.$1 == 'EMAIL' ? attachment : null,
      },
    );
  }
}

Future<void> auditEvent(
  Session session,
  String actor,
  String action,
  String id, {
  String? description,
}) async {
  await session.execute(
    Sql.named("""
  INSERT INTO audit_logs(user_id,action,resource_type,resource_id,description)
  VALUES(@actor,@action,'account_request',@id,@description)
 """),
    parameters: {
      'actor': actor,
      'action': action,
      'id': id,
      'description': description,
    },
  );
}
