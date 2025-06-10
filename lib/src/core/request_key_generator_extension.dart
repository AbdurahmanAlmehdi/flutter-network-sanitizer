import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';

extension RequestKeyGeneratorExtension on RequestOptions {
  static const allowedHeaders = ['authorization', 'accept-language'];
  String get generateRequestKey {
    final method = this.method.toUpperCase();
    final path = uri.toString();
    final queryParams = jsonEncode(Map.fromEntries(
        queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))));
    final headers = jsonEncode(Map.fromEntries(this.headers.entries.toList()
      ..where((element) => allowedHeaders.contains(element.key))
      ..sort((a, b) => a.key.compareTo(b.key))));
    final body = data != null ? jsonEncode(data) : '';
    final rawKey = '$method|$path|$queryParams|$headers|$body';
    final bytes = utf8.encode(rawKey);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
