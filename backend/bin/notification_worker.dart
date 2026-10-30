import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:postgres/postgres.dart';
import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';

Future<void> main(List<String> args) async {
  final env = ServerConfig.environmentValues();
  final db = Database(ServerConfig.load());
  final emailReady =
      (env['SMTP_HOST'] ?? '').isNotEmpty &&
      (env['SMTP_FROM'] ?? '').isNotEmpty;
  final accountSid = env['TWILIO_ACCOUNT_SID'] ?? '';
  final smsReady =
      RegExp(r'^AC[0-9a-fA-F]{32}$').hasMatch(accountSid) &&
      (env['TWILIO_AUTH_TOKEN'] ?? '').isNotEmpty &&
      ((env['TWILIO_FROM_NUMBER'] ?? '').isNotEmpty ||
          (env['TWILIO_MESSAGING_SERVICE_SID'] ?? '').isNotEmpty);
  if (!emailReady && !smsReady) {
    stdout.writeln(
      'No notification delivery channels configured. Queued messages remain pending.',
    );
    return;
  }
  await db.open();
  try {
    do {
      final rows = await db.connection.execute(
        Sql.named("""
    UPDATE notification_outbox SET status='SENDING',attempts=attempts+1,updated_at=now()
    WHERE id=(SELECT id FROM notification_outbox
      WHERE attempts<5 AND available_at<=now()
       AND (status IN ('PENDING','FAILED') OR (status='SENDING' AND updated_at<now()-interval '15 minutes'))
       AND ((channel='EMAIL' AND @email) OR (channel='SMS' AND @sms))
      ORDER BY available_at FOR UPDATE SKIP LOCKED LIMIT 1)
    RETURNING *
   """),
        parameters: {'email': emailReady, 'sms': smsReady},
      );
      if (rows.isEmpty) {
        if (args.contains('--once')) break;
        await Future<void>.delayed(const Duration(seconds: 10));
        continue;
      }
      final r = rows.single.toColumnMap();
      try {
        if (r['channel'] == 'EMAIL') {
          final smtp = SmtpServer(
            env['SMTP_HOST']!,
            port: int.tryParse(env['SMTP_PORT'] ?? '465') ?? 465,
            username: env['SMTP_USERNAME'],
            password: env['SMTP_PASSWORD'],
            ssl: (env['SMTP_PORT'] ?? '465') == '465',
            allowInsecure: false,
          );
          final message = Message()
            ..from = Address(env['SMTP_FROM']!, 'CISO Office')
            ..recipients.add(r['recipient'])
            ..subject = r['subject'] as String
            ..text = r['body'] as String;
          final attachment = r['attachment_path'];
          if (attachment is String && attachment.isNotEmpty) {
            final file = File(attachment);
            if (!await file.exists() || await file.length() > 5 * 1024 * 1024) {
              throw StateError('Attachment unavailable');
            }
            message.attachments.add(
              FileAttachment(file)..fileName = 'formal-letter-template.docx',
            );
          }
          await send(message, smtp, timeout: const Duration(seconds: 30));
        } else {
          var recipient = (r['recipient'] as String).replaceAll(
            RegExp(r'[\s()-]'),
            '',
          );
          if (RegExp(r'^09\d{9}$').hasMatch(recipient)) {
            recipient = '+63${recipient.substring(1)}';
          }
          if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(recipient)) {
            throw StateError('Invalid SMS recipient');
          }
          final service = env['TWILIO_MESSAGING_SERVICE_SID'] ?? '';
          final response = await http
              .post(
                Uri.https(
                  'api.twilio.com',
                  '/2010-04-01/Accounts/$accountSid/Messages.json',
                ),
                headers: {
                  'authorization':
                      'Basic ${base64Encode(utf8.encode('$accountSid:${env['TWILIO_AUTH_TOKEN']}'))}',
                },
                body: {
                  'To': recipient,
                  'Body': r['body'] as String,
                  if (service.isNotEmpty)
                    'MessagingServiceSid': service
                  else
                    'From': env['TWILIO_FROM_NUMBER']!,
                },
              )
              .timeout(const Duration(seconds: 30));
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw StateError('Gateway rejected message');
          }
          final body = jsonDecode(response.body);
          if (body is! Map ||
              body['sid'] is! String ||
              ![
                'accepted',
                'queued',
                'sending',
                'sent',
              ].contains(body['status'])) {
            throw StateError('No acceptance receipt');
          }
        }
        await db.connection.execute(
          Sql.named(
            "UPDATE notification_outbox SET status='SENT',last_error=NULL,updated_at=now() WHERE id=@id",
          ),
          parameters: {'id': r['id']},
        );
      } catch (_) {
        await db.connection.execute(
          Sql.named("""
     UPDATE notification_outbox SET status='FAILED',last_error='Provider or attachment unavailable',
      available_at=now()+interval '5 minutes',updated_at=now() WHERE id=@id
    """),
          parameters: {'id': r['id']},
        );
      }
    } while (!args.contains('--once'));
  } finally {
    await db.close();
  }
}
