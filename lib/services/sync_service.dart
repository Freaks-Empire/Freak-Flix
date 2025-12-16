import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

class SyncService {
  final Future<String?> Function() getAccessToken;

  SyncService({required this.getAccessToken});

  // Base URL for Netlify Functions
  String get _endpoint {
    // For Web, relative path works and is preferred to avoid CORS issues if on same domain
    if (kIsWeb) {
      if (kReleaseMode) return '/.netlify/functions/sync';
      // Local web dev
      return 'http://localhost:8888/.netlify/functions/sync'; 
    }
    
    // For Desktop/Mobile (Windows), we need the absolute URL.
    // Unless you are running a local backend and want to debug against it,
    // we should point to the production instance to verify "cloud sync".
    return 'https://freak-flix.netlify.app/.netlify/functions/sync'; 
    
    // TODO: Make this configurable via .env if needed
    // return dotenv.env['SYNC_ENDPOINT'] ?? 'https://freak-flix.netlify.app/.netlify/functions/sync';
  }

  Future<void> pushData(Map<String, dynamic> data) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('SyncService: No auth token, skipping push.');
      return;
    }

    try {
      final uri = Uri.parse(_endpoint);
      final jsonStr = jsonEncode(data);
      final bytes = utf8.encode(jsonStr);
      final compressed = GZipEncoder().encode(bytes); 

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Content-Encoding': 'gzip',
          'Authorization': 'Bearer $token',
        },
        body: compressed,
      );

      if (res.statusCode != 200) {
        throw Exception('Sync failed: ${res.statusCode} ${res.body}');
      } else {
        debugPrint('SyncService push success. Payload size: ${compressed?.length ?? 0} bytes');
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
          'Accept-Encoding': 'gzip',
        },
      );

      if (res.statusCode == 200) {
        String bodyStr = res.body; 
        // Dart http client often auto-decompresses if Content-Encoding is gzip 
        // AND the platform supports it (native). 
        // On Web, browser handles it.
        // However, if we manually verify content encoding or want to be safe:
        // If the body looks like garbage/binary or header is still gzip, we decompress.
        // But usually res.body decodes utf8.
        
        final body = jsonDecode(bodyStr);
        if (body is Map<String, dynamic> && body.isNotEmpty) {
           debugPrint('SyncService pull success.');
           return body;
        }
      } else {
        throw Exception('Sync pull failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('SyncService pull error: $e');
    }
    return null;
  }
}
