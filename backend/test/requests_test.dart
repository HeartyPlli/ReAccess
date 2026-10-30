import 'dart:convert';

import 'package:reaccess_hub_backend/src/database/database.dart';
import 'package:reaccess_hub_backend/src/errors/api_error.dart';
import 'package:reaccess_hub_backend/src/modules/requests/request_store.dart';
import 'package:reaccess_hub_backend/src/routing/app_router.dart';
import 'package:request_contract/request_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support_test.dart' as fixtures;

class FakeRequests implements RequestStore {
  bool fail = false;
  ApiError? mismatch;
  int submits = 0;
  final saved = <String, String>{};
  @override
  Future<RequestConfiguration> configuration() async => RequestConfiguration(
    institutions: institutePrograms,
    studentRequestLimit: 2,
  );

  @override
  Future<int> verify(RequestData data) async {
    if (fail) throw StateError('private database detail');
    if (mismatch != null) throw mismatch!;
    return 3;
  }

  @override
  Future<String> submit(RequestData data, String nonce) async {
    await verify(data);
    return saved.putIfAbsent(
      nonce,
      () =>
          'REQ-${data.personKind.prefix}-2026-09-${(++submits).toString().padLeft(4, '0')}',
    );
  }

  @override
  Future<List<Map<String, Object?>>> list(
    String kind,
    String type,
    int page,
  ) async => [];
}

Map<String, dynamic> payload({
  String type = 'SSPR',
  String person = 'STUDENT',
}) => {
  'personKind': person,
  'requestKind': type,
  'fields': {
    'firstName': 'Juan',
    'lastName': 'Cruz',
    'personId': person == 'STUDENT' ? '123456' : 'AB1234',
    'institute': institutePrograms.keys.first,
    if (person == 'STUDENT')
      'program': institutePrograms.values.first.single
    else
      'position': 'Full Time',
    'schoolEmail': 'cruzjuan@gadtc.edu.ph',
    'contact': '09123456789',
    'gmail': 'juan@gmail.com',
    'alternativeGmail': 'newjuan@gmail.com',
    'reason': 'Unable to access my account',
  },
};
void main() {
  late FakeRequests store;
  late Handler handler;
  setUp(() {
    store = FakeRequests();
    final c = fixtures.config();
    handler = buildHandler(
      config: c,
      database: Database(c),
      requestStore: store,
    );
  });
  for (final person in ['STUDENT', 'FACULTY']) {
    for (final kind in ['SSPR', 'RECOVERY', 'UPDATE']) {
      test(
        '$person $kind verifies then submits with a server reference',
        () async {
          final data = payload(type: kind, person: person);
          final verified = await handler(
            fixtures.post('public/requests/verify', data),
          );
          expect(verified.statusCode, 200);
          final result = jsonDecode(await verified.readAsString()) as Map;
          expect(result['previousRequests'], 3);
          expect(result['requiresFormalLetter'], person == 'STUDENT');
          data['verificationToken'] = result['verificationToken'];
          final submitted = await handler(
            fixtures.post('public/requests', data),
          );
          expect(submitted.statusCode, 200);
          final first = await submitted.readAsString();
          final retry = await handler(fixtures.post('public/requests', data));
          expect(await retry.readAsString(), first);
          expect(store.submits, 1);
        },
      );
    }
  }
  test(
    'cannot skip verification or alter identity after verification',
    () async {
      final data = payload();
      expect(
        (await handler(fixtures.post('public/requests', data))).statusCode,
        422,
      );
      final verify = await handler(
        fixtures.post('public/requests/verify', data),
      );
      data['verificationToken'] = jsonDecode(
        await verify.readAsString(),
      )['verificationToken'];
      (data['fields'] as Map)['personId'] = '654321';
      expect(
        (await handler(fixtures.post('public/requests', data))).statusCode,
        422,
      );
      expect(store.submits, 0);
    },
  );
  test('invalid fields and mismatches cannot advance', () async {
    final data = payload();
    (data['fields'] as Map)['personId'] = '123';
    expect(
      (await handler(fixtures.post('public/requests/verify', data))).statusCode,
      400,
    );
    store.mismatch = const ApiError(
      statusCode: 422,
      message: 'Information could not be verified.',
    );
    expect(
      (await handler(
        fixtures.post('public/requests/verify', payload(type: 'RECOVERY')),
      )).statusCode,
      422,
    );
    store.mismatch = const ApiError(
      statusCode: 409,
      message: 'Already enrolled.',
    );
    expect(
      (await handler(fixtures.post('public/requests/verify', payload())))
          .statusCode,
      409,
    );
  });
  test('database failure gives safe error, not a receipt', () async {
    store.fail = true;
    final response = await handler(
      fixtures.post('public/requests/verify', payload()),
    );
    expect(response.statusCode, 503);
    expect(await response.readAsString(), isNot(contains('private database')));
  });
  test('admin requests need authentication and permission', () async {
    final request = Request(
      'GET',
      Uri.parse('http://localhost/api/v1/admin/requests'),
    );
    expect((await handler(request)).statusCode, 401);
    final c = fixtures.config();
    final denied = buildHandler(
      config: c,
      database: Database(c),
      requestStore: store,
      requestAuthorization: (_) async => throw ApiError.forbidden,
    );
    expect(
      (await denied(Request('GET', request.requestedUri))).statusCode,
      403,
    );
  });
  test('anonymous verification is rate limited', () async {
    for (var i = 0; i < 10; i++) {
      await handler(fixtures.post('public/requests/verify', payload()));
    }
    expect(
      (await handler(fixtures.post('public/requests/verify', payload())))
          .statusCode,
      429,
    );
  });
}
