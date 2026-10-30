import 'package:postgres/postgres.dart';

import '../../database/database.dart';

class AuditLogService {
  const AuditLogService(this._database);

  final Database _database;

  Future<void> record({
    required String? userId,
    required String action,
    required String resourceType,
    String? resourceId,
    String? description,
    String? ipAddress,
    String? userAgent,
  }) async {
    await _database.connection.execute(
      Sql.named('''
        INSERT INTO audit_logs (
          user_id,
          action,
          resource_type,
          resource_id,
          description,
          ip_address,
          user_agent
        )
        VALUES (
          @userId,
          @action,
          @resourceType,
          @resourceId,
          @description,
          @ipAddress,
          @userAgent
        )
      '''),
      parameters: {
        'userId': userId,
        'action': action,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'description': description,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
      },
    );
  }
}
