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
    final ogHeaders = this.headers.entries.toList();
    final filteredHeaders = ogHeaders
        .where((element) => allowedHeaders.contains(element.key.toLowerCase()))
        .toList();
    final headers = jsonEncode(Map.fromEntries(
        filteredHeaders..sort((a, b) => a.key.compareTo(b.key))));
    final body = data != null ? jsonEncode(data) : '';
    final rawKey = '$method|$path|$queryParams|$headers|$body';
    final bytes = utf8.encode(rawKey);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
