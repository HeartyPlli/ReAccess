import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reaccess_hub_backend/src/config/server_config.dart';
import 'package:reaccess_hub_backend/src/database/database.dart';
import 'package:reaccess_hub_backend/src/errors/api_error.dart';
import 'package:reaccess_hub_backend/src/modules/support/support_ai.dart';
import 'package:reaccess_hub_backend/src/modules/support/support_knowledge.dart';
import 'package:reaccess_hub_backend/src/modules/support/support_store.dart';
import 'package:reaccess_hub_backend/src/routing/app_router.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

ServerConfig config({bool ai = false}) => ServerConfig(
  environment: 'test',
  host: 'localhost',
  port: 8080,
  databaseHost: 'localhost',
  databasePort: 5432,
  databaseName: 'test',
  databaseUser: 'test',
  databasePassword: '',
  databaseSsl: false,
  jwtSecret: 'a-test-secret-with-more-than-32-characters',
  accessTokenMinutes: 15,
  refreshTokenDays: 7,
  allowedOrigins: ['http://localhost:3000'],
  skipDatabaseConnection: true,
  aiApiKey: ai ? 'test-only' : '',
  aiModel: ai ? 'test-model' : '',
);
Request post(String path, Object data) => Request(
  'POST',
  Uri.parse('http://localhost/api/v1/$path'),
  headers: {'content-type': 'application/json'},
  body: jsonEncode(data),
);

class MemoryStore implements SupportStore {
  static const id = '01234567-0123-4123-8123-0123456789ab';
  String? hash;
  String? response;
  bool fail = false;
  bool knownPerson = true;
  String? personId;
  bool deleted = false;
  String? deletedUsername;
  @override
  Future<bool> personExists(String personId) async => knownPerson;
  @override
  Future<String> create({
    required String personId,
    required String tokenHash,
    required List<Map<String, String>> messages,
  }) async {
    if (fail) throw StateError('database unavailable');
    this.personId = personId;
    hash = tokenHash;
    return id;
  }

  @override
  Future<Map<String, Object?>?> status(String id, String tokenHash) async =>
      id == MemoryStore.id && tokenHash == hash
      ? {'status': response == null ? 'OPEN' : 'ANSWERED', 'reply': response}
      : null;
  @override
  Future<List<Map<String, Object?>>> list() async => [];
  @override
  Future<bool> reply(String id, String reply, String userId) async {
    response = reply;
    return true;
  }

  @override
  Future<bool> deleteConversation({
    required String id,
    required String userId,
    required String username,
    required String password,
  }) async {
    if (id != MemoryStore.id) return false;
    deleted = true;
    deletedUsername = username;
    return true;
  }
}

void main() {
  late Handler handler;
  late MemoryStore store;
  setUp(() {
    final c = config();
    store = MemoryStore();
    handler = buildHandler(
      config: c,
      database: Database(c),
      supportStore: store,
    );
  });
  test('missing and invalid admin tokens return 401', () async {
    for (final headers in [
      <String, String>{},
      {'authorization': 'Bearer invalid'},
    ]) {
      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/v1/admin/support'),
          headers: headers,
        ),
      );
      expect(response.statusCode, 401);
    }
  });
  test('permission denial returns 403', () async {
    final c = config();
    final forbidden = buildHandler(
      config: c,
      database: Database(c),
      supportStore: store,
      supportAuthorization: (_) async => throw ApiError.forbidden,
    );
    final response = await forbidden(
      Request('GET', Uri.parse('http://localhost/api/v1/admin/support')),
    );
    expect(response.statusCode, 403);
  });
  test('no AI key gives a truthful handoff option', () async {
    final response = await handler(
      post('public/chat/message', {'message': 'Please help'}),
    );
    final data = jsonDecode(await response.readAsString());
    expect(data['handoff'], true);
    expect(data['message'], contains('not available'));
  });
  test('handoff requires consent and validates payload types', () async {
    expect(
      (await handler(post('public/chat/handoff', {'messages': []}))).statusCode,
      400,
    );
    expect(
      (await handler(post('public/chat/message', {'message': 123}))).statusCode,
      400,
    );
    expect(
      (await handler(post('public/chat/message', {'message': 'x' * 1001})))
          .statusCode,
      400,
    );
  });
  test(
    'handoff persists hash, enforces ownership, and returns office reply',
    () async {
      final created = await handler(
        post('public/chat/handoff', {
          'consent': true,
          'personId': '123456',
          'messages': [
            {'role': 'user', 'text': 'Question'},
          ],
        }),
      );
      expect(created.statusCode, 201);
      expect(store.personId, '123456');
      final ticket = jsonDecode(await created.readAsString()) as Map;
      expect(store.hash, isNot(ticket['token']));
      expect(store.hash!.length, 64);
      final wrong = await handler(
        post('public/chat/status', {
          'ticketId': ticket['ticketId'],
          'token': 'a' * 43,
        }),
      );
      expect(wrong.statusCode, 404);
      final c = config();
      final admin = buildHandler(
        config: c,
        database: Database(c),
        supportStore: store,
        supportAuthorization: (_) async => 'authorized-user',
      );
      expect(
        (await admin(
          post('admin/support/${MemoryStore.id}/reply', {
            'reply': 'Please visit the office.',
          }),
        )).statusCode,
        200,
      );
      final read = await handler(
        post('public/chat/status', {
          'ticketId': ticket['ticketId'],
          'token': ticket['token'],
        }),
      );
      expect(read.statusCode, 200);
      expect(read.headers['cache-control'], 'no-store');
      expect(
        jsonDecode(await read.readAsString())['reply'],
        'Please visit the office.',
      );
    },
  );
  test('failed database write never claims successful handoff', () async {
    store.fail = true;
    final response = await handler(
      post('public/chat/handoff', {
        'consent': true,
        'personId': '123456',
        'messages': [
          {'role': 'user', 'text': 'Question'},
        ],
      }),
    );
    expect(response.statusCode, 503);
  });
  test('authorized admin can delete a support conversation', () async {
    final c = config();
    final admin = buildHandler(
      config: c,
      database: Database(c),
      supportStore: store,
      supportAuthorization: (_) async => 'authorized-user',
    );
    final response = await admin(
      post('admin/support/${MemoryStore.id}/delete', {
        'username': 'admin',
        'password': 'test-password',
      }),
    );
    expect(response.statusCode, 200);
    expect(store.deleted, true);
    expect(store.deletedUsername, 'admin');
  });

  test('support deletion requires confirmation credentials', () async {
    final c = config();
    final admin = buildHandler(
      config: c,
      database: Database(c),
      supportStore: store,
      supportAuthorization: (_) async => 'authorized-user',
    );
    final response = await admin(
      post('admin/support/${MemoryStore.id}/delete', {
        'username': '',
        'password': '',
      }),
    );
    expect(response.statusCode, 403);
    expect(store.deleted, false);
  });
  test('handoff accepts an exactly six-character faculty ID', () async {
    final response = await handler(
      post('public/chat/handoff', {
        'consent': true,
        'personId': 'AB1234',
        'messages': [
          {'role': 'user', 'text': 'Question'},
        ],
      }),
    );
    expect(response.statusCode, 201);
    expect(store.personId, 'AB1234');
  });
  test('handoff requires a valid ID that exists in the registry', () async {
    final invalid = await handler(
      post('public/chat/handoff', {
        'consent': true,
        'personId': 'bad',
        'messages': [
          {'role': 'user', 'text': 'Question'},
        ],
      }),
    );
    expect(invalid.statusCode, 400);
    final punctuation = await handler(
      post('public/chat/handoff', {
        'consent': true,
        'personId': 'AB-123',
        'messages': [
          {'role': 'user', 'text': 'Question'},
        ],
      }),
    );
    expect(punctuation.statusCode, 400);
    store.knownPerson = false;
    final missing = await handler(
      post('public/chat/handoff', {
        'consent': true,
        'personId': '123456',
        'messages': [
          {'role': 'user', 'text': 'Question'},
        ],
      }),
    );
    expect(missing.statusCode, 422);
  });
  test('anonymous AI rate limit is enforced', () async {
    for (var i = 0; i < 10; i++) {
      expect(
        (await handler(post('public/chat/message', {'message': 'Question'})))
            .statusCode,
        200,
      );
    }
    expect(
      (await handler(post('public/chat/message', {'message': 'Question'})))
          .statusCode,
      429,
    );
  });
  test('AI selects only a server-approved answer', () async {
    final ai = SupportAi(
      config(ai: true),
      client: MockClient((request) async {
        if (request.url.path.endsWith('moderations')) {
          return http.Response('{"results":[{"flagged":false}]}', 200);
        }
        final body = jsonDecode(request.body);
        expect(body['store'], false);
        expect(body.containsKey('tools'), false);
        return http.Response(
          jsonEncode({
            'status': 'completed',
            'output': [
              {
                'type': 'message',
                'content': [
                  {
                    'type': 'output_text',
                    'text': jsonEncode({
                      'action': 'answer',
                      'topic': 'sspr',
                      'inventedText': 'Untrusted content',
                    }),
                  },
                ],
              },
            ],
          }),
          200,
        );
      }),
    );
    expect(
      (await ai.answer('How do I reset my password?')).message,
      supportAnswers['sspr'],
    );
  });
  test('flagged content never reaches the answer model', () async {
    var calls = 0;
    final ai = SupportAi(
      config(ai: true),
      client: MockClient((request) async {
        calls++;
        return http.Response('{"results":[{"flagged":true}]}', 200);
      }),
    );
    final response = await ai.answer('Unsafe content');
    expect(response.message, refusedAnswer);
    expect(response.handoff, false);
    expect(calls, 1);
  });
  test('provider failures return a safe fallback', () async {
    final ai = SupportAi(
      config(ai: true),
      client: MockClient(
        (request) async => http.Response('private-provider-error', 500),
      ),
    );
    final response = await ai.answer('Question');
    expect(response.handoff, true);
    expect(response.message, isNot(contains('private-provider-error')));
  });
}
