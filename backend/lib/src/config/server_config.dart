import 'dart:io';

class ServerConfig {
  ServerConfig({
    required this.environment,
    required this.host,
    required this.port,
    required this.databaseHost,
    required this.databasePort,
    required this.databaseName,
    required this.databaseUser,
    required this.databasePassword,
    required this.databaseSsl,
    required this.jwtSecret,
    required this.accessTokenMinutes,
    required this.refreshTokenDays,
    required this.allowedOrigins,
    required this.skipDatabaseConnection,
    this.aiApiKey = '',
    this.aiModel = '',
  });

  final String environment;
  final String host;
  final int port;
  final String databaseHost;
  final int databasePort;
  final String databaseName;
  final String databaseUser;
  final String databasePassword;
  final bool databaseSsl;
  final String jwtSecret;
  final int accessTokenMinutes;
  final int refreshTokenDays;
  final List<String> allowedOrigins;
  final bool skipDatabaseConnection;
  final String aiApiKey;
  final String aiModel;

  bool get isProduction => environment == 'production';

  static ServerConfig load() {
    final env = environmentValues();

    String read(String key, {String? fallback}) {
      return env[key] ?? fallback ?? '';
    }

    int readInt(String key, int fallback) {
      return int.tryParse(read(key)) ?? fallback;
    }

    bool readBool(String key, {bool fallback = false}) {
      final value = read(key).toLowerCase();
      if (value == 'true' || value == '1') {
        return true;
      }
      if (value == 'false' || value == '0') {
        return false;
      }
      return fallback;
    }

    final config = ServerConfig(
      environment: read('APP_ENV', fallback: 'development'),
      host: read('API_HOST', fallback: '0.0.0.0'),
      port: readInt('API_PORT', 8080),
      databaseHost: read('DATABASE_HOST', fallback: 'localhost'),
      databasePort: readInt('DATABASE_PORT', 5432),
      databaseName: read('DATABASE_NAME', fallback: 'reaccess_hub'),
      databaseUser: read('DATABASE_USER', fallback: 'reaccess_app'),
      databasePassword: read('DATABASE_PASSWORD'),
      databaseSsl: readBool('DATABASE_SSL'),
      jwtSecret: read('JWT_SECRET'),
      accessTokenMinutes: readInt('ACCESS_TOKEN_MINUTES', 15),
      refreshTokenDays: readInt('REFRESH_TOKEN_DAYS', 7),
      allowedOrigins:
          read(
                'ALLOWED_ORIGINS',
                fallback: 'http://localhost:3000,http://localhost:8081',
              )
              .split(',')
              .map((origin) => origin.trim())
              .where((origin) => origin.isNotEmpty)
              .toList(),
      skipDatabaseConnection: readBool('SKIP_DATABASE_CONNECTION'),
      aiApiKey: read('AI_API_KEY'),
      aiModel: read('AI_MODEL'),
    );

    if (config.isProduction && config.jwtSecret.length < 32) {
      throw StateError(
        'JWT_SECRET must be at least 32 characters in production.',
      );
    }

    if (!config.skipDatabaseConnection && config.databasePassword.isEmpty) {
      throw StateError('DATABASE_PASSWORD must be configured.');
    }

    return config;
  }

  static Map<String, String> environmentValues() => {
    ..._readDotEnvFile('.env'),
    ...Platform.environment,
  };

  static Map<String, String> _readDotEnvFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return {};
    }

    final values = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final separator = trimmed.indexOf('=');
      if (separator <= 0) {
        continue;
      }

      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      values[key] = value;
    }
    return values;
  }
}
