/// lib/screens/onedrive_browser_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/graph_auth_service.dart';
import '../widgets/device_code_dialog.dart';
import 'video_player_screen.dart';

class OneDriveBrowserScreen extends StatefulWidget {
  final GraphAuthService auth;
  final String initialPath;

  const OneDriveBrowserScreen(
      {super.key, required this.auth, this.initialPath = '/'});

  @override
  State<OneDriveBrowserScreen> createState() => _OneDriveBrowserScreenState();
}

class _OneDriveBrowserScreenState extends State<OneDriveBrowserScreen> {
  late String _currentPath;
  bool _loading = false;
  String? _error;
  List<_DriveItem> _items = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadFolder(_currentPath);
  }

  Future<void> _loadFolder(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });

    try {
      final token = await _ensureAccessToken();
      final url = _buildChildrenUrl(path);
      final res =
          await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) {
        throw Exception('Graph error: ${res.statusCode} ${res.body}');
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> value =
          json['value'] as List<dynamic>? ?? <dynamic>[];

      final items = <_DriveItem>[];
      for (final raw in value) {
        final m = raw as Map<String, dynamic>;
        final isFolder = m['folder'] != null;
        final name = m['name'] as String? ?? '';
        final id = m['id'] as String? ?? '';
        final downloadUrl = m['@microsoft.graph.downloadUrl'] as String?;
        items.add(_DriveItem(
          id: id,
          name: name,
          isFolder: isFolder,
          downloadUrl: downloadUrl,
        ));
      }

      items.sort((a, b) {
        if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      setState(() {
        _items = items;
        _currentPath = path;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> _ensureAccessToken() async {
    final active = widget.auth.activeAccount;
    if (active != null) {
      return widget.auth.getFreshAccessToken(active.id);
    }

    final account = await showDeviceCodeDialog(context, widget.auth);
    if (account == null) {
      throw Exception('Microsoft sign-in was canceled.');
    }

    return widget.auth.getFreshAccessToken(account.id);
  }

  Uri _buildChildrenUrl(String path) {
    final baseUrl = widget.auth.graphBaseUrl;
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') {
      return Uri.parse('$baseUrl/me/drive/root/children');
    }
    final normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    final encodedPath = Uri.encodeComponent(normalized).replaceAll('%2F', '/');
    return Uri.parse('$baseUrl/me/drive/root:/$encodedPath:/children');
  }

  bool _isVideo(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mkv') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm');
  }

  void _goUp() {
    if (_currentPath == '/' || _currentPath.isEmpty) return;
    final parts = _currentPath.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) {
      _loadFolder('/');
      return;
    }
    parts.removeLast();
    final newPath = parts.isEmpty ? '/' : '/${parts.join('/')}';
    _loadFolder(newPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OneDrive: $_currentPath'),
        actions: [
          if (_currentPath != '/')
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: _goUp,
              tooltip: 'Up one folder',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadFolder(_currentPath),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      leading:
                          Icon(item.isFolder ? Icons.folder : Icons.video_file),
                      title: Text(item.name),
                      onTap: () {
                        if (item.isFolder) {
                          final newPath = _currentPath == '/'
                              ? '/${item.name}'
                              : '$_currentPath/${item.name}';
                          _loadFolder(newPath);
                        } else if (_isVideo(item.name) &&
                            item.downloadUrl != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VideoPlayerScreen(
                                  filePath: item.downloadUrl!,
                                  title: item.name,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _DriveItem {
  final String id;
  final String name;
  final bool isFolder;
  final String? downloadUrl;

  _DriveItem({
    required this.id,
    required this.name,
    required this.isFolder,
    this.downloadUrl,
  });
}
