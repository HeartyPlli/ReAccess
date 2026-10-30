import 'package:postgres/postgres.dart';

import '../config/server_config.dart';

class Database {
  Database(this._config);

  final ServerConfig _config;
  Connection? _connection;

  Connection get connection {
    final current = _connection;
    if (current == null) {
      throw StateError('Database connection has not been opened.');
    }
    return current;
  }

  Future<void> open() async {
    _connection = await Connection.open(
      Endpoint(
        host: _config.databaseHost,
        port: _config.databasePort,
        database: _config.databaseName,
        username: _config.databaseUser,
        password: _config.databasePassword,
      ),
      settings: ConnectionSettings(
        sslMode: _config.databaseSsl ? SslMode.require : SslMode.disable,
      ),
    );
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }
}
