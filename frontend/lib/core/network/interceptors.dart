import 'dart:async';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:qabas/core/network/api_exception.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/shared/data/dtos/error_envelope_dto.dart';

final class ContractHeadersInterceptor extends Interceptor {
  ContractHeadersInterceptor({required this.client, required this.language});
  final String client;
  final String Function() language;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll({'Qabas-Contract': '10', 'Qabas-Client': client, 'Accept-Language': language()});
    handler.next(options);
  }
}

final class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.tokens);
  final TokenStore tokens;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['noAuth'] != true) {
      final token = await tokens.read();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

final class IdempotencyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = options.extra['idempotencyKey'];
    if (key is String) options.headers['Idempotency-Key'] = key;
    handler.next(options);
  }
}

ApiException decodeApiError(DioException error) {
  final status = error.response?.statusCode;
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    try {
      final body = ErrorEnvelopeDto.fromJson(data).error;
      return ApiException(status: status, code: body.code, message: body.message, details: body.details);
    } catch (_) {
      /* Malformed envelopes retain their HTTP status mapping. */
    }
  }
  return ApiException(status: status, code: status == null ? 'network' : 'unknown', message: 'Request failed');
}

final class RetryInterceptor extends Interceptor {
  RetryInterceptor(this.dio, {Future<void> Function(Duration)? delay}) : delay = delay ?? Future<void>.delayed;
  final Dio dio;
  final Future<void> Function(Duration) delay;
  bool _safe(RequestOptions options) =>
      options.method == 'GET' ||
      (options.method == 'POST' &&
          (options.extra['idempotencyKey'] != null || RegExp(r'^/sessions(?:/[^/]+/(?:answers|finish))?$').hasMatch(options.path)));
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempts = options.extra['retryAttempt'] as int? ?? 0;
    final status = err.response?.statusCode;
    final transient =
        [
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
        ].contains(err.type) ||
        status == 429 ||
        status == 502 ||
        status == 503 ||
        status == 504;
    // At most three total attempts; never replay cancelled actions.
    if (!_safe(options) || !transient || attempts >= 2 || options.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }
    final backoff = Duration(milliseconds: [500, 1000, 2000][attempts]);
    final retryAfter = decodeApiError(err).retryAfter;
    await delay(retryAfter != null && retryAfter > backoff ? retryAfter : backoff);
    if (options.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }
    options.extra['retryAttempt'] = attempts + 1;
    if (options.data case final FormData form) {
      options.data = form.clone();
    }
    try {
      handler.resolve(await dio.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.reject(retryError);
    }
  }
}

final class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({required this.tokens, required this.publish, required this.contractObserved});
  final TokenStore tokens;
  final void Function(AuthEvent) publish;
  final void Function(String?) contractObserved;
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    contractObserved(response.headers.value('Qabas-Contract'));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    contractObserved(err.response?.headers.value('Qabas-Contract'));
    final exception = err.error is ApiException ? err.error! as ApiException : decodeApiError(err);
    if (err.requestOptions.extra['authNoticePublished'] != true) {
      if (exception.status == 401 && err.requestOptions.extra['noAuth'] != true) {
        await tokens.clear();
        publish(const AuthExpired());
      }
      if (exception.status == 403 && err.requestOptions.path.startsWith('/admin/')) publish(const ReviewerAccessForbidden());
      if (exception.status == 426) {
        publish(ClientOutdated(exception.details['min_app_version'] is String ? exception.details['min_app_version'] as String : null));
      }
      err.requestOptions.extra['authNoticePublished'] = true;
    }
    handler.next(err.copyWith(error: exception));
  }
}

final class RedactingLogInterceptor extends Interceptor {
  final Logger _log = Logger('http');
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['requestStarted'] = DateTime.now();
    handler.next(options);
  }

  void _record(RequestOptions options, int? status) {
    final started = options.extra['requestStarted'];
    final elapsed = started is DateTime ? DateTime.now().difference(started).inMilliseconds : 0;
    _log.fine('${options.method} ${options.uri.path} ${status ?? '-'} ${elapsed}ms');
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _record(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }
}
