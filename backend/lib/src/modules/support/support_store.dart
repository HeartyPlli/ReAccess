import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../database/database.dart';
import '../../errors/api_error.dart';
import '../auth/password_hasher.dart';

abstract class SupportStore {
  Future<bool> personExists(String personId);
  Future<String> create({
    required String personId,
    required String tokenHash,
    required List<Map<String, String>> messages,
  });
  Future<Map<String, Object?>?> status(String id, String tokenHash);
  Future<List<Map<String, Object?>>> list();
  Future<bool> reply(String id, String reply, String userId);
  Future<bool> deleteConversation({
    required String id,
    required String userId,
    required String username,
    required String password,
  });
}

class PostgresSupportStore implements SupportStore {
  PostgresSupportStore(this.database);
  final Database database;
  final PasswordHasher _passwordHasher = const PasswordHasher();
  @override
  Future<bool> personExists(String personId) async {
    final rows = await database.connection.execute(
      Sql.named(
        'SELECT 1 FROM school_registry WHERE person_id = @id AND active = true LIMIT 1',
      ),
      parameters: {'id': personId},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<String> create({
    required String personId,
    required String tokenHash,
    required List<Map<String, String>> messages,
  }) async {
    final rows = await database.connection.execute(
      Sql.named('''
      INSERT INTO support_tickets (person_id, visitor_token_hash, transcript)
      VALUES (@personId, @hash, CAST(@transcript AS jsonb)) RETURNING id
    '''),
      parameters: {
        'personId': personId,
        'hash': tokenHash,
        'transcript': jsonEncode(messages),
      },
    );
    return rows.single[0] as String;
  }

  @override
  Future<Map<String, Object?>?> status(String id, String tokenHash) async {
    final rows = await database.connection.execute(
      Sql.named('''
      SELECT status, reply FROM support_tickets
      WHERE id = @id AND visitor_token_hash = @hash AND expires_at > now()
    '''),
      parameters: {'id': id, 'hash': tokenHash},
    );
    return rows.isEmpty ? null : rows.single.toColumnMap();
  }

  @override
  Future<List<Map<String, Object?>>> list() async {
    final rows = await database.connection.execute(
      Sql.named('''
      SELECT id, person_id, transcript, status, reply, created_at::text
      FROM support_tickets WHERE expires_at > now()
      ORDER BY (status = 'OPEN') DESC, created_at DESC LIMIT 100
    '''),
    );
    return rows.map((row) => row.toColumnMap()).toList();
  }

  @override
  Future<bool> reply(String id, String reply, String userId) =>
      database.connection.runTx((session) async {
        final rows = await session.execute(
          Sql.named('''
      UPDATE support_tickets SET reply = @reply, status = 'ANSWERED',
        replied_by = @userId, updated_at = now()
      WHERE id = @id AND expires_at > now() RETURNING id
    '''),
          parameters: {'reply': reply, 'userId': userId, 'id': id},
        );
        if (rows.isEmpty) return false;
        await session.execute(
          Sql.named('''
      INSERT INTO audit_logs (user_id, action, resource_type, resource_id)
      VALUES (@userId, 'SUPPORT_REPLIED', 'support_ticket', @id)
    '''),
          parameters: {'userId': userId, 'id': id},
        );
        return true;
      });

  @override
  Future<bool> deleteConversation({
    required String id,
    required String userId,
    required String username,
    required String password,
  }) => database.connection.runTx((session) async {
    final users = await session.execute(
      Sql.named('''
        SELECT username,password_hash,status FROM users WHERE id=@id FOR UPDATE
      '''),
      parameters: {'id': userId},
    );
    if (users.isEmpty ||
        users.single[2] != 'ACTIVE' ||
        users.single[0].toString().toLowerCase() !=
            username.trim().toLowerCase() ||
        !_passwordHasher.verify(
          password: password,
          passwordHash: users.single[1] as String,
        )) {
      throw const ApiError(
        statusCode: 403,
        message: 'The confirmation username or password is incorrect.',
      );
    }
    final tickets = await session.execute(
      Sql.named(
        'SELECT person_id FROM support_tickets WHERE id=@id FOR UPDATE',
      ),
      parameters: {'id': id},
    );
    if (tickets.isEmpty) return false;
    final personId = tickets.single[0]?.toString() ?? 'unknown';
    await session.execute(
      Sql.named('DELETE FROM support_tickets WHERE id=@id'),
      parameters: {'id': id},
    );
    await session.execute(
      Sql.named('''
        INSERT INTO audit_logs(user_id,action,resource_type,resource_id,description)
        VALUES(@userId,'SUPPORT_DELETED','support_ticket',@id,@description)
      '''),
      parameters: {
        'userId': userId,
        'id': id,
        'description':
            'Permanently deleted the support conversation for ID $personId.',
      },
    );
    return true;
  });
}
