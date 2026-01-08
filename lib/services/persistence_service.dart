/// lib/services/persistence_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersistenceService {
  PersistenceService._();
  static final PersistenceService _instance = PersistenceService._();
  factory PersistenceService() => _instance;
  static PersistenceService get instance => _instance;

  Future<dynamic> _getFile(String filename) async {
    if (kIsWeb) {
      throw UnsupportedError('File access is not supported on web');
    }
    final dir = await getApplicationSupportDirectory();
    // Ensure directory exists (it should, but safety first)
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, filename));
  }

  /// Saves a string to a file.
  Future<void> saveString(String filename, String content) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(filename, content);
        debugPrint('PersistenceService: Saved $filename to SharedPreferences (${content.length} chars)');
        return;
      }
      final file = await _getFile(filename);
      await file.writeAsString(content, flush: true);
      debugPrint('PersistenceService: Saved $filename (${content.length} chars)');
    } catch (e) {
      debugPrint('PersistenceService: Error saving $filename: $e');
      rethrow;
    }
  }

  /// Loads a string from a file. Returns null if file doesn't exist.
  Future<String?> loadString(String filename) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(filename);
      }
      final file = await _getFile(filename);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('PersistenceService: Error loading $filename: $e');
      return null;
    }
  }

  /// Saves compressed data (GZip) to a file.
  Future<void> saveCompressed(String filename, String content) async {
    try {
      final bytes = utf8.encode(content);
      final compressed = GZipEncoder().encode(bytes);
      if (compressed == null) throw Exception('Compression failed');
      
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final base64String = base64Encode(compressed);
        await prefs.setString(filename, base64String);
        debugPrint('PersistenceService: Saved compressed $filename to SharedPreferences (${compressed.length} bytes)');
        return;
      }

      final file = await _getFile(filename);
      await file.writeAsBytes(compressed, flush: true);
      debugPrint('PersistenceService: Saved compressed $filename (${compressed.length} bytes)');
    } catch (e) {
      debugPrint('PersistenceService: Error saving compressed $filename: $e');
      rethrow;
    }
  }

  /// Loads compressed data (GZip) from a file.
  Future<String?> loadCompressed(String filename) async {
    try {
      List<int>? bytes;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final base64Str = prefs.getString(filename);
        if (base64Str == null) return null;
        bytes = base64Decode(base64Str);
      } else {
        final file = await _getFile(filename);
        if (!await file.exists()) return null;
        bytes = await file.readAsBytes();
      }
      
      if (bytes == null) return null;

      final bytesList = bytes is List<int> ? bytes : (bytes as List).cast<int>();
      return await compute(_decompressHelper, bytesList);
    } catch (e) {
      debugPrint('PersistenceService: Error loading compressed $filename: $e');
      return null;
    }
  }

  /// Deletes a file.
  Future<void> delete(String filename) async {
     try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(filename);
        debugPrint('PersistenceService: Deleted $filename from SharedPreferences');
        return;
      }
      final file = await _getFile(filename);
      if (await file.exists()) {
        await file.delete();
        debugPrint('PersistenceService: Deleted $filename');
      }
    } catch (e) {
      debugPrint('PersistenceService: Error deleting $filename: $e');
    }
  }
}

String _decompressHelper(List<int> bytes) {
  final decompressed = GZipDecoder().decodeBytes(bytes);
  return utf8.decode(decompressed);
}
