import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/graph_auth_service.dart';

class OneDriveFolderSelection {
  final String id;
  final String path;
  final String name;

  OneDriveFolderSelection(
      {required this.id, required this.path, required this.name});
}

class OneDriveFolderPicker extends StatefulWidget {
  final GraphAuthService auth;
  const OneDriveFolderPicker({super.key, required this.auth});

  @override
  State<OneDriveFolderPicker> createState() => _OneDriveFolderPickerState();
}

class _OneDriveFolderPickerState extends State<OneDriveFolderPicker> {
  _DriveFolder? _current;
  List<_DriveFolder> _stack = [];
  List<_DriveItem> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoot();
  }

  Future<void> _loadRoot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await widget.auth.getOrLoginWithDeviceCode();
      final rootRes = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me/drive/root'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (rootRes.statusCode != 200) {
        throw Exception('Graph error: ${rootRes.statusCode} ${rootRes.body}');
      }
      final rootJson = jsonDecode(rootRes.body) as Map<String, dynamic>;
      final root = _DriveFolder(
        id: rootJson['id'] as String? ?? 'root',
        name: 'Root',
        path: '/',
      );
      _stack = [];
      await _loadFolder(root, token: token);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFolder(_DriveFolder folder, {String? token}) async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });

    try {
      final t = token ?? await widget.auth.getOrLoginWithDeviceCode();
      final url = Uri.parse(
          'https://graph.microsoft.com/v1.0/me/drive/items/${folder.id}/children');
      final res = await http.get(url, headers: {'Authorization': 'Bearer $t'});
      if (res.statusCode != 200) {
        throw Exception('Graph error: ${res.statusCode} ${res.body}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final values = body['value'] as List<dynamic>? ?? <dynamic>[];
      final children = <_DriveItem>[];
      for (final raw in values) {
        final m = raw as Map<String, dynamic>;
        final isFolder = m['folder'] != null;
        final name = m['name'] as String? ?? '';
        final id = m['id'] as String? ?? '';
        final child = _DriveItem(
          id: id,
          name: name,
          isFolder: isFolder,
          path: folder.path == '/' ? '/$name' : '${folder.path}/$name',
        );
        children.add(child);
      }
      children
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _current = folder;
        _items = children;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateTo(_DriveItem item) {
    if (!item.isFolder) return;
    final next = _DriveFolder(id: item.id, name: item.name, path: item.path);
    _stack.add(_current!);
    _loadFolder(next);
  }

  void _goBack() {
    if (_stack.isEmpty) return;
    final previous = _stack.removeLast();
    _loadFolder(previous);
  }

  void _selectCurrent() {
    final folder = _current;
    if (folder == null) return;
    Navigator.of(context).pop(
      OneDriveFolderSelection(
          id: folder.id, path: folder.path, name: folder.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _current?.path ?? 'OneDrive';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: _stack.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final current = _current;
              if (current != null) _loadFolder(current);
            },
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
                      leading: Icon(item.isFolder
                          ? Icons.folder
                          : Icons.insert_drive_file_outlined),
                      title: Text(item.name),
                      subtitle: Text(item.path),
                      onTap: () => _navigateTo(item),
                      onLongPress: item.isFolder
                          ? () {
                              Navigator.of(context).pop(
                                OneDriveFolderSelection(
                                    id: item.id,
                                    path: item.path,
                                    name: item.name),
                              );
                            }
                          : null,
                    );
                  },
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: _current == null ? null : _selectCurrent,
          icon: const Icon(Icons.check),
          label: Text('Use this folder (${_current?.path ?? ''})'),
        ),
      ),
    );
  }
}

class _DriveFolder {
  final String id;
  final String name;
  final String path;

  _DriveFolder({required this.id, required this.name, required this.path});
}

class _DriveItem {
  final String id;
  final String name;
  final bool isFolder;
  final String path;

  _DriveItem(
      {required this.id,
      required this.name,
      required this.isFolder,
      required this.path});
}
