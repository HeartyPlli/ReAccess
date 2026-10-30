import 'dart:io';

import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';
import 'package:reaccess_hub_backend/src/routing/app_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> arguments) async {
  final config = ServerConfig.load();
  final database = Database(config);

  if (!config.skipDatabaseConnection) {
    await database.open();
  }

  final handler = buildHandler(config: config, database: database);
  final server = await shelf_io.serve(handler, config.host, config.port);

  stdout.writeln(
    'ReAccess API listening on http://${server.address.host}:${server.port}',
  );
}
