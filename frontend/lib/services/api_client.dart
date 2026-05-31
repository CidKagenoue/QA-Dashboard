import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Gedeelde HTTP-plumbing voor alle domein-API-services.
///
/// Bevat de basis-URL-resolutie, het opbouwen van request-headers en het
/// uitvoeren/decoderen van requests. Elke domein-service (auth, accounts, OVA,
/// notifications, …) hergebruikt deze helpers i.p.v. ze te dupliceren.
class ApiClient {
  static const String _configuredWebApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _productionApiBaseUrl = 'https://tst.vlotterqa.tech';

  static String get baseUrl {
    if (_configuredWebApiBaseUrl.isNotEmpty) {
      return _configuredWebApiBaseUrl;
    }

    if (kReleaseMode) {
      return _productionApiBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3001';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3001';
      default:
        return 'http://localhost:3001';
    }
  }

  static Map<String, String> headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Voert een request uit en geeft de JSON-body als map terug. Gooit een
  /// [Exception] met de servermelding bij een niet-2xx-status.
  static Future<Map<String, dynamic>> requestObject(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    final payload = _decodePayload(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (payload is Map<String, dynamic>) {
        return payload;
      }

      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }

      return <String, dynamic>{};
    }

    throw Exception(_extractMessage(payload, response.statusCode));
  }

  static dynamic _decodePayload(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _extractMessage(dynamic payload, int statusCode) {
    if (payload is Map) {
      final message = payload['message'];
      if (message is List) {
        return message.join(', ');
      }
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    if (payload is String && payload.isNotEmpty) {
      return payload;
    }

    return 'Request failed with status code $statusCode';
  }
}
