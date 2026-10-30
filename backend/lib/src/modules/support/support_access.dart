import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../../database/database.dart';
import '../../errors/api_error.dart';
import '../auth/token_service.dart';

typedef SupportAccess = Future<String> Function(Request request);

SupportAccess supportAccess(
  Database database,
  TokenService tokens, {
  String permission = 'manage_support',
  bool allowPasswordChange = false,
}) => (request) async {
  final authorization = request.headers['authorization'] ?? '';
  if (!authorization.startsWith('Bearer ')) throw ApiError.unauthorized;
  String id;
  int version;
  try {
    final jwt = tokens.verifyAccessToken(authorization.substring(7));
    final subject = jwt.payload['sub'];
    if (subject is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(subject)) {
      throw ApiError.unauthorized;
    }
    id = subject;
    version = jwt.payload['version'] as int? ?? 0;
  } on JWTException {
    throw ApiError.unauthorized;
  } on TypeError {
    throw ApiError.unauthorized;
  }
  // Recheck active status and current grants in the database on every request.
  final users = await database.connection.execute(
    Sql.named(
      'SELECT status,token_version,must_change_password FROM users WHERE id = @id',
    ),
    parameters: {'id': id},
  );
  if (users.isEmpty || users.single[0] != 'ACTIVE') throw ApiError.unauthorized;
  if (users.single[1] != version) throw ApiError.unauthorized;
  if (users.single[2] == true && !allowPasswordChange) {
    throw const ApiError(
      statusCode: 403,
      message: 'Change your temporary password first.',
    );
  }
  final permissions = await database.connection.execute(
    Sql.named('''
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    JOIN role_permissions rp ON rp.role_id = r.id
    JOIN permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = @id AND r.name IN ('SUPER_ADMIN', 'ADMIN')
      AND (@permission = '' OR p.name = @permission) LIMIT 1
  '''),
    parameters: {'id': id, 'permission': permission},
  );
  if (permissions.isEmpty) throw ApiError.forbidden;
  return id;
};
