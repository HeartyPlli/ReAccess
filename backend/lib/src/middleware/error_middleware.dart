import 'dart:io';

import 'package:shelf/shelf.dart';

import '../errors/api_error.dart';
import '../routing/json_response.dart';

Middleware safeErrorMiddleware() {
  return (innerHandler) {
    return (request) async {
      try {
        return await innerHandler(request);
      } on ApiError catch (error) {
        return Response(
          error.statusCode,
          body: '{"success":false,"message":"${error.message}"}',
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      } catch (error, stackTrace) {
        stderr.writeln('Unhandled API error: $error');
        stderr.writeln(stackTrace);
        return JsonResponse.serverError();
      }
    };
  };
}
