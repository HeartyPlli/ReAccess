import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';
import 'package:reaccess_hub_backend/src/routing/app_router.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('health endpoint returns ok', () async {
    final config = ServerConfig(
      environment: 'test',
      host: 'localhost',
      port: 8080,
      databaseHost: 'localhost',
      databasePort: 5432,
      databaseName: 'reaccess_hub_test',
      databaseUser: 'reaccess_app',
      databasePassword: 'not-used',
      databaseSsl: false,
      jwtSecret: 'test-secret-with-more-than-32-characters',
      accessTokenMinutes: 15,
      refreshTokenDays: 7,
      allowedOrigins: const ['http://localhost:3000'],
      skipDatabaseConnection: true,
    );

    final handler = buildHandler(config: config, database: Database(config));
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/health')),
    );

    expect(response.statusCode, 200);
    expect(await response.readAsString(), contains('"status":"ok"'));

    final letter = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/v1/public/letter-template'),
      ),
    );
    expect(letter.statusCode, 200);
    expect(
      letter.headers['content-type'],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final bytes = await letter.read().expand((chunk) => chunk).toList();
    expect(bytes.take(2), [0x50, 0x4b]);
  });
}
