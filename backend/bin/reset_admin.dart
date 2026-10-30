import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';
import 'package:reaccess_hub_backend/src/modules/auth/password_hasher.dart';

Future<void> main() async {
  if (!stdin.hasTerminal) {
    stderr.writeln('Run in an interactive maintainer terminal.');
    exitCode = 1;
    return;
  }
  stdout.write('Existing administrator email: ');
  final email = (stdin.readLineSync() ?? '').trim().toLowerCase();
  stdout.write('New username: ');
  final username = (stdin.readLineSync() ?? '').trim().toLowerCase();
  String secret(String label) {
    stdout.write(label);
    final echo = stdin.echoMode;
    try {
      stdin.echoMode = false;
      return stdin.readLineSync() ?? '';
    } finally {
      stdin.echoMode = echo;
      stdout.writeln();
    }
  }

  final password = secret('New password (12+ characters): ');
  final confirm = secret('Confirm password: ');
  if (!RegExp(r'^[a-z0-9_.-]{3,64}$').hasMatch(username) ||
      password.length < 12 ||
      utf8.encode(password).length > 72 ||
      password != confirm) {
    stderr.writeln('Invalid or mismatching credentials.');
    exitCode = 1;
    return;
  }
  stdout.write(
    'Confirm the account owner was verified by the CISO Office (type RESET): ',
  );
  if (stdin.readLineSync() != 'RESET') return;
  final db = Database(ServerConfig.load());
  try {
    await db.open();
    await db.connection.runTx((s) async {
      final rows = await s.execute(
        Sql.named("""
    SELECT u.id FROM users u WHERE lower(u.email)=@email AND EXISTS(
      SELECT 1 FROM user_roles ur JOIN roles r ON r.id=ur.role_id
      WHERE ur.user_id=u.id AND r.name IN('ADMIN','SUPER_ADMIN')) FOR UPDATE
   """),
        parameters: {'email': email},
      );
      if (rows.length != 1) throw StateError('Administrator not found');
      final id = rows.single[0];
      await s.execute(
        Sql.named(
          'UPDATE users SET username=@username,password_hash=@hash,must_change_password=false,token_version=token_version+1,updated_at=now() WHERE id=@id',
        ),
        parameters: {
          'username': username,
          'hash': const PasswordHasher().hash(password),
          'id': id,
        },
      );
      await s.execute(
        Sql.named(
          "INSERT INTO audit_logs(action,resource_type,resource_id,description) VALUES('MAINTAINER_CREDENTIAL_RESET','user',@id,'Interactive trusted-maintainer credential reset')",
        ),
        parameters: {'id': id},
      );
    });
    stdout.writeln('Credentials reset; previous sessions revoked.');
  } catch (_) {
    stderr.writeln(
      'Reset failed. Check account, username uniqueness, database and migration 004.',
    );
    exitCode = 1;
  } finally {
    await db.close();
  }
}
