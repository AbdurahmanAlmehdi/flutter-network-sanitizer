import 'dart:async';

import 'package:dio/dio.dart';
import 'package:network_sanitizer/src/core/request_key_generator_extension.dart';

import 'core/cache_manager/cache_manager.dart';
import 'core/cache_manager/hive_cache_manager.dart';
import 'core/constants/sanitizer_constants.dart';

class NetworkSanitizerInterceptor extends Interceptor {
  final Duration _cacheDuration;
  late final SanitizerCacheManager _cacheManager;

  final _incomingRequests = <String, List<Completer<Response>>>{};

  NetworkSanitizerInterceptor(this._cacheDuration) {
    _cacheManager = HiveCacheManager();
  }

  NetworkSanitizerInterceptor.custom({
    required Duration cacheDuration,
    required SanitizerCacheManager cacheManager,
  })  : _cacheDuration = cacheDuration,
        _cacheManager = cacheManager;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final key = options.generateRequestKey;
    _checkForceRefresh(options, key);

    // Check for duplicate requests first (deduplication)
    if (_incomingRequests.containsKey(key)) {
      final completer = Completer<Response>();
      _incomingRequests[key]!.add(completer);
      completer.future.then(
        (response) => handler.resolve(response),
        onError: (e) => handler.reject(e as DioException),
      );
      return;
    }

    // Check cache validity
    try {
      final cached = await _cacheManager.getData(key, options);
      if (cached != null && !_isCacheExpired(cached)) {
        handler.resolve(cached);
        return;
      } else {
        _incomingRequests[key] = [Completer<Response>()];
        await _cacheManager.remove(key);
      }
    } catch (_) {}

    // Initialize the incoming requests list for this key
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final key = response.requestOptions.generateRequestKey;

    try {
      await _cacheManager.setData(key, response);
    } catch (_) {}

    final completers = _incomingRequests.remove(key);
    for (final completer in (completers ?? [])) {
      if (!completer.isCompleted) {
        completer.complete(response);
      }
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = err.requestOptions.generateRequestKey;

    final completers = _incomingRequests.remove(key);
    for (final completer in (completers ?? [])) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    }

    handler.next(err);
  }

  bool _isCacheExpired(Response response) {
    final timestampStr =
        response.extra[SanitizerConstants.cacheTimeStampKey] as String?;
    if (timestampStr == null) return true;

    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) return true;

    return DateTime.now().difference(timestamp) > _cacheDuration;
  }

  void _checkForceRefresh(RequestOptions options, String key) {
    final invalidate =
        options.extra[SanitizerConstants.invalidateCacheKey] == true;
    if (invalidate) {
      _cacheManager.remove(key);
    }
  }
}
