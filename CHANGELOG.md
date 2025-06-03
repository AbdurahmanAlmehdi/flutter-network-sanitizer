# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-06-03

### Added
- 🎉 Initial release of Network Sanitizer
- ✅ HTTP request caching with configurable duration
- ✅ Automatic request deduplication to prevent duplicate simultaneous requests
- ✅ Force refresh functionality to invalidate cache on demand
- ✅ Cross-platform storage support using Hive
- ✅ Seamless Dio interceptor integration
- ✅ Customizable cache manager interface for custom storage implementations
- ✅ Smart cache key generation based on request parameters
- ✅ Zero-configuration setup with sensible defaults
- ✅ Support for all Flutter platforms (Android, iOS, Web, macOS, Windows, Linux)
- 📱 Complete example app demonstrating all features
- 📚 Comprehensive documentation and API reference

### Features
- **NetworkSanitizerInterceptor**: Main interceptor class with configurable cache duration
- **SanitizerCacheManager**: Abstract interface for custom cache implementations
- **HiveCacheManager**: Default Hive-based cache storage implementation
- **Request Key Generation**: Automatic generation of unique cache keys
- **Cache Invalidation**: Support for force refresh via request options
- **Request Deduplication**: Prevents duplicate network calls for identical requests

### Dependencies
- `dio: ^5.8.0+1` - HTTP client integration
- `hive: ^2.2.3` - Cross-platform storage
- `hive_flutter: ^1.1.0` - Flutter-specific Hive extensions
- `path_provider: ^2.1.4` - Platform-specific paths
