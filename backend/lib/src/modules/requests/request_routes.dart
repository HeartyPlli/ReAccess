import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:request_contract/request_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../errors/api_error.dart';
import '../../routing/json_response.dart';
import '../support/support_access.dart';
import 'request_store.dart';

class RequestRoutes {
  RequestRoutes({
    required this.store,
    required this.secret,
    required this.authorize,
  });
  final RequestStore store;
  final String secret;
  final SupportAccess authorize;
  final _attempts = <DateTime>[];
  final _clients = <String, List<DateTime>>{};

  void register(Router router) {
    router.get('/api/v1/public/request-settings', (Request request) async {
      final configuration = await _available(store.configuration);
      return JsonResponse.ok({
        'institutions': [
          for (final entry in configuration.institutions.entries)
            {'name': entry.key, 'programs': entry.value},
        ],
        'studentRequestLimit': configuration.studentRequestLimit,
      });
    });
    router.post('/api/v1/public/requests/verify', (Request request) async {
      _limit(request);
      final configuration = await _available(store.configuration);
      final data = _data(
        await _body(request),
        details: false,
        catalog: configuration.institutions,
      );
      final count = await _available(() => store.verify(data));
      if (secret.length < 32) {
        throw const ApiError(
          statusCode: 503,
          message: 'Request verification is not configured.',
        );
      }
      final nonce = base64UrlEncode(
        List.generate(32, (_) => Random.secure().nextInt(256)),
      );
      final token = JWT({
        'purpose': 'request-verification',
        'hash': requestHash(data.identityJson),
        'nonce': nonce,
      }).sign(SecretKey(secret), expiresIn: const Duration(minutes: 15));
      return JsonResponse.ok({
        'verificationToken': token,
        'previousRequests': count,
        'studentRequestLimit': data.personKind == PersonKind.student
            ? configuration.studentRequestLimit
            : 0,
        'requiresFormalLetter':
            data.personKind == PersonKind.student &&
            configuration.studentRequestLimit > 0 &&
            count >= configuration.studentRequestLimit,
      });
    });
    router.post('/api/v1/public/requests', (Request request) async {
      _limit(request);
      final body = await _body(request);
      final token = body.remove('verificationToken');
      final configuration = await _available(store.configuration);
      final data = _data(body, catalog: configuration.institutions);
      String nonce;
      try {
        if (secret.length < 32 || token is! String) {
          throw const FormatException();
        }
        final jwt = JWT.verify(token, SecretKey(secret));
        if (jwt.payload['purpose'] != 'request-verification' ||
            jwt.payload['hash'] != requestHash(data.identityJson) ||
            jwt.payload['nonce'] is! String) {
          throw const FormatException();
        }
        nonce = jwt.payload['nonce'] as String;
      } catch (_) {
        throw const ApiError(
          statusCode: 422,
          message: 'Verification expired or details changed. Go back and verify your information again.',
        );
      }
      final reference = await _available(() => store.submit(data, nonce));
      return JsonResponse.ok({'reference': reference});
    });
    router.get('/api/v1/admin/requests', (Request request) async {
      await authorize(request);
      final q = request.url.queryParameters;
      final kind = q['kind'] ?? '';
      final type = q['type'] ?? '';
      final page = int.tryParse(q['page'] ?? '0');
      if (page == null ||
          page < 0 ||
          page > 100000 ||
          (kind.isNotEmpty && !PersonKind.values.any((v) => v.code == kind)) ||
          (type.isNotEmpty && !RequestKind.values.any((v) => v.code == type))) {
        throw const ApiError(statusCode: 400, message: 'Invalid filters.');
      }
      return JsonResponse.ok({'requests': await store.list(kind, type, page)});
    });
  }

  // Bounded process-wide budget; deploy an additional per-client edge limit.
  void _limit(Request request) {
    final now = DateTime.now();
    _attempts.removeWhere((time) => now.difference(time).inMinutes >= 1);
    if (_attempts.length >= 60) {
      throw const ApiError(
        statusCode: 429,
        message: 'Too many requests. Please try again shortly.',
      );
    }
    _attempts.add(now);
    final peer = request.context['shelf.io.connection_info'];
    final key = peer is HttpConnectionInfo
        ? peer.remoteAddress.address
        : 'unknown';
    _clients.removeWhere(
      (_, times) => times.isEmpty || now.difference(times.last).inMinutes >= 1,
    );
    final times = _clients.putIfAbsent(key, () => []);
    times.removeWhere((time) => now.difference(time).inMinutes >= 1);
    if (times.length >= 10) {
      throw const ApiError(
        statusCode: 429,
        message: 'Too many attempts. Please wait a minute.',
      );
    }
    times.add(now);
  }

  Future<T> _available<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on ApiError {
      rethrow;
    } catch (_) {
      throw const ApiError(
        statusCode: 503,
        message: 'The request service is unavailable. Please try again later.',
      );
    }
  }

  RequestData _data(
    Map<String, dynamic> body, {
    bool details = true,
    required Map<String, List<String>> catalog,
  }) {
    try {
      final data = RequestData.fromJson(body);
      final errors = data.validate(details: details, instituteCatalog: catalog);
      if (errors.isNotEmpty) {
        throw ApiError(statusCode: 400, message: errors.values.first);
      }
      return data;
    } on FormatException {
      throw const ApiError(
        statusCode: 400,
        message: 'Invalid request information.',
      );
    }
  }

  Future<Map<String, dynamic>> _body(Request request) async {
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > 32768) {
        throw const ApiError(statusCode: 413, message: 'Request too large.');
      }
    }
    try {
      final body = jsonDecode(utf8.decode(bytes));
      if (body is! Map<String, dynamic>) throw const FormatException();
      return body;
    } on FormatException {
      throw const ApiError(
        statusCode: 400,
        message: 'Invalid request information.',
      );
    }
  }
}
