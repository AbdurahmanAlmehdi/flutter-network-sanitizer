import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_sanitizer/network_sanitizer.dart';
import 'package:network_sanitizer/src/core/constants/sanitizer_constants.dart';
import 'package:network_sanitizer/src/core/models/hive_cached_response.dart';
import 'package:network_sanitizer/src/core/request_key_generator_extension.dart';

void main() {
  group('NetworkSanitizerInterceptor', () {
    late NetworkSanitizerInterceptor interceptor;
    late MockCacheManager mockCacheManager;

    setUp(() {
      mockCacheManager = MockCacheManager();
      interceptor = NetworkSanitizerInterceptor.custom(
        cacheDuration: const Duration(minutes: 5),
        cacheManager: mockCacheManager,
      );
    });

    test('should create interceptor with custom cache manager', () {
      final customInterceptor = NetworkSanitizerInterceptor.custom(
        cacheDuration: const Duration(minutes: 1),
        cacheManager: mockCacheManager,
      );
      expect(customInterceptor, isA<NetworkSanitizerInterceptor>());
    });

    group('onRequest', () {
      test('should handle cache hit with valid cache', () async {
        final options = RequestOptions(path: '/api/users');
        final cachedResponse = Response(
          requestOptions: options,
          data: {'cached': 'data'},
          statusCode: 200,
          extra: {
            SanitizerConstants.cacheTimeStampKey:
                DateTime.now().toIso8601String(),
          },
        );

        mockCacheManager.setTestData(
          options.generateRequestKey,
          cachedResponse,
        );

        final handler = MockRequestHandler();
        interceptor.onRequest(options, handler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(handler.resolvedResponse, isNotNull);
        expect(handler.resolvedResponse!.data, equals({'cached': 'data'}));
      });

      test('should handle cache miss', () async {
        final options = RequestOptions(path: '/api/users');
        final handler = MockRequestHandler();

        interceptor.onRequest(options, handler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(handler.nextCalled, isTrue);
        expect(handler.resolvedResponse, isNull);
      });

      test('should handle expired cache', () async {
        final options = RequestOptions(path: '/api/users');
        final expiredResponse = Response(
          requestOptions: options,
          data: {'expired': 'data'},
          statusCode: 200,
          extra: {
            SanitizerConstants.cacheTimeStampKey:
                DateTime.now()
                    .subtract(const Duration(hours: 1))
                    .toIso8601String(),
          },
        );

        mockCacheManager.setTestData(
          options.generateRequestKey,
          expiredResponse,
        );

        final handler = MockRequestHandler();
        interceptor.onRequest(options, handler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(handler.nextCalled, isTrue);
        expect(mockCacheManager.removedKeys.contains(options.generateRequestKey),
            isTrue);
      });

      test('should handle force refresh', () async {
        final options = RequestOptions(
          path: '/api/users',
          extra: {SanitizerConstants.invalidateCacheKey: true},
        );

        mockCacheManager.setTestData(
          options.generateRequestKey,
          Response(
            requestOptions: options,
            data: {'old': 'data'},
            statusCode: 200,
          ),
        );

        final handler = MockRequestHandler();
        interceptor.onRequest(options, handler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(mockCacheManager.removedKeys.contains(options.generateRequestKey),
            isTrue);
        expect(handler.nextCalled, isTrue);
      });

      test('should deduplicate simultaneous requests', () async {
        final options1 = RequestOptions(path: '/api/users');
        final options2 = RequestOptions(path: '/api/users');

        final handler1 = MockRequestHandler();
        final handler2 = MockRequestHandler();

        // First request should proceed normally
        interceptor.onRequest(options1, handler1);
        
        // Wait a bit then make second request
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Second identical request should wait
        interceptor.onRequest(options2, handler2);
        
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(handler1.nextCalled, isTrue);
        expect(handler2.nextCalled, isFalse);
        expect(handler2.resolvedResponse, isNull);
      });

      test('should handle cache manager exceptions gracefully', () async {
        final options = RequestOptions(path: '/api/users');
        mockCacheManager.shouldThrowOnGetData = true;

        final handler = MockRequestHandler();
        interceptor.onRequest(options, handler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(handler.nextCalled, isTrue);
        expect(handler.resolvedResponse, isNull);
      });

      test('should handle cache with missing timestamp', () async {
        final options = RequestOptions(path: '/api/users');
        final responseWithoutTimestamp = Response(
          requestOptions: options,
          data: {'test': 'data'},
          statusCode: 200,
          extra: {}, // No timestamp
        );

        mockCacheManager.setTestData(
          options.generateRequestKey,
          responseWithoutTimestamp,
        );

        final handler = MockRequestHandler();
        interceptor.onRequest(options, handler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(handler.nextCalled, isTrue);
        expect(mockCacheManager.removedKeys.contains(options.generateRequestKey),
            isTrue);
      });

      test('should handle cache with invalid timestamp', () async {
        final options = RequestOptions(path: '/api/users');
        final responseWithInvalidTimestamp = Response(
          requestOptions: options,
          data: {'test': 'data'},
          statusCode: 200,
          extra: {
            SanitizerConstants.cacheTimeStampKey: 'invalid-timestamp',
          },
        );

        mockCacheManager.setTestData(
          options.generateRequestKey,
          responseWithInvalidTimestamp,
        );

        final handler = MockRequestHandler();
        interceptor.onRequest(options, handler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(handler.nextCalled, isTrue);
        expect(mockCacheManager.removedKeys.contains(options.generateRequestKey),
            isTrue);
      });
    });

    group('onResponse', () {
      test('should cache response and resolve duplicate requests', () async {
        final options = RequestOptions(path: '/api/users');
        final response = Response(
          requestOptions: options,
          data: {'response': 'data'},
          statusCode: 200,
        );

        // Simulate pending requests
        final handler1 = MockRequestHandler();
        final handler2 = MockRequestHandler();

        // Set up duplicate requests
        interceptor.onRequest(options, handler1);
        await Future.delayed(const Duration(milliseconds: 10));
        interceptor.onRequest(options, handler2);
        await Future.delayed(const Duration(milliseconds: 10));

        final responseHandler = MockResponseHandler();
        interceptor.onResponse(response, responseHandler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(responseHandler.nextCalled, isTrue);
        expect(mockCacheManager.cachedData.containsKey(options.generateRequestKey),
            isTrue);
      });

      test('should handle cache manager exceptions during caching', () async {
        final options = RequestOptions(path: '/api/users');
        final response = Response(
          requestOptions: options,
          data: {'response': 'data'},
          statusCode: 200,
        );

        mockCacheManager.shouldThrowOnSetData = true;

        final responseHandler = MockResponseHandler();
        interceptor.onResponse(response, responseHandler);

        // Wait a bit for async operations to complete
        await Future.delayed(const Duration(milliseconds: 10));

        expect(responseHandler.nextCalled, isTrue);
      });
    });

    group('onError', () {
      test('should handle error properly', () {
        final options = RequestOptions(path: '/api/users');
        final error = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final errorHandler = MockErrorHandler();
        interceptor.onError(error, errorHandler);

        expect(errorHandler.nextCalled, isTrue);
      });
    });
  });

  group('Request Key Generation', () {
    test('should generate unique keys for different paths', () {
      final options1 = RequestOptions(path: '/api/users');
      final options2 = RequestOptions(path: '/api/posts');

      final key1 = options1.generateRequestKey;
      final key2 = options2.generateRequestKey;

      expect(key1, isNot(equals(key2)));
    });

    test('should generate same key for identical requests', () {
      final options1 = RequestOptions(
        path: '/api/users',
        method: 'GET',
        queryParameters: {'page': 1},
      );
      final options2 = RequestOptions(
        path: '/api/users',
        method: 'GET',
        queryParameters: {'page': 1},
      );

      final key1 = options1.generateRequestKey;
      final key2 = options2.generateRequestKey;

      expect(key1, equals(key2));
    });

    test('should include all request components in key', () {
      final options = RequestOptions(
        path: '/api/users',
        method: 'POST',
        queryParameters: {'page': 1, 'limit': 10},
        headers: {'Authorization': 'Bearer token'},
        data: {'name': 'John'},
      );

      final key = options.generateRequestKey;

      expect(key, contains('POST'));
      expect(key, contains('/api/users'));
    });

    test('should handle null query parameters', () {
      final options = RequestOptions(
        path: '/api/users',
        queryParameters: null,
      );

      final key = options.generateRequestKey;
      expect(key, isNotEmpty);
    });

    test('should handle null headers', () {
      final options = RequestOptions(
        path: '/api/users',
        headers: null,
      );

      final key = options.generateRequestKey;
      expect(key, isNotEmpty);
    });

    test('should handle null data', () {
      final options = RequestOptions(
        path: '/api/users',
        data: null,
      );

      final key = options.generateRequestKey;
      expect(key, isNotEmpty);
    });

    test('should handle different methods for same path', () {
      final options1 = RequestOptions(path: '/api/users', method: 'GET');
      final options2 = RequestOptions(path: '/api/users', method: 'POST');

      final key1 = options1.generateRequestKey;
      final key2 = options2.generateRequestKey;

      expect(key1, isNot(equals(key2)));
    });

    test('should handle different query parameters', () {
      final options1 = RequestOptions(
        path: '/api/users',
        queryParameters: {'page': 1},
      );
      final options2 = RequestOptions(
        path: '/api/users',
        queryParameters: {'page': 2},
      );

      final key1 = options1.generateRequestKey;
      final key2 = options2.generateRequestKey;

      expect(key1, isNot(equals(key2)));
    });

    test('should handle different headers', () {
      final options1 = RequestOptions(
        path: '/api/users',
        headers: {'Authorization': 'Bearer token1'},
      );
      final options2 = RequestOptions(
        path: '/api/users',
        headers: {'Authorization': 'Bearer token2'},
      );

      final key1 = options1.generateRequestKey;
      final key2 = options2.generateRequestKey;

      expect(key1, isNot(equals(key2)));
    });

    test('should handle different request data', () {
      final options1 = RequestOptions(
        path: '/api/users',
        data: {'name': 'John'},
      );
      final options2 = RequestOptions(
        path: '/api/users',
        data: {'name': 'Jane'},
      );

      final key1 = options1.generateRequestKey;
      final key2 = options2.generateRequestKey;

      expect(key1, isNot(equals(key2)));
    });
  });

  group('HiveCachedResponse', () {
    test('should create from response correctly', () {
      final requestOptions = RequestOptions(path: '/test');
      final response = Response(
        requestOptions: requestOptions,
        data: {'test': 'data'},
        statusCode: 200,
        headers: Headers.fromMap({'content-type': ['application/json']}),
      );

      final cached = HiveCachedResponse.fromResponse(
        key: 'test-key',
        response: response,
      );

      expect(cached.key, equals('test-key'));
      expect(cached.statusCode, equals(200));
      expect(cached.data, equals(jsonEncode({'test': 'data'})));
      expect(cached.timestamp, isA<DateTime>());
    });

    test('should convert to response correctly', () {
      final requestOptions = RequestOptions(path: '/test');
      final cached = HiveCachedResponse(
        key: 'test-key',
        statusCode: 200,
        data: jsonEncode({'test': 'data'}),
        headersJson: jsonEncode({
          'content-type': ['application/json']
        }),
        timestamp: DateTime.now(),
      );

      final response = cached.toResponse(requestOptions);

      expect(response.statusCode, equals(200));
      expect(response.data, equals({'test': 'data'}));
      expect(response.headers.map['content-type'], equals(['application/json']));
      expect(response.extra[SanitizerConstants.cacheTimeStampKey], isNotNull);
    });

    test('should handle null status code in response', () {
      final requestOptions = RequestOptions(path: '/test');
      final response = Response(
        requestOptions: requestOptions,
        data: {'test': 'data'},
        statusCode: null, // Null status code
        headers: Headers.fromMap({'content-type': ['application/json']}),
      );

      final cached = HiveCachedResponse.fromResponse(
        key: 'test-key',
        response: response,
      );

      expect(cached.statusCode, equals(200)); // Should default to 200
    });

    test('should handle complex data structures', () {
      final requestOptions = RequestOptions(path: '/test');
      final complexData = {
        'users': [
          {'id': 1, 'name': 'John'},
          {'id': 2, 'name': 'Jane'},
        ],
        'meta': {'total': 2, 'page': 1}
      };

      final response = Response(
        requestOptions: requestOptions,
        data: complexData,
        statusCode: 201,
        headers: Headers.fromMap({
          'content-type': ['application/json'],
          'x-total-count': ['2']
        }),
      );

      final cached = HiveCachedResponse.fromResponse(
        key: 'complex-key',
        response: response,
      );

      final reconstructed = cached.toResponse(requestOptions);

      expect(reconstructed.statusCode, equals(201));
      expect(reconstructed.data, equals(complexData));
      expect(reconstructed.headers.map['content-type'], equals(['application/json']));
      expect(reconstructed.headers.map['x-total-count'], equals(['2']));
    });
  });

  group('SanitizerConstants', () {
    test('should have correct constant values', () {
      expect(SanitizerConstants.cacheTimeStampKey, equals("cache_timestamp"));
      expect(SanitizerConstants.invalidateCacheKey, equals("invalidateCache"));
      expect(SanitizerConstants.hiveBoxName, equals("sanitizer_hive_box"));
    });
  });

  group('MockCacheManager', () {
    late MockCacheManager cacheManager;

    setUp(() {
      cacheManager = MockCacheManager();
    });

    test('should store and retrieve data', () async {
      final response = Response(
        requestOptions: RequestOptions(path: '/test'),
        data: {'test': 'data'},
        statusCode: 200,
      );

      await cacheManager.setData('test_key', response);
      final retrieved =
          await cacheManager.getData('test_key', RequestOptions(path: '/test'));

      expect(retrieved, isNotNull);
      expect(retrieved!.data, equals({'test': 'data'}));
    });

    test('should remove specific data', () async {
      final response = Response(
        requestOptions: RequestOptions(path: '/test'),
        data: {'test': 'data'},
        statusCode: 200,
      );

      await cacheManager.setData('test_key', response);
      await cacheManager.remove('test_key');
      final retrieved =
          await cacheManager.getData('test_key', RequestOptions(path: '/test'));

      expect(retrieved, isNull);
    });

    test('should clear all data', () async {
      final response1 = Response(
        requestOptions: RequestOptions(path: '/test1'),
        data: {'test': 'data1'},
        statusCode: 200,
      );
      final response2 = Response(
        requestOptions: RequestOptions(path: '/test2'),
        data: {'test': 'data2'},
        statusCode: 200,
      );

      await cacheManager.setData('key1', response1);
      await cacheManager.setData('key2', response2);
      await cacheManager.clearAll();

      final retrieved1 =
          await cacheManager.getData('key1', RequestOptions(path: '/test1'));
      final retrieved2 =
          await cacheManager.getData('key2', RequestOptions(path: '/test2'));

      expect(retrieved1, isNull);
      expect(retrieved2, isNull);
    });

    test('should handle exceptions in getData', () async {
      cacheManager.shouldThrowOnGetData = true;

      expect(
        () => cacheManager.getData('key', RequestOptions(path: '/test')),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle exceptions in setData', () async {
      cacheManager.shouldThrowOnSetData = true;
      final response = Response(
        requestOptions: RequestOptions(path: '/test'),
        data: {'test': 'data'},
        statusCode: 200,
      );

      expect(
        () => cacheManager.setData('key', response),
        throwsA(isA<Exception>()),
      );
    });
  });
}

/// Mock cache manager for testing
class MockCacheManager implements SanitizerCacheManager {
  final Map<String, Response> cachedData = {};
  final Set<String> removedKeys = <String>{};
  bool shouldThrowOnGetData = false;
  bool shouldThrowOnSetData = false;

  void setTestData(String key, Response response) {
    cachedData[key] = response;
  }

  @override
  Future<void> setData(String key, Response response) async {
    if (shouldThrowOnSetData) {
      throw Exception('Test exception in setData');
    }
    cachedData[key] = response;
  }

  @override
  Future<Response?> getData(String key, RequestOptions options) async {
    if (shouldThrowOnGetData) {
      throw Exception('Test exception in getData');
    }
    return cachedData[key];
  }

  @override
  Future<void> clearAll() async {
    cachedData.clear();
    removedKeys.clear();
  }

  @override
  Future<void> remove(String key) async {
    cachedData.remove(key);
    removedKeys.add(key);
  }
}

/// Mock request handler for testing
class MockRequestHandler extends RequestInterceptorHandler {
  Response? resolvedResponse;
  DioException? rejectedError;
  bool nextCalled = false;

  @override
  void resolve(Response response, [bool callFollowingResponseInterceptor = false]) {
    resolvedResponse = response;
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    rejectedError = error;
  }

  @override
  void next(RequestOptions requestOptions) {
    nextCalled = true;
  }
}

/// Mock response handler for testing
class MockResponseHandler extends ResponseInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(Response response) {
    nextCalled = true;
  }
}

/// Mock error handler for testing
class MockErrorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(DioException err) {
    nextCalled = true;
  }
}
