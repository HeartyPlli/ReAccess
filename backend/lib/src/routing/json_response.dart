import 'dart:convert';

import 'package:shelf/shelf.dart';

class JsonResponse {
  const JsonResponse._();

  static Response ok(Object data) {
    return _json(200, data);
  }

  static Response created(Object data) {
    return _json(201, data);
  }

  static Response unauthorized([String message = 'Unauthorized.']) {
    return _json(401, {'success': false, 'message': message});
  }

  static Response forbidden([String message = 'Forbidden.']) {
    return _json(403, {'success': false, 'message': message});
  }

  static Response badRequest([String message = 'Invalid request.']) {
    return _json(400, {'success': false, 'message': message});
  }

  static Response serverError() {
    return _json(500, {
      'success': false,
      'message': 'An unexpected error occurred.',
    });
  }

  static Response _json(int statusCode, Object body) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
