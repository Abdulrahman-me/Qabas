import 'dart:async';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/network/api_exception.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/network/interceptors.dart';
import 'package:qabas/core/network/multipart_request.dart';
import 'package:qabas/core/network/routing_adapter.dart';
import 'package:qabas/core/storage/token_store.dart';

typedef JsonDecoder<T> = T Function(Map<String, dynamic> json);

final class ApiClient {
  ApiClient._(this._dio, this._recording);
  factory ApiClient.create({
    required AppConfig config,
    required TokenStore tokens,
    required String platform,
    required String Function() language,
    BackendTransport? mock,
    bool debug = false,
    Future<void> Function(Duration)? retryDelay,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
      ),
    );
    final client = ApiClient._(dio, config.recordingDemo);
    dio.httpClientAdapter = RoutingAdapter(config: config, live: dio.httpClientAdapter, mock: mock);
    dio.interceptors.addAll([
      ContractHeadersInterceptor(client: '$platform/${config.appVersion}', language: language),
      AuthInterceptor(tokens),
      IdempotencyInterceptor(),
      RetryInterceptor(dio, delay: retryDelay),
      ErrorInterceptor(tokens: tokens, publish: client._authEvents.add, contractObserved: client._observe),
      if (debug) RedactingLogInterceptor(),
    ]);
    return client;
  }
  final Dio _dio;
  final bool _recording;
  final _authEvents = StreamController<AuthEvent>.broadcast();
  Stream<AuthEvent> get authEvents => _authEvents.stream;
  String? serverContract;
  void _observe(String? revision) {
    if (revision == null || serverContract != null) return;
    serverContract = revision;
    Logger('http').fine('Server contract revision: $revision');
  }

  Future<T> _call<T>(Future<Response<Object?>> Function() request, JsonDecoder<T> decode, {void Function(int status)? onStatus}) async {
    try {
      final response = await request();
      onStatus?.call(response.statusCode ?? 200);
      final json = response.data;
      if (json is! Map<String, dynamic>) throw const FormatException('Expected an object response');
      return decode(json);
    } on DioException catch (error) {
      throw error.error is ApiException ? error.error! as ApiException : decodeApiError(error);
    }
  }

  Options _options(String method, String path, {String? key, bool noAuth = false}) => Options(
    method: method,
    extra: {
      'noAuth': noAuth || (method == 'POST' && ['/auth/guest', '/auth/reviewer'].contains(path)),
      'idempotencyKey': ?key,
    },
  );
  Future<T> get<T>(String path, {Map<String, Object?>? query, required JsonDecoder<T> decode}) =>
      _call(() => _dio.get<Object?>(path, queryParameters: query, options: _options('GET', path)), decode);
  Future<T?> getNullable<T>(String path, {required JsonDecoder<T> decode}) async {
    try {
      final response = await _dio.get<Object?>(path, options: _options('GET', path));
      if (response.statusCode == 204) return null;
      if (response.data is! Map<String, dynamic>) throw const FormatException('Expected an object response');
      return decode(response.data! as Map<String, dynamic>);
    } on DioException catch (error) {
      throw error.error is ApiException ? error.error! as ApiException : decodeApiError(error);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    required JsonDecoder<T> decode,
    String? idempotencyKey,
    void Function(int status)? onStatus,
  }) => _call(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: _options('POST', path, key: idempotencyKey),
    ),
    decode,
    onStatus: onStatus,
  );
  Future<T> patch<T>(String path, {required Object body, required JsonDecoder<T> decode}) =>
      _call(() => _dio.patch<Object?>(path, data: body, options: _options('PATCH', path)), decode);
  Future<void> _noContent(Future<Response<Object?>> Function() request) async {
    try {
      await request();
    } on DioException catch (error) {
      throw decodeApiError(error);
    }
  }

  Future<void> postNoContent(String path, {Object? body, String? idempotencyKey}) => _noContent(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: _options('POST', path, key: idempotencyKey),
    ),
  );
  Future<void> delete(String path) => _noContent(() => _dio.delete<Object?>(path, options: _options('DELETE', path)));
  Future<T> postMultipart<T>(
    String path, {
    required MultipartRequest form,
    required JsonDecoder<T> decode,
    required String idempotencyKey,
    void Function(int, int)? onProgress,
  }) => _call(
    () => _dio.post<Object?>(
      path,
      data: form.toFormData(),
      onSendProgress: onProgress,
      options: _options('POST', path, key: idempotencyKey).copyWith(
        contentType: Headers.multipartFormDataContentType,
        sendTimeout: const Duration(seconds: 60),
        extra: {'idempotencyKey': idempotencyKey, 'mockMultipartBody': _recording ? form.recordingMockBody : form.mockBody},
      ),
    ),
    decode,
  );
  Future<void> dispose() async {
    _dio.close(force: true);
    await _authEvents.close();
  }
}
