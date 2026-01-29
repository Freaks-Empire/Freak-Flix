/// lib/screens/remote_folder_picker.dart
/// Folder browser for SFTP, FTP, and WebDAV remote storage

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/remote_storage_service.dart';
import '../services/sftp_client.dart';
import '../services/ftp_client_wrapper.dart';
import '../services/webdav_client_wrapper.dart';
import '../widgets/settings_widgets.dart';

/// Result returned when a folder is selected
class RemoteFolderSelection {
  final String path;
  final String name;
  final RemoteStorageAccount account;

  RemoteFolderSelection({
    required this.path,
    required this.name,
    required this.account,
  });
}

class RemoteFolderPicker extends StatefulWidget {
  final RemoteStorageAccount account;

  const RemoteFolderPicker({super.key, required this.account});

  @override
  State<RemoteFolderPicker> createState() => _RemoteFolderPickerState();
}

class _RemoteFolderPickerState extends State<RemoteFolderPicker> {
  // Clients
  SftpClient? _sftpClient;
  FtpClientWrapper? _ftpClient;
  WebDavClientWrapper? _webdavClient;

  // State
  String _currentPath = '/';
  List<String> _pathStack = [];
  List<RemoteFile> _items = [];
  bool _loading = false;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  void _disconnect() {
    _sftpClient?.disconnect();
    _ftpClient?.disconnect();
    _webdavClient?.disconnect();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      // Get stored password
      final password = await RemoteStorageService.instance.getPassword(widget.account.id);
      if (password == null) {
        throw Exception('No stored password found for this account');
      }

      bool connected = false;

      switch (widget.account.type) {
        case RemoteStorageType.sftp:
          _sftpClient = SftpClient(widget.account);
          connected = await _sftpClient!.connect(password);
          break;
        case RemoteStorageType.ftp:
          _ftpClient = FtpClientWrapper(widget.account);
          connected = await _ftpClient!.connect(password);
          break;
        case RemoteStorageType.webdav:
          _webdavClient = WebDavClientWrapper(widget.account);
          connected = await _webdavClient!.connect(password);
          break;
      }

      if (!connected) {
        throw Exception('Failed to connect to ${widget.account.host}');
      }

      // Successfully connected, load root directory
      await _loadDirectory('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      List<RemoteFile> files = [];

      switch (widget.account.type) {
        case RemoteStorageType.sftp:
          if (_sftpClient != null) {
            files = await _sftpClient!.listDirectory(path);
          }
          break;
        case RemoteStorageType.ftp:
          if (_ftpClient != null) {
            files = await _ftpClient!.listDirectory(path);
          }
          break;
        case RemoteStorageType.webdav:
          if (_webdavClient != null) {
            files = await _webdavClient!.listDirectory(path);
          }
          break;
      }

      // Sort: folders first, then alphabetically
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      setState(() {
        _currentPath = path;
        _items = files;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateTo(RemoteFile item) {
    if (!item.isDirectory) return;
    _pathStack.add(_currentPath);
    _loadDirectory(item.path);
  }

  void _goBack() {
    if (_pathStack.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final previous = _pathStack.removeLast();
    _loadDirectory(previous);
  }

  void _selectCurrentFolder() {
    Navigator.of(context).pop(
      RemoteFolderSelection(
        path: _currentPath,
        name: _currentPath.split('/').where((s) => s.isNotEmpty).lastOrNull ?? 'Root',
        account: widget.account,
      ),
    );
  }

  void _selectFolder(RemoteFile folder) {
    Navigator.of(context).pop(
      RemoteFolderSelection(
        path: folder.path,
        name: folder.name,
        account: widget.account,
      ),
    );
  }

  Color get _protocolColor {
    switch (widget.account.type) {
      case RemoteStorageType.sftp:
        return const Color(0xFF10B981);
      case RemoteStorageType.ftp:
        return const Color(0xFFF59E0B);
      case RemoteStorageType.webdav:
        return const Color(0xFF6366F1);
    }
  }

  IconData get _protocolIcon {
    switch (widget.account.type) {
      case RemoteStorageType.sftp:
        return LucideIcons.shield;
      case RemoteStorageType.ftp:
        return LucideIcons.folderSync;
      case RemoteStorageType.webdav:
        return LucideIcons.globe;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textMain),
          onPressed: _goBack,
        ),
        title: Row(
          children: [
            Icon(_protocolIcon, size: 20, color: _protocolColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.account.displayName,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentPath,
                    style: const TextStyle(
                      color: AppColors.textSub,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.textSub),
            onPressed: () => _loadDirectory(_currentPath),
          ),
        ],
      ),
      body: _connecting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _protocolColor),
                  const SizedBox(height: 16),
                  Text(
                    'Connecting to ${widget.account.host}...',
                    style: const TextStyle(color: AppColors.textSub),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Connection Error',
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.textSub),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _connect,
                          icon: const Icon(LucideIcons.refreshCw),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _protocolColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _loading
                  ? Center(child: CircularProgressIndicator(color: _protocolColor))
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.folderOpen, size: 48, color: AppColors.textSub.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              const Text(
                                'Empty folder',
                                style: TextStyle(color: AppColors.textSub),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _buildFileItem(item);
                          },
                        ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _selectCurrentFolder,
            icon: const Icon(LucideIcons.check),
            label: Text('Use this folder: $_currentPath'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _protocolColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(RemoteFile item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateTo(item),
        onLongPress: item.isDirectory ? () => _selectFolder(item) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.isDirectory
                      ? _protocolColor.withOpacity(0.1)
                      : AppColors.textSub.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.isDirectory ? LucideIcons.folder : LucideIcons.file,
                  size: 20,
                  color: item.isDirectory ? _protocolColor : AppColors.textSub,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: item.isDirectory ? AppColors.textMain : AppColors.textSub,
                        fontSize: 14,
                        fontWeight: item.isDirectory ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    if (item.size != null)
                      Text(
                        _formatSize(item.size!),
                        style: TextStyle(
                          color: AppColors.textSub.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (item.isDirectory)
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textSub),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
