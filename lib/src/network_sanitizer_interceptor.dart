import 'dart:async';

import 'package:dio/dio.dart';
import 'package:network_sanitizer/src/core/request_key_generator_extension.dart';

import 'core/cache_manager/cache_manager.dart';
import 'core/cache_manager/hive_cache_manager.dart';
import 'core/constants/sanitizer_constants.dart';

/// A Dio interceptor that provides HTTP request caching and deduplication.
/// 
/// This interceptor automatically caches HTTP responses and prevents duplicate
/// simultaneous requests. It supports configurable cache duration and allows
/// for custom cache storage implementations.
/// 
/// ## Features
/// 
/// - **Request Caching**: Stores responses based on request parameters
/// - **Request Deduplication**: Prevents duplicate simultaneous requests  
/// - **Cache Invalidation**: Supports force refresh functionality
/// - **Configurable Duration**: Set custom cache expiration times
/// - **Custom Storage**: Use your own cache storage implementation
/// 
/// ## Usage
/// 
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(
///   NetworkSanitizerInterceptor(const Duration(minutes: 5)),
/// );
/// ```
/// 
/// ## Force Refresh
/// 
/// ```dart
/// final response = await dio.get(
///   '/api/users',
///   options: Options(extra: {'invalidateCache': true}),
/// );
/// ```
class NetworkSanitizerInterceptor extends Interceptor {
  final Duration _cacheDuration;
  late final SanitizerCacheManager _cacheManager;

  final _incomingRequests = <String, List<Completer<Response>>>{};

  /// Creates a NetworkSanitizerInterceptor with the specified cache duration.
  /// 
  /// Uses the default [HiveCacheManager] for storage.
  /// 
  /// [cacheDuration] - How long responses should be cached before expiring
  NetworkSanitizerInterceptor(this._cacheDuration) {
    _cacheManager = HiveCacheManager();
  }

  /// Creates a NetworkSanitizerInterceptor with a custom cache manager.
  /// 
  /// This constructor allows you to provide your own cache storage implementation.
  /// 
  /// [cacheDuration] - How long responses should be cached before expiring
  /// [cacheManager] - Custom cache storage implementation
  NetworkSanitizerInterceptor.custom({
    required Duration cacheDuration,
    required SanitizerCacheManager cacheManager,
  })  : _cacheDuration = cacheDuration,
        _cacheManager = cacheManager;

  /// Handles incoming requests by checking cache and deduplicating requests.
  /// 
  /// This method:
  /// 1. Checks for force refresh requests
  /// 2. Deduplicates simultaneous identical requests
  /// 3. Returns cached responses if valid
  /// 4. Removes expired cache entries
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

  /// Handles successful responses by caching them and resolving duplicate requests.
  /// 
  /// This method:
  /// 1. Stores the response in cache
  /// 2. Resolves all waiting duplicate requests with the same response
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

  /// Handles request errors by notifying all waiting duplicate requests.
  /// 
  /// This method ensures that all duplicate requests receive the same error
  /// when a network request fails.
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

  /// Checks if a cached response has expired based on the configured cache duration.
  /// 
  /// [response] - The cached response to check
  /// Returns true if the cache has expired, false otherwise
  bool _isCacheExpired(Response response) {
    final timestampStr =
        response.extra[SanitizerConstants.cacheTimeStampKey] as String?;
    if (timestampStr == null) return true;

    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) return true;

    return DateTime.now().difference(timestamp) > _cacheDuration;
  }

  /// Checks if a request should invalidate the cache and removes it if needed.
  /// 
  /// [options] - The request options to check
  /// [key] - The cache key for the request
  void _checkForceRefresh(RequestOptions options, String key) {
    final validateCache =
        options.extra[SanitizerConstants.validateCacheKey] == true;
    if (!validateCache) {
      _cacheManager.remove(key);
    }
  }
}
