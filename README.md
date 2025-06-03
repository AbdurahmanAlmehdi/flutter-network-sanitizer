# Network Sanitizer

[![pub package](https://img.shields.io/pub/v/network_sanitizer.svg)](https://pub.dev/packages/network_sanitizer)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A powerful HTTP caching and request deduplication library for Flutter/Dart applications using Dio interceptor. Network Sanitizer provides efficient network request optimization with configurable caching, automatic request deduplication, and cross-platform storage support.

## Features

✅ **HTTP Request Caching** - Cache network responses with configurable duration  
✅ **Request Deduplication** - Automatically prevents duplicate simultaneous requests  
✅ **Force Refresh** - Invalidate cache on demand for fresh data  
✅ **Cross-Platform Storage** - Uses Hive for reliable storage across all platforms  
✅ **Dio Integration** - Seamless integration as a Dio interceptor  
✅ **Customizable Cache Manager** - Implement your own cache storage if needed  
✅ **Smart Key Generation** - Generates unique keys based on request parameters  
✅ **Zero Configuration** - Works out of the box with sensible defaults

## Installation

Add `network_sanitizer` to your `pubspec.yaml`:

```yaml
dependencies:
  network_sanitizer: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:dio/dio.dart';
import 'package:network_sanitizer/network_sanitizer.dart';

void main() {
  final dio = Dio();
  
  // Add the NetworkSanitizerInterceptor with 5-minute cache duration
  dio.interceptors.add(
    NetworkSanitizerInterceptor(const Duration(minutes: 5)),
  );
  
  // Your requests are now cached and deduplicated automatically!
  final response = await dio.get('/api/users');
}
```

## Usage Examples

### Basic Configuration

```dart
final dio = Dio();

// Cache responses for 2 minutes
dio.interceptors.add(
  NetworkSanitizerInterceptor(const Duration(minutes: 2)),
);
```

### Custom Cache Manager

```dart
// Implement your own cache storage
class CustomCacheManager implements SanitizerCacheManager {
  @override
  Future<void> setData(String key, Response response) async {
    // Your custom storage implementation
  }
  
  @override
  Future<Response?> getData(String key, RequestOptions options) async {
    // Your custom retrieval implementation
    return null;
  }
  
  @override
  Future<void> clearAll() async {
    // Clear all cached data
  }
  
  @override
  Future<void> remove(String key) async {
    // Remove specific cached data
  }
}

// Use your custom cache manager
dio.interceptors.add(
  NetworkSanitizerInterceptor.custom(
    cacheDuration: const Duration(minutes: 5),
    cacheManager: CustomCacheManager(),
  ),
);
```

### Force Refresh

```dart
// Force refresh by invalidating cache for a specific request
final response = await dio.get(
  '/api/users',
  options: Options(
    extra: {'invalidateCache': true},
  ),
);
```

### Request Deduplication

```dart
// Multiple simultaneous identical requests will be deduplicated automatically
final futures = List.generate(10, (index) => dio.get('/api/users'));
final responses = await Future.wait(futures);
// Only one actual network request is made, others receive the same response
```

## How It Works

### Caching
- Responses are cached based on request parameters (URL, headers, body, query parameters)
- Cache keys are generated using a combination of HTTP method, URL, headers, and request body
- Cached responses include timestamps for expiration checking
- Expired cache entries are automatically removed

### Deduplication
- Identical requests made simultaneously are deduplicated
- Only the first request triggers a network call
- Subsequent identical requests wait for the first request to complete
- All requests receive the same response when the network call completes

### Cache Invalidation
- Set `invalidateCache: true` in request options to force refresh
- Cache entries automatically expire based on the configured duration
- Manual cache clearing is supported through the cache manager

## API Reference

### NetworkSanitizerInterceptor

#### Constructors

```dart
NetworkSanitizerInterceptor(Duration cacheDuration)
```
Creates an interceptor with the specified cache duration using the default Hive cache manager.

```dart
NetworkSanitizerInterceptor.custom({
  required Duration cacheDuration,
  required SanitizerCacheManager cacheManager,
})
```
Creates an interceptor with a custom cache manager implementation.

#### Parameters

- `cacheDuration`: How long responses should be cached
- `cacheManager`: Custom cache storage implementation (optional)

### SanitizerCacheManager

Abstract class for implementing custom cache storage:

```dart
abstract class SanitizerCacheManager {
  Future<void> setData(String key, Response response);
  Future<Response?> getData(String key, RequestOptions options);
  Future<void> clearAll();
  Future<void> remove(String key);
}
```

### Request Options

Use these extra parameters in your Dio requests:

- `invalidateCache`: Set to `true` to force refresh and bypass cache

```dart
dio.get('/api/data', options: Options(extra: {'invalidateCache': true}))
```

## Platform Support

| Platform | Status |
|----------|--------|
| Android  | ✅     |
| iOS      | ✅     |
| Web      | ✅     |

## Performance Benefits

- **Reduced Network Calls**: Identical requests are cached and deduplicated
- **Faster Response Times**: Cached responses are served instantly
- **Lower Bandwidth Usage**: Fewer network requests mean less data consumption
- **Improved User Experience**: Faster loading times and better offline support
- **Server Load Reduction**: Fewer requests to your backend services

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you find this package helpful, please consider:

- ⭐ Starring the repository
- 🐛 Reporting bugs and issues
- 💡 Suggesting new features
- 📝 Contributing to the documentation

For questions and support, please [open an issue](https://github.com/aelkholy9/flutter-network-sanitizer/issues) on GitHub.
