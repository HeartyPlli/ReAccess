import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'auth_token_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(authTokenStoreProvider));
});

class ApiClient {
  ApiClient(this._tokenStore)
    : dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.requestTimeout,
          receiveTimeout: AppConfig.requestTimeout,
          sendTimeout: AppConfig.requestTimeout,
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokenStore.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  final AuthTokenStore _tokenStore;
  final Dio dio;

  Future<Response<T>> get<T>(String path) => _safeCall(() => dio.get<T>(path));

  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _safeCall(() => dio.post<T>(path, data: data));
  }

  Future<Response<T>> _safeCall<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) {
        _tokenStore.clear();
      }
      throw AppException(_messageFor(error), statusCode: status);
    }
  }

  String _messageFor(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return 'The request timed out. Please try again.';
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        if (data is Map && data['message'] is String) {
          return data['message'] as String;
        }
        return 'The server could not process the request.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return 'Unable to connect to the server.';
    }
  }
}
