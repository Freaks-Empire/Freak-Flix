import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SyncService {
  final Future<String?> Function() getAccessToken;

  SyncService({required this.getAccessToken});

  // Base URL for Netlify Functions
  // In development (local): usually http://localhost:8888/.netlify/functions/sync
  // In production (web): /.netlify/functions/sync
  String get _endpoint {
    if (kReleaseMode) {
      return '/.netlify/functions/sync';
    }
    // Adjust this if you run netlify dev locally
    return 'http://localhost:8888/.netlify/functions/sync';
  }

  Future<void> pushData(Map<String, dynamic> data) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('SyncService: No auth token, skipping push.');
      return;
    }

    try {
      final uri = Uri.parse(_endpoint);
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (res.statusCode != 200) {
        debugPrint('SyncService push failed: ${res.statusCode} ${res.body}');
      } else {
        debugPrint('SyncService push success.');
      }
    } catch (e) {
      debugPrint('SyncService push error: $e');
    }
  }

  Future<Map<String, dynamic>?> pullData() async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('SyncService: No auth token, skipping pull.');
      return null;
    }

    try {
      final uri = Uri.parse(_endpoint);
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body.isNotEmpty) {
           debugPrint('SyncService pull success.');
           return body;
        }
      } else {
        debugPrint('SyncService pull failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('SyncService pull error: $e');
    }
    return null;
  }
}
