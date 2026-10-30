import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';
import 'package:reaccess_hub_backend/src/modules/auth/password_hasher.dart';

Future<void> main() async {
  if (!stdin.hasTerminal) {
    stderr.writeln('Run this command in an interactive terminal.');
    exitCode = 1;
    return;
  }
  stdout.write('Admin email: ');
  final email = (stdin.readLineSync() ?? '').trim().toLowerCase();
  stdout.write('Username (3-64 letters, numbers, dot, dash or underscore): ');
  final username = (stdin.readLineSync() ?? '').trim().toLowerCase();
  stdout.write('First name: ');
  final first = (stdin.readLineSync() ?? '').trim();
  stdout.write('Last name: ');
  final last = (stdin.readLineSync() ?? '').trim();
  stdout.write('Password (12+ characters, hidden): ');
  final previousEcho = stdin.echoMode;
  String password;
  try {
    stdin.echoMode = false;
    password = stdin.readLineSync() ?? '';
  } finally {
    stdin.echoMode = previousEcho;
    stdout.writeln();
  }
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
      email.length > 254 ||
      !RegExp(r'^[a-z0-9_.-]{3,64}$').hasMatch(username) ||
      first.isEmpty ||
      first.length > 100 ||
      last.isEmpty ||
      last.length > 100 ||
      password.length < 12 ||
      utf8.encode(password).length > 72) {
    stderr.writeln(
      'Invalid details. Use a valid email, names up to 100 characters, and a password of 12+ characters and at most 72 UTF-8 bytes.',
    );
    exitCode = 1;
    return;
  }
  final config = ServerConfig.load();
  final database = Database(config);
  try {
    await database.open();
    await database.connection.runTx((session) async {
      final role = await session.execute(
        "SELECT id FROM roles WHERE name = 'SUPER_ADMIN'",
      );
      if (role.isEmpty) throw StateError('Apply migrations first');
      final rows = await session.execute(
        Sql.named('''
        INSERT INTO users (email, username, password_hash, first_name, last_name)
        VALUES (@email, @username, @hash, @first, @last) RETURNING id
      '''),
        parameters: {
          'email': email,
          'username': username,
          'hash': const PasswordHasher().hash(password),
          'first': first,
          'last': last,
        },
      );
      final id = rows.single[0];
      await session.execute(
        Sql.named(
          'INSERT INTO user_roles (user_id, role_id) VALUES (@userId, @roleId)',
        ),
        parameters: {'userId': id, 'roleId': role.single[0]},
      );
      await session.execute(
        Sql.named(
          "INSERT INTO audit_logs (user_id, action, resource_type, resource_id) VALUES (@id, 'ADMIN_CREATED', 'user', @resourceId)",
        ),
        parameters: {'id': id, 'resourceId': id.toString()},
      );
    });
    stdout.writeln('Administrator created. Sign in at /admin/login.');
  } catch (_) {
    stderr.writeln(
      'Could not create administrator. Check database configuration, migrations, and whether the email is already registered.',
    );
    exitCode = 1;
  } finally {
    await database.close();
  }
}
