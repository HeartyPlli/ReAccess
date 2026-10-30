import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';
import 'package:reaccess_hub_backend/src/modules/auth/password_hasher.dart';

// Explicit local bootstrap only. No account is created on API startup.
Future<void> main(List<String> args) async {
  final env = ServerConfig.environmentValues();
  if ((env['APP_ENV'] ?? 'development') != 'development') {
    throw StateError('Development only.');
  }
  final file = File('.local-admin.json');
  if (args.contains('--stage')) {
    stdout.write('Local username: ');
    final username = stdin.readLineSync()?.trim() ?? '';
    stdout.write('Temporary password: ');
    final terminal = stdin.hasTerminal;
    if (terminal) stdin.echoMode = false;
    String password;
    try {
      password = stdin.readLineSync() ?? '';
    } finally {
      if (terminal) stdin.echoMode = true;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.-]{3,64}$').hasMatch(username) ||
        password.length < 6 ||
        utf8.encode(password).length > 72) {
      throw StateError('Invalid local credentials.');
    }
    if (file.existsSync()) {
      throw StateError(
        'Staged credentials already exist. Remove them deliberately before restaging.',
      );
    }
    await file.writeAsString(
      jsonEncode({
        'username': username.toLowerCase(),
        'hash': const PasswordHasher().hash(password),
      }),
    );
    stdout.writeln(
      'Local credentials staged as a bcrypt hash. Apply after migration 004.',
    );
    return;
  }
  final config = ServerConfig.load();
  final data = jsonDecode(await file.readAsString()) as Map;
  final db = Database(config);
  try {
    await db.open();
    await db.connection.runTx((s) async {
      final row = await s.execute(
        Sql.named("""
    INSERT INTO users(email,username,password_hash,first_name,last_name,must_change_password)
    VALUES(@email,@username,@hash,'Local','Administrator',true) RETURNING id
   """),
        parameters: {
          'email': '${data['username']}@localhost.invalid',
          'username': data['username'],
          'hash': data['hash'],
        },
      );
      await s.execute(
        Sql.named(
          "INSERT INTO user_roles(user_id,role_id) SELECT @id,id FROM roles WHERE name='SUPER_ADMIN'",
        ),
        parameters: {'id': row.single[0]},
      );
    });
    stdout.writeln(
      'Local administrator created. Change the temporary password on first sign-in.',
    );
  } finally {
    await db.close();
  }
}
