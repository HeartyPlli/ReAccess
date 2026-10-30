import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../database/database.dart';
import '../../errors/api_error.dart';
import 'password_hasher.dart';
import 'token_service.dart';

class AuthService {
  AuthService({
    required this.database,
    required this.passwordHasher,
    required this.tokenService,
  });
  final Database database;
  final PasswordHasher passwordHasher;
  final TokenService tokenService;
  Future<JsonMap> login({
    required String email,
    required String password,
  }) async {
    final login = email.trim().toLowerCase();
    if (login.isEmpty ||
        login.length > 254 ||
        password.isEmpty ||
        utf8.encode(password).length > 72) {
      return _invalid();
    }
    final rows = await database.connection.execute(
      Sql.named("""
   SELECT * FROM users WHERE lower(username)=@login OR lower(email)=@login LIMIT 1
  """),
      parameters: {'login': login},
    );
    if (rows.isEmpty) {
      // Perform the same expensive operation without disclosing account existence.
      passwordHasher.hash(password);
      return _invalid();
    }
    final row = rows.single.toColumnMap();
    if (!passwordHasher.verify(
          password: password,
          passwordHash: row['password_hash'] as String,
        ) ||
        row['status'] != 'ACTIVE') {
      return _invalid();
    }
    if (row['must_change_password'] == true && tokenService.isProduction) {
      return _invalid();
    }
    final user = await profile(row['id'] as String);
    final token = tokenService.createAccessToken(
      userId: row['id'] as String,
      email: row['email'] as String,
      roles: (user['roles'] as List).cast<String>(),
      permissions: (user['permissions'] as List).cast<String>(),
      version: row['token_version'] as int,
    );
    await database.connection.execute(
      Sql.named(
        "INSERT INTO audit_logs(user_id,action,resource_type,resource_id) VALUES(@id::uuid,'ADMIN_LOGIN','user',@id::text)",
      ),
      parameters: {'id': row['id']},
    );
    return {'success': true, 'accessToken': token, 'user': user};
  }

  Future<JsonMap> profile(String id) async {
    final rows = await database.connection.execute(
      Sql.named(
        'SELECT id,username,email,first_name,last_name,status,must_change_password FROM users WHERE id=@id',
      ),
      parameters: {'id': id},
    );
    if (rows.isEmpty) throw ApiError.unauthorized;
    final roles = await database.connection.execute(
      Sql.named(
        'SELECT r.name FROM roles r JOIN user_roles ur ON ur.role_id=r.id WHERE ur.user_id=@id',
      ),
      parameters: {'id': id},
    );
    final permissions = await database.connection.execute(
      Sql.named(
        'SELECT DISTINCT p.name FROM permissions p JOIN role_permissions rp ON rp.permission_id=p.id JOIN user_roles ur ON ur.role_id=rp.role_id WHERE ur.user_id=@id',
      ),
      parameters: {'id': id},
    );
    final r = rows.single.toColumnMap();
    return {
      'id': id,
      'username': r['username'],
      'email': r['email'],
      'firstName': r['first_name'],
      'lastName': r['last_name'],
      'status': r['status'],
      'mustChangePassword': r['must_change_password'],
      'roles': roles.map((r) => r[0]).toList(),
      'permissions': permissions.map((r) => r[0]).toList(),
    };
  }

  Future<void> credentials(String id, Map<String, dynamic> data) async {
    final old = data['oldPassword'],
        username = data['username'],
        password = data['newPassword'],
        confirm = data['confirmPassword'];
    if (old is! String ||
        utf8.encode(old).length > 72 ||
        username is! String ||
        !RegExp(r'^[a-zA-Z0-9_.-]{3,64}$').hasMatch(username) ||
        password is! String ||
        confirm is! String ||
        password != confirm ||
        (password.isNotEmpty &&
            (password.length < 8 ||
                utf8.encode(password).length > 72 ||
                password != confirm))) {
      throw const ApiError(
        statusCode: 400,
        message: 'Use a valid username and matching password of at least 8 characters (up to 72 UTF-8 bytes).',
      );
    }
    await database.connection.runTx((s) async {
      final rows = await s.execute(
        Sql.named(
          'SELECT password_hash,must_change_password FROM users WHERE id=@id FOR UPDATE',
        ),
        parameters: {'id': id},
      );
      if (rows.isEmpty ||
          !passwordHasher.verify(
            password: old,
            passwordHash: rows.single[0] as String,
          )) {
        throw const ApiError(
          statusCode: 403,
          message: 'The current password is incorrect.',
        );
      }
      if (rows.single[1] == true && password.isEmpty) {
        throw const ApiError(
          statusCode: 400,
          message: 'Set a new password before continuing.',
        );
      }
      if (password.isNotEmpty && password == old) {
        throw const ApiError(
          statusCode: 400,
          message: 'Choose a different password.',
        );
      }
      final duplicate = await s.execute(
        Sql.named(
          'SELECT id FROM users WHERE (lower(username)=@username OR lower(email)=@username) AND id<>@id',
        ),
        parameters: {'username': username.toLowerCase(), 'id': id},
      );
      if (duplicate.isNotEmpty) {
        throw const ApiError(
          statusCode: 409,
          message: 'That username is unavailable.',
        );
      }
      await s.execute(
        Sql.named("""
    UPDATE users SET username=@username,password_hash=@hash,must_change_password=false,
     token_version=token_version+1,updated_at=now() WHERE id=@id
   """),
        parameters: {
          'username': username.toLowerCase(),
          'hash': password.isEmpty
              ? rows.single[0]
              : passwordHasher.hash(password),
          'id': id,
        },
      );
      await s.execute(
        Sql.named(
          "INSERT INTO audit_logs(user_id,action,resource_type,resource_id) VALUES(@id::uuid,'CREDENTIALS_CHANGED','user',@id::text)",
        ),
        parameters: {'id': id},
      );
    });
  }

  Future<void> logout(String id) async {
    await database.connection.runTx((s) async {
      await s.execute(
        Sql.named(
          'UPDATE users SET token_version=token_version+1 WHERE id=@id',
        ),
        parameters: {'id': id},
      );
      await s.execute(
        Sql.named(
          "INSERT INTO audit_logs(user_id,action,resource_type,resource_id) VALUES(@id::uuid,'ADMIN_LOGOUT','user',@id::text)",
        ),
        parameters: {'id': id},
      );
    });
  }

  JsonMap _invalid() => {
    'success': false,
    'message': 'Invalid username or password.',
  };
}

typedef JsonMap = Map<String, Object?>;
