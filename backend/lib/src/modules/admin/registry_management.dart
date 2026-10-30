import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:postgres/postgres.dart';
import 'package:request_contract/request_contract.dart';
import 'package:xml/xml.dart';

import '../../database/database.dart';
import '../../errors/api_error.dart';
import '../auth/password_hasher.dart';

const registryColumns = <String>[
  'person_kind',
  'person_id',
  'first_name',
  'middle_name',
  'last_name',
  'institute',
  'program',
  'position',
  'school_email',
  'contact',
  'gmail',
  'active',
];

String _header(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return const {
        'type': 'person_kind',
        'user_type': 'person_kind',
        'student_or_faculty': 'person_kind',
        'id': 'person_id',
        'id_number': 'person_id',
        'student_id': 'person_id',
        'faculty_id': 'person_id',
        'firstname': 'first_name',
        'middlename': 'middle_name',
        'lastname': 'last_name',
        'school_email_address': 'school_email',
        'phone': 'contact',
        'contact_number': 'contact',
        'gmail_address': 'gmail',
      }[normalized] ??
      normalized;
}

List<List<String>> parseCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[], field = StringBuffer(), quoted = false;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (char == '"') {
      if (quoted && i + 1 < source.length && source[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      row.add(field.toString());
      field = StringBuffer();
    } else if ((char == '\n' || char == '\r') && !quoted) {
      if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      row.add(field.toString());
      field = StringBuffer();
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(char);
    }
  }
  if (quoted) throw const FormatException('Unclosed quoted CSV field.');
  row.add(field.toString());
  if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
  return rows;
}

int _columnIndex(String reference) {
  final letters =
      RegExp(r'^[A-Z]+').firstMatch(reference.toUpperCase())?.group(0) ?? '';
  var value = 0;
  for (final unit in letters.codeUnits) {
    value = value * 26 + unit - 64;
  }
  return value - 1;
}

List<List<String>> parseXlsx(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? named(String path) => archive.files
      .where((file) => file.isFile && file.name.replaceAll('\\', '/') == path)
      .firstOrNull;
  String contents(ArchiveFile file) => utf8.decode(file.content as List<int>);

  final shared = <String>[];
  final sharedFile = named('xl/sharedStrings.xml');
  if (sharedFile != null) {
    final document = XmlDocument.parse(contents(sharedFile));
    for (final item in document.findAllElements('si')) {
      shared.add(
        item.findAllElements('t').map((node) => node.innerText).join(),
      );
    }
  }
  final sheets =
      archive.files
          .where(
            (file) =>
                file.isFile &&
                RegExp(r'^xl/worksheets/sheet\d+\.xml$')
                    .hasMatch(file.name.replaceAll('\\', '/')),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  if (sheets.isEmpty) throw const FormatException('Workbook has no worksheet.');
  final document = XmlDocument.parse(contents(sheets.first));
  final result = <List<String>>[];
  for (final rowNode in document.findAllElements('row')) {
    final values = <int, String>{};
    var sequential = 0;
    for (final cell in rowNode.findElements('c')) {
      final reference = cell.getAttribute('r') ?? '';
      final index = reference.isEmpty ? sequential : _columnIndex(reference);
      sequential = index + 1;
      final type = cell.getAttribute('t');
      String value;
      if (type == 'inlineStr') {
        value = cell.findAllElements('t').map((e) => e.innerText).join();
      } else {
        value = cell.findElements('v').firstOrNull?.innerText ?? '';
        if (type == 's' && value.isNotEmpty) {
          final sharedIndex = int.tryParse(value);
          value = sharedIndex != null && sharedIndex < shared.length
              ? shared[sharedIndex]
              : '';
        }
      }
      values[index] = value;
    }
    if (values.isEmpty) continue;
    final width = values.keys.reduce((a, b) => a > b ? a : b) + 1;
    result.add(List.generate(width, (index) => values[index] ?? ''));
  }
  return result;
}

List<Map<String, String>> tabularRegistryRecords(
  String filename,
  Uint8List bytes,
) {
  final lower = filename.toLowerCase();
  final rows = lower.endsWith('.csv')
      ? parseCsv(utf8.decode(bytes, allowMalformed: false))
      : lower.endsWith('.xlsx')
      ? parseXlsx(bytes)
      : throw const FormatException('Upload a .csv or .xlsx file.');
  if (rows.length < 2) {
    throw const FormatException('The file has no data rows.');
  }
  final headers = rows.first.map(_header).toList();
  while (headers.isNotEmpty && headers.last.isEmpty) {
    headers.removeLast();
  }
  if (headers.toSet().length != headers.length) {
    throw const FormatException('Column names must be unique.');
  }
  final unknown = headers
      .where((header) => header.isEmpty || !registryColumns.contains(header))
      .toList();
  if (unknown.isNotEmpty) {
    throw FormatException('Unknown column: ${unknown.first}.');
  }
  for (final required in [
    'person_kind',
    'person_id',
    'first_name',
    'last_name',
    'institute',
    'school_email',
  ]) {
    if (!headers.contains(required)) {
      throw FormatException('Missing column: $required.');
    }
  }
  return [
    for (final row in rows.skip(1))
      {
        for (var index = 0; index < headers.length; index++)
          headers[index]: index < row.length ? row[index].trim() : '',
      },
  ];
}

class RegistryRecord {
  RegistryRecord._(this.values, this.data);
  final Map<String, String> values;
  final RequestData data;

  factory RegistryRecord.fromMap(
    Map<String, dynamic> input,
    Map<String, List<String>> catalog,
  ) {
    String text(String key) => (input[key] ?? '').toString().trim();
    final kind = text('person_kind').toUpperCase();
    final personId = text('person_id').toUpperCase();
    final first = text('first_name');
    final middle = text('middle_name');
    final last = text('last_name');
    final schoolEmail = text('school_email').toLowerCase();
    final contact = text('contact');
    final gmail = text('gmail').toLowerCase();
    final data = RequestData.fromJson({
      'personKind': kind,
      'requestKind': 'UPDATE',
      'fields': {
        'personId': personId,
        'firstName': first,
        'middleName': middle,
        'lastName': last,
        'institute': text('institute'),
        'program': text('program'),
        'position': text('position'),
        'schoolEmail': schoolEmail,
      },
    });
    final errors = data.validate(details: false, instituteCatalog: catalog);
    final contactError = phoneError(contact, optional: true);
    final gmailValidation = gmailError(gmail, optional: true);
    if (errors.isNotEmpty || contactError != null || gmailValidation != null) {
      throw FormatException(
        errors.values.firstOrNull ?? contactError ?? gmailValidation!,
      );
    }
    final activeText = text('active').toLowerCase();
    if (activeText.isNotEmpty &&
        !['true', 'false', 'yes', 'no', '1', '0'].contains(activeText)) {
      throw const FormatException('Active must be true/false, yes/no, or 1/0.');
    }
    return RegistryRecord._({
      'person_kind': data.personKind.code,
      'person_id': data['personId'],
      'first_name': data['firstName'],
      'middle_name': data['middleName'],
      'last_name': data['lastName'],
      'institute': data['institute'],
      'program': data['program'],
      'position': data['position'],
      'school_email': data['schoolEmail'],
      'contact': contact,
      'gmail': gmail,
      'active': ['false', 'no', '0'].contains(activeText) ? 'false' : 'true',
    }, data);
  }

  String get personId => values['person_id']!;
  String get fullName => [
    values['first_name'],
    values['middle_name'],
    values['last_name'],
  ].where((value) => value!.isNotEmpty).join(' ');
  Map<String, Object?> get parameters => {
    ...values,
    'active': values['active'] == 'true',
  };
}

class RegistryManagement {
  RegistryManagement(this.database);
  final Database database;
  final PasswordHasher _passwordHasher = const PasswordHasher();

  Future<Map<String, Object?>> list(Map<String, String> query) async {
    final kind = query['kind'] ?? '';
    final search = (query['search'] ?? '').trim();
    final page = int.tryParse(query['page'] ?? '0');
    if (!['', 'STUDENT', 'FACULTY'].contains(kind) ||
        page == null ||
        page < 0) {
      throw const ApiError(
        statusCode: 400,
        message: 'Invalid registry filters.',
      );
    }
    final rows = await database.connection.execute(
      Sql.named('''
      SELECT person_kind,person_id,first_name,middle_name,last_name,institute,
        program,position,school_email,contact,gmail,active,updated_at::text
      FROM school_registry
      WHERE (@kind='' OR person_kind=@kind)
        AND (person_id ILIKE @search OR concat(first_name,' ',middle_name,' ',last_name) ILIKE @search)
      ORDER BY last_name,first_name,person_id LIMIT 25 OFFSET @offset
      '''),
      parameters: {'kind': kind, 'search': '%$search%', 'offset': page * 25},
    );
    return {'rows': rows.map((row) => row.toColumnMap()).toList()};
  }

  Future<void> create(String actor, Map<String, dynamic> body) async {
    RegistryRecord record;
    try {
      record = RegistryRecord.fromMap(body, await _catalog());
    } on FormatException catch (error) {
      throw ApiError(statusCode: 400, message: error.message.toString());
    }
    await database.connection.runTx((session) async {
      await session.execute(
        Sql.named('SELECT pg_advisory_xact_lock(hashtextextended(@id,0))'),
        parameters: {'id': record.personId},
      );
      final existing = await _existing(session, record.personId);
      if (existing != null) throw _duplicate(existing);
      await _insert(session, record);
      await session.execute(
        Sql.named(
          "INSERT INTO audit_logs(user_id,action,resource_type,resource_id,description) VALUES(@actor,'REGISTRY_USER_ADDED','school_registry',@id,@name)",
        ),
        parameters: {
          'actor': actor,
          'id': record.personId,
          'name': record.fullName,
        },
      );
    });
  }

  Future<void> update(
    String actor,
    String personId,
    Map<String, dynamic> body,
  ) async {
    RegistryRecord record;
    try {
      record = RegistryRecord.fromMap(body, await _catalog());
    } on FormatException catch (error) {
      throw ApiError(statusCode: 400, message: error.message.toString());
    }
    final id = personId.trim().toUpperCase();
    if (record.personId != id) {
      throw const ApiError(
        statusCode: 400,
        message: 'The ID number cannot be changed. Create a new user instead.',
      );
    }
    await database.connection.runTx((session) async {
      await session.execute(
        Sql.named('SELECT pg_advisory_xact_lock(hashtextextended(@id,0))'),
        parameters: {'id': id},
      );
      final rows = await session.execute(
        Sql.named(
          'SELECT person_kind FROM school_registry WHERE person_id=@id FOR UPDATE',
        ),
        parameters: {'id': id},
      );
      if (rows.isEmpty) {
        throw const ApiError(
          statusCode: 404,
          message: 'The student or faculty record was not found.',
        );
      }
      if (rows.single[0] != record.values['person_kind']) {
        throw const ApiError(
          statusCode: 400,
          message:
              'The user type cannot be changed. Create a new user instead.',
        );
      }
      await _confirm(session, actor, body);
      await session.execute(
        Sql.named('''
          UPDATE school_registry SET
            first_name=@first_name,middle_name=@middle_name,last_name=@last_name,
            institute=@institute,program=@program,position=@position,
            school_email=@school_email,contact=@contact,gmail=@gmail,
            active=@active,updated_at=now()
          WHERE person_id=@person_id
        '''),
        parameters: record.parameters,
      );
      await _audit(
        session,
        actor,
        'REGISTRY_USER_UPDATED',
        id,
        'Updated registry data for ${record.fullName}.',
      );
    });
  }

  Future<void> delete(
    String actor,
    String personId,
    Map<String, dynamic> body,
  ) async {
    final id = personId.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(id)) {
      throw const ApiError(statusCode: 400, message: 'Invalid ID number.');
    }
    await database.connection.runTx((session) async {
      await session.execute(
        Sql.named('SELECT pg_advisory_xact_lock(hashtextextended(@id,0))'),
        parameters: {'id': id},
      );
      final rows = await session.execute(
        Sql.named('''
          SELECT first_name,middle_name,last_name
          FROM school_registry WHERE person_id=@id FOR UPDATE
        '''),
        parameters: {'id': id},
      );
      if (rows.isEmpty) {
        throw const ApiError(
          statusCode: 404,
          message: 'The student or faculty record was not found.',
        );
      }
      await _confirm(session, actor, body);
      final values = rows.single.toColumnMap();
      final name =
          [values['first_name'], values['middle_name'], values['last_name']]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(' ');
      await session.execute(
        Sql.named('DELETE FROM school_registry WHERE person_id=@id'),
        parameters: {'id': id},
      );
      await _audit(
        session,
        actor,
        'REGISTRY_USER_DELETED',
        id,
        'Permanently deleted registry data for $name.',
      );
    });
  }

  Future<Map<String, Object?>> bulk(
    String actor,
    String filename,
    Uint8List bytes,
  ) async {
    List<Map<String, String>> source;
    try {
      source = tabularRegistryRecords(filename, bytes);
    } on Object catch (error) {
      throw ApiError(
        statusCode: 400,
        message: error is FormatException
            ? error.message.toString()
            : 'The spreadsheet could not be read.',
      );
    }
    if (source.length > 1000) {
      throw const ApiError(
        statusCode: 400,
        message: 'Import at most 1,000 users at a time.',
      );
    }
    final added = <String>[];
    final duplicates = <String>[];
    final errors = <String>[];
    final catalog = await _catalog();
    await database.connection.runTx((session) async {
      for (var index = 0; index < source.length; index++) {
        RegistryRecord record;
        try {
          record = RegistryRecord.fromMap(source[index], catalog);
        } on FormatException catch (error) {
          errors.add('Row ${index + 2}: ${error.message}');
          continue;
        }
        await session.execute(
          Sql.named('SELECT pg_advisory_xact_lock(hashtextextended(@id,0))'),
          parameters: {'id': record.personId},
        );
        final existing = await _existing(session, record.personId);
        if (existing != null) {
          duplicates.add(_duplicate(existing).message);
          continue;
        }
        await _insert(session, record);
        added.add(record.personId);
      }
      await session.execute(
        Sql.named(
          "INSERT INTO audit_logs(user_id,action,resource_type,description) VALUES(@actor,'REGISTRY_BULK_IMPORTED','school_registry',@description)",
        ),
        parameters: {
          'actor': actor,
          'description':
              'Added ${added.length}; duplicates ${duplicates.length}; invalid ${errors.length}',
        },
      );
    });
    return {'added': added.length, 'duplicates': duplicates, 'errors': errors};
  }

  Future<Map<String, dynamic>?> _existing(Session session, String id) async {
    final rows = await session.execute(
      Sql.named(
        'SELECT person_id,first_name,middle_name,last_name FROM school_registry WHERE person_id=@id',
      ),
      parameters: {'id': id},
    );
    return rows.isEmpty ? null : rows.single.toColumnMap();
  }

  Future<Map<String, List<String>>> _catalog() async {
    final rows = await database.connection.execute('''
      SELECT i.name,p.name FROM institutions i
      LEFT JOIN institution_programs p
        ON p.institution_id=i.id AND p.active=true
      WHERE i.active=true
      ORDER BY CASE i.name
        WHEN 'Institute of Computer Studies' THEN 1
        WHEN 'Institute of Health Sciences' THEN 2
        WHEN 'Institute of Art and Sciences' THEN 3
        WHEN 'Institute of Teacher Education' THEN 4
        WHEN 'Institute of Business and Financial Services' THEN 5
        WHEN 'Institute of Criminal Justice Education' THEN 6
        ELSE 99
      END,i.name,p.name
    ''');
    final catalog = <String, List<String>>{};
    for (final row in rows) {
      final programs = catalog.putIfAbsent(row[0] as String, () => []);
      if (row[1] != null) programs.add(row[1] as String);
    }
    return catalog;
  }

  ApiError _duplicate(Map<String, dynamic> existing) {
    final name = [
      existing['first_name'],
      existing['middle_name'],
      existing['last_name'],
    ].where((value) => value != null && value.toString().isNotEmpty).join(' ');
    return ApiError(
      statusCode: 409,
      message:
          'ID number: "${existing['person_id']}" and name "$name" already existed in the system.',
    );
  }

  Future<void> _insert(Session session, RegistryRecord record) =>
      session.execute(
        Sql.named('''
    INSERT INTO school_registry(person_kind,person_id,first_name,middle_name,last_name,
      institute,program,position,school_email,contact,gmail,active)
    VALUES(@person_kind,@person_id,@first_name,@middle_name,@last_name,
      @institute,@program,@position,@school_email,@contact,@gmail,@active)
    '''),
        parameters: record.parameters,
      );

  Future<void> _confirm(
    Session session,
    String actor,
    Map<String, dynamic> body,
  ) async {
    final username = body['username'];
    final password = body['password'];
    if (username is! String ||
        password is! String ||
        username.length > 254 ||
        password.isEmpty ||
        utf8.encode(password).length > 72) {
      throw const ApiError(
        statusCode: 403,
        message: 'Enter your current username and password to confirm.',
      );
    }
    final rows = await session.execute(
      Sql.named('''
        SELECT username,password_hash,status FROM users WHERE id=@id FOR UPDATE
      '''),
      parameters: {'id': actor},
    );
    if (rows.isEmpty ||
        rows.single[2] != 'ACTIVE' ||
        rows.single[0].toString().toLowerCase() !=
            username.trim().toLowerCase() ||
        !_passwordHasher.verify(
          password: password,
          passwordHash: rows.single[1] as String,
        )) {
      throw const ApiError(
        statusCode: 403,
        message: 'The confirmation username or password is incorrect.',
      );
    }
  }

  Future<void> _audit(
    Session session,
    String actor,
    String action,
    String resourceId,
    String description,
  ) => session.execute(
    Sql.named('''
      INSERT INTO audit_logs(user_id,action,resource_type,resource_id,description)
      VALUES(@actor,@action,'school_registry',@id,@description)
    '''),
    parameters: {
      'actor': actor,
      'action': action,
      'id': resourceId,
      'description': description,
    },
  );
}
