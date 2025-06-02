import 'package:dio/dio.dart';

abstract class SanitizerCacheManager {
  Future<void> setData(String key, Response response);
  Future<Response?> getData(String key, RequestOptions options);
  Future<void> clearAll();
  Future<void> remove(String key);
}
