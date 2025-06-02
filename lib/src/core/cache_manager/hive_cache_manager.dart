import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:network_sanitizer/src/core/constants/sanitizer_constants.dart';

import '../models/hive_cached_response.dart';
import 'cache_manager.dart';

class HiveCacheManager implements SanitizerCacheManager {
  late final Box<HiveCachedResponse> _box;
  bool _isInitialized = false;

  HiveCacheManager() {
    _initHive();
  }

  Future<void> _initHive() async {
    if (!_isInitialized) {
      await Hive.initFlutter();
      Hive.registerAdapter(HiveCachedResponseAdapter());
      _box = await Hive.openBox<HiveCachedResponse>(
          SanitizerConstants.hiveBoxName);
      _isInitialized = true;
    }
  }

  @override
  Future<Response?> getData(String key, RequestOptions options) async {
    await _ensureInitialized();
    final cachedResponse = _box.get(key);
    if (cachedResponse != null) {
      return cachedResponse.toResponse(options);
    }
    return null;
  }

  @override
  Future<void> setData(String key, Response response) async {
    await _ensureInitialized();
    final cachedResponse = HiveCachedResponse.fromResponse(
      key: key,
      response: response,
    );
    await _box.put(key, cachedResponse);
  }

  @override
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _box.clear();
  }

  @override
  Future<void> remove(String key) async {
    await _ensureInitialized();
    await _box.delete(key);
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initHive();
    }
  }
}
