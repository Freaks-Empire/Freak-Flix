import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

class PersistenceService {
  PersistenceService._();
  static final PersistenceService _instance = PersistenceService._();
  factory PersistenceService() => _instance;
  static PersistenceService get instance => _instance;

  Future<File> _getFile(String filename) async {
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
      final file = await _getFile(filename);
      if (!await file.exists()) return null;
      
      final bytes = await file.readAsBytes();
      final decompressed = GZipDecoder().decodeBytes(bytes);
      return utf8.decode(decompressed);
    } catch (e) {
      debugPrint('PersistenceService: Error loading compressed $filename: $e');
      return null;
    }
  }
  
  /// Deletes a file.
  Future<void> delete(String filename) async {
     try {
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
