import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../errors/api_error.dart';
import 'support_access.dart';
import 'support_ai.dart';
import 'support_store.dart';

class SupportRoutes {
  SupportRoutes({
    required this.store,
    required this.ai,
    required this.authorize,
  });
  final SupportStore store;
  final SupportAi ai;
  final SupportAccess authorize;
  final _limits = <String, (DateTime, int)>{};
  final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void register(Router router) {
    router.post('/api/v1/public/chat/message', (Request request) async {
      _limit(request, 'ai', 10);
      final payload = await _read(request);
      final message = _text(payload['message'], 1000);
      return _privateJson((await ai.answer(message)).toJson());
    });
    router.post('/api/v1/public/chat/handoff', (Request request) async {
      _limit(request, 'handoff', 3);
      final payload = await _read(request);
      if (payload['consent'] != true) {
        throw const ApiError(
          statusCode: 400,
          message: 'Consent is required to send a conversation.',
        );
      }
      final personId = _personId(payload['personId']);
      if (!await store.personExists(personId)) {
        throw const ApiError(
          statusCode: 422,
          message: 'This ID number was not found in the school database. Check the ID or contact the CISO Office.',
        );
      }
      final raw = payload['messages'];
      if (raw is! List || raw.isEmpty || raw.length > 20) {
        throw const ApiError(
          statusCode: 400,
          message: 'Send between 1 and 20 messages.',
        );
      }
      final messages = <Map<String, String>>[];
      for (final item in raw) {
        if (item is! Map ||
            !['user', 'assistant', 'notice', 'office'].contains(item['role'])) {
          throw const ApiError(
            statusCode: 400,
            message: 'Invalid conversation.',
          );
        }
        messages.add({
          'role': item['role'] as String,
          'text': _text(item['text'], 4000),
        });
      }
      if (!messages.any((m) => m['role'] == 'user')) {
        throw const ApiError(
          statusCode: 400,
          message: 'A question is required.',
        );
      }
      final random = Random.secure();
      final token = base64UrlEncode(
        List.generate(32, (_) => random.nextInt(256)),
      ).replaceAll('=', '');
      String id;
      try {
        id = await store.create(
          personId: personId,
          tokenHash: _hash(token),
          messages: messages,
        );
      } catch (_) {
        throw const ApiError(
          statusCode: 503,
          message:
              'Your conversation could not be sent. Please try again later.',
        );
      }
      return _privateJson({
        'success': true,
        'ticketId': id,
        'token': token,
      }, status: 201);
    });
    router.post('/api/v1/public/chat/status', (Request request) async {
      _limit(request, 'status', 30);
      final payload = await _read(request);
      final id = _text(payload['ticketId'], 36);
      final token = _text(payload['token'], 64);
      if (!_uuid.hasMatch(id) ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        throw ApiError.unauthorized;
      }
      final ticket = await store.status(id, _hash(token));
      if (ticket == null) {
        throw const ApiError(
          statusCode: 404,
          message: 'Conversation not found or expired.',
        );
      }
      return _privateJson({'success': true, ...ticket});
    });
    router.get('/api/v1/admin/support', (Request request) async {
      await authorize(request);
      return _privateJson({'success': true, 'tickets': await store.list()});
    });
    router.post('/api/v1/admin/support/<id>/reply', (
      Request request,
      String id,
    ) async {
      final userId = await authorize(request);
      if (!_uuid.hasMatch(id)) {
        throw const ApiError(statusCode: 400, message: 'Invalid ticket.');
      }
      final payload = await _read(request);
      final reply = _text(payload['reply'], 4000);
      if (!await store.reply(id, reply, userId)) {
        throw const ApiError(
          statusCode: 404,
          message: 'Conversation not found or expired.',
        );
      }
      return _privateJson({'success': true});
    });
    router.post('/api/v1/admin/support/<id>/delete', (
      Request request,
      String id,
    ) async {
      final userId = await authorize(request);
      if (!_uuid.hasMatch(id)) {
        throw const ApiError(statusCode: 400, message: 'Invalid ticket.');
      }
      final payload = await _read(request);
      final username = payload['username'];
      final password = payload['password'];
      if (username is! String ||
          password is! String ||
          username.trim().isEmpty ||
          username.length > 254 ||
          password.isEmpty ||
          utf8.encode(password).length > 72) {
        throw const ApiError(
          statusCode: 403,
          message: 'Enter your current username and password to confirm.',
        );
      }
      if (!await store.deleteConversation(
        id: id,
        userId: userId,
        username: username,
        password: password,
      )) {
        throw const ApiError(
          statusCode: 404,
          message: 'Conversation not found or already deleted.',
        );
      }
      return _privateJson({
        'success': true,
        'message': 'Support conversation permanently deleted.',
      });
    });
  }

  String _hash(String token) => sha256.convert(utf8.encode(token)).toString();
  String _personId(Object? value) {
    if (value is! String) {
      throw const ApiError(statusCode: 400, message: 'Enter your ID number.');
    }
    final id = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(id)) {
      throw const ApiError(
        statusCode: 400,
        message: 'Enter exactly 6 letters or numbers for the ID.',
      );
    }
    return id;
  }

  String _text(Object? value, int max) {
    if (value is! String || value.trim().isEmpty || value.length > max) {
      throw const ApiError(
        statusCode: 400,
        message: 'Invalid or oversized message.',
      );
    }
    return value.trim();
  }

  Response _privateJson(Map<String, Object?> data, {int status = 200}) =>
      Response(
        status,
        body: jsonEncode(data),
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'cache-control': 'no-store',
        },
      );
  Future<Map<String, dynamic>> _read(Request request) async {
    if (!(request.headers['content-type'] ?? '').toLowerCase().startsWith(
      'application/json',
    )) {
      throw const ApiError(statusCode: 415, message: 'JSON is required.');
    }
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      if (bytes.length + chunk.length > 100000) {
        throw const ApiError(statusCode: 413, message: 'Request is too large.');
      }
      bytes.addAll(chunk);
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      /* Return a safe validation error. */
    }
    throw const ApiError(statusCode: 400, message: 'Invalid JSON.');
  }

  void _limit(Request request, String bucket, int max) {
    final now = DateTime.now();
    _limits.removeWhere(
      (_, value) => now.difference(value.$1) >= const Duration(minutes: 1),
    );
    // Ignore client-supplied forwarding headers. Behind Nginx this is a
    // conservative shared limit; production needs a trusted edge rate limit.
    final connection =
        request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    final peer = connection?.remoteAddress.address ?? 'local';
    for (final (key, limit) in [
      ('$bucket:$peer', max),
      ('$bucket:global', max * 10),
    ]) {
      final count = _limits[key];
      if (_limits.length > 10000 || (count != null && count.$2 >= limit)) {
        throw const ApiError(
          statusCode: 429,
          message: 'Too many requests. Please wait a minute.',
        );
      }
      _limits[key] = (count?.$1 ?? now, (count?.$2 ?? 0) + 1);
    }
  }
}
