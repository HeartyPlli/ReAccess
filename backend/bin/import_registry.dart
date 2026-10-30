import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:request_contract/request_contract.dart';
import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run bin/import_registry.dart <private-registry.json>',
    );
    exitCode = 1;
    return;
  }
  Database? database;
  try {
    final raw = jsonDecode(await File(args.single).readAsString());
    if (raw is! List || raw.isEmpty || raw.length > 10000) {
      throw const FormatException();
    }
    final records = raw.map((item) {
      final data = RequestData.fromJson({
        ...Map<String, dynamic>.from(item as Map),
        'requestKind': 'UPDATE',
      });
      if (data.validate(details: false).isNotEmpty) {
        throw const FormatException();
      }
      return data;
    }).toList();
    database = Database(ServerConfig.load());
    await database.open();
    await database.connection.runTx((session) async {
      for (final data in records) {
        // Trusted maintenance import only; submissions never modify the registry.
        await session.execute(
          Sql.named("""
          INSERT INTO school_registry
            (person_kind, person_id, first_name, middle_name, last_name, institute, program, position, school_email)
          VALUES (@kind,@id,@first,@middle,@last,@institute,@program,@position,@email)
          ON CONFLICT (person_id) DO UPDATE SET
            person_kind=EXCLUDED.person_kind,
            first_name=EXCLUDED.first_name, middle_name=EXCLUDED.middle_name,
            last_name=EXCLUDED.last_name, institute=EXCLUDED.institute,
            program=EXCLUDED.program, position=EXCLUDED.position,
            school_email=EXCLUDED.school_email, updated_at=now()
        """),
          parameters: {
            'kind': data.personKind.code,
            'id': data['personId'],
            'first': data['firstName'],
            'middle': data['middleName'],
            'last': data['lastName'],
            'institute': data['institute'],
            'program': data['program'],
            'position': data['position'],
            'email': data['schoolEmail'],
          },
        );
      }
      await session.execute("""
        INSERT INTO audit_logs (action, resource_type, description)
        VALUES ('REGISTRY_IMPORTED', 'school_registry', 'Trusted maintenance import')
      """);
    });
    stdout.writeln('Imported ${records.length} registry records.');
  } catch (_) {
    stderr.writeln(
      'Import failed. Check the private input format, field validation, database configuration, and migrations. No partial import was committed.',
    );
    exitCode = 1;
  } finally {
    await database?.close();
  }
}
