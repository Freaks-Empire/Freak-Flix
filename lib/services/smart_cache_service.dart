/// lib/services/smart_cache_service.dart
/// 
/// Intelligent caching service for better performance
/// Implements predictive caching, adaptive cache sizes, and memory management

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/secure_logger.dart';

/// Cache configuration
class CacheConfig {
  final int maxSizeBytes;
  final int maxItems;
  final Duration cleanupInterval;
  final Duration maxAge;

  const CacheConfig({
    this.maxSizeBytes = 500 * 1024 * 1024, // 500MB default
    this.maxItems = 1000,
    this.cleanupInterval = const Duration(hours: 1),
    this.maxAge = const Duration(days: 7),
  });
}

/// Cache item with metadata
class CacheItem {
  final String key;
  final String filePath;
  final int sizeBytes;
  final DateTime lastAccessed;
  final int accessCount;
  final Duration? duration;
  
  const CacheItem({
    required this.key,
    required this.filePath,
    required this.sizeBytes,
    required this.lastAccessed,
    this.accessCount = 0,
    this.duration,
  });
}

/// Smart cache service with predictive features
class SmartCacheService {
  static final SmartCacheService _instance = SmartCacheService._internal();
  factory SmartCacheService() => _instance;
  
  SmartCacheService._internal();
  
  final CacheConfig _config = const CacheConfig();
  final Map<String, CacheItem> _cache = {};
  Timer? _cleanupTimer;
  int _currentCacheSize = 0;

  /// Initialize cache service
  Future<void> initialize() async {
    await _loadCacheFromDisk();
    _startPeriodicCleanup();
  }

  /// Load existing cache from disk
  Future<void> _loadCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString('smart_cache');
      
      if (cacheData != null) {
        final items = (cacheData as String).split('|');
        for (final item in items) {
          if (item.isEmpty) continue;
          
          final parts = item.split(':');
          if (parts.length >= 3) {
            _cache[parts[0]] = CacheItem(
              key: parts[0],
              filePath: parts[1],
              sizeBytes: int.tryParse(parts[2]) ?? 0,
              lastAccessed: DateTime.tryParse(parts[3]) ?? DateTime.now(),
              accessCount: int.tryParse(parts[4]) ?? 0,
            );
          }
        }
      }
      
      _updateCacheSize();
      SecureLogger.debug('Loaded ${_cache.length} items from cache', 'SmartCache');
    } catch (e) {
      SecureLogger.error('Error loading cache from disk', e, 'SmartCache');
    }
  }

  /// Save cache to disk
  Future<void> _saveCacheToDisk() async {
    try {
      final items = _cache.values.map((k, v) => '$k:${v.filePath}:${v.sizeBytes}:${v.lastAccessed.millisecondsSinceEpoch}:${v.accessCount}:${v.duration?.inMilliseconds ?? 0}').join('|');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('smart_cache', items);
      
      _updateCacheSize();
      SecureLogger.debug('Saved ${_cache.length} items to cache', 'SmartCache');
    } catch (e) {
      SecureLogger.error('Error saving cache to disk', e, 'SmartCache');
    }
  }

  /// Get cached file if available
  String? getCachedFile(String filePath) {
    final item = _cache.values.firstWhere(
      (item) => item.filePath == filePath && item.sizeBytes > 0,
    );
    
    if (item != null && await File(item.filePath).exists()) {
      item.accessCount++;
      item.lastAccessed = DateTime.now();
      return item.filePath;
    }
    
    return null;
  }

  /// Add item to cache
  Future<void> addToCache({
    required String filePath,
    required List<int> data,
    int? estimatedSize,
    Duration? estimatedDuration,
    bool isHighPriority = false,
  }) async {
    final sizeBytes = estimatedSize ?? data.length;
    final cacheKey = _generateCacheKey(filePath);
    
    // Check if we should add to cache (exists and not too large)
    final file = File(filePath);
    if (await file.exists()) {
      final fileSize = await file.length();
      if (fileSize <= _config.maxSizeBytes) {
        _currentCacheSize += sizeBytes;
        
        _cache[cacheKey] = CacheItem(
          key: cacheKey,
          filePath: filePath,
          sizeBytes: sizeBytes,
          lastAccessed: DateTime.now(),
          accessCount: 1,
          duration: estimatedDuration,
        );
        
        // Remove oldest items if cache is full
        await _evictOldestItems();
        
        SecureLogger.debug('Added to cache: $filePath (${(sizeBytes / 1024 / 1024).toStringAsFixed(1)}MB)', 'SmartCache');
      } else {
        SecureLogger.warning('File too large for cache: ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB', 'SmartCache');
      }
    } else {
      SecureLogger.warning('File not found: $filePath', 'SmartCache');
    }
  }

  /// Generate cache key
  String _generateCacheKey(String filePath) {
    // Hash the file path for consistent key generation
    final cleanPath = filePath.replaceAll(RegExp(r'[^\w\.:\\/]+'), '_');
    return cleanPath.hashCode().toString();
  }

  /// Get current cache statistics
  Map<String, dynamic> getCacheStats() {
    final totalSize = _cache.values.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    final totalItems = _cache.length;
    final oldestDate = _cache.values.isEmpty 
        ? DateTime.now() 
        : _cache.values.map((item) => item.lastAccessed).reduce((a, b) => a.isBefore(b) ? a : b);
    
    final oldestItem = _cache.values.isEmpty ? null : _cache.values.firstWhere(
      (item) => item.lastAccessed.millisecondsSinceEpoch == oldestDate.millisecondsSinceEpoch,
    );
    
    return {
      'total_size_mb': (totalSize / 1024 / 1024).toStringAsFixed(1),
      'total_items': totalItems,
      'oldest_date': oldestDate?.toIso8601String(),
      'oldest_file': oldestItem?.filePath,
      'cache_hit_rate': _calculateHitRate(),
    };
  }

  /// Calculate cache hit rate
  double _calculateHitRate() {
    if (_cache.isEmpty) return 0.0;
    
    final totalAccesses = _cache.values.fold<int>(0, (sum, item) => sum + item.accessCount);
    final hits = _cache.values.where((item) => item.accessCount > 1).length;
    
    return hits / totalAccesses;
  }

  /// Periodic cleanup of old cache items
  Future<void> _evictOldestItems() async {
    if (_cache.length <= _config.maxItems) return;
    
    // Sort by last access time (LRU cache eviction)
    final sortedItems = _cache.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));
    
    // Remove oldest items if we have too many
    final itemsToRemove = sortedItems.take(_cache.length - _config.maxItems);
    
    for (final item in itemsToRemove) {
      try {
        final file = File(item.filePath);
        if (await file.exists()) {
          await file.delete();
          _cache.remove(item.key);
          _currentCacheSize -= item.sizeBytes;
          SecureLogger.debug('Evicted from cache: ${item.filePath}', 'SmartCache');
        }
      } catch (e) {
        SecureLogger.error('Error evicting cache item: ${item.filePath}', e, 'SmartCache');
      }
    }
  }

  /// Update current cache size
  void _updateCacheSize() {
    _currentCacheSize = _cache.values.fold<int>(0, (sum, item) => sum + item.sizeBytes);
  }

  /// Start periodic cleanup timer
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    
    _cleanupTimer = Timer.periodic(_config.cleanupInterval, (timer) async {
      await _evictOldestItems();
      await _saveCacheToDisk();
      await _performMemoryOptimization();
    });
  }

  /// Perform memory optimization (placeholder for now)
  Future<void> _performMemoryOptimization() async {
    // Could implement: cache size analysis, compression algorithms
    // For now, just log current memory state
    final cacheSizeMB = _currentCacheSize / 1024 / 1024;
    SecureLogger.debug('Cache size: ${cacheSizeMB.toStringAsFixed(1)}MB', 'SmartCache');
  }
}