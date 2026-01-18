/// lib/widgets/settings/remote_connection_dialog.dart
/// Dialog for adding SFTP/FTP/WebDAV connections

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../services/remote_storage_service.dart';
import '../../services/sftp_client.dart';
import '../../services/ftp_client_wrapper.dart';
import '../../services/webdav_client_wrapper.dart';
import '../settings_widgets.dart';

class RemoteConnectionDialog extends StatefulWidget {
  final RemoteStorageType type;
  
  const RemoteConnectionDialog({
    super.key,
    required this.type,
  });

  @override
  State<RemoteConnectionDialog> createState() => _RemoteConnectionDialogState();
}

class _RemoteConnectionDialogState extends State<RemoteConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  bool _testing = false;
  bool _saving = false;
  bool _obscurePassword = true;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _portController.text = RemoteStorageAccount.defaultPort(widget.type).toString();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  String get _protocolName {
    switch (widget.type) {
      case RemoteStorageType.sftp:
        return 'SFTP';
      case RemoteStorageType.ftp:
        return 'FTP';
      case RemoteStorageType.webdav:
        return 'WebDAV';
    }
  }

  IconData get _protocolIcon {
    switch (widget.type) {
      case RemoteStorageType.sftp:
        return LucideIcons.shield;
      case RemoteStorageType.ftp:
        return LucideIcons.folderSync;
      case RemoteStorageType.webdav:
        return LucideIcons.globe;
    }
  }

  Color get _protocolColor {
    switch (widget.type) {
      case RemoteStorageType.sftp:
        return const Color(0xFF10B981); // Green
      case RemoteStorageType.ftp:
        return const Color(0xFFF59E0B); // Amber
      case RemoteStorageType.webdav:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? RemoteStorageAccount.defaultPort(widget.type);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    bool success = false;
    
    try {
      switch (widget.type) {
        case RemoteStorageType.sftp:
          success = await SftpClient.testConnection(
            host: host,
            port: port,
            username: username,
            password: password,
          );
          break;
        case RemoteStorageType.ftp:
          success = await FtpClientWrapper.testConnection(
            host: host,
            port: port,
            username: username,
            password: password,
          );
          break;
        case RemoteStorageType.webdav:
          success = await WebDavClientWrapper.testConnection(
            host: host,
            port: port,
            username: username,
            password: password,
          );
          break;
      }
    } catch (e) {
      success = false;
    }

    setState(() {
      _testing = false;
      _testSuccess = success;
      _testResult = success ? 'Connection successful!' : 'Connection failed. Check your credentials.';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);

    final account = RemoteStorageAccount(
      id: const Uuid().v4(),
      type: widget.type,
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text) ?? RemoteStorageAccount.defaultPort(widget.type),
      username: _usernameController.text.trim(),
      displayName: _displayNameController.text.trim().isNotEmpty 
          ? _displayNameController.text.trim()
          : '${_usernameController.text}@${_hostController.text}',
    );

    await RemoteStorageService.instance.addAccount(
      account,
      _passwordController.text,
    );

    setState(() => _saving = false);
    
    if (mounted) {
      Navigator.of(context).pop(account);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _protocolColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_protocolIcon, size: 24, color: _protocolColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connect $_protocolName Server',
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.type == RemoteStorageType.ftp)
                            Text(
                              'Warning: FTP is unencrypted',
                              style: TextStyle(
                                color: Colors.amber.shade600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      color: AppColors.textSub,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Host
                _buildTextField(
                  controller: _hostController,
                  label: 'Host',
                  hint: widget.type == RemoteStorageType.webdav 
                      ? 'cloud.example.com/remote.php/dav'
                      : 'server.example.com',
                  icon: LucideIcons.server,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Port
                _buildTextField(
                  controller: _portController,
                  label: 'Port',
                  hint: RemoteStorageAccount.defaultPort(widget.type).toString(),
                  icon: LucideIcons.hash,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Username
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'username',
                  icon: LucideIcons.user,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Password
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  icon: LucideIcons.key,
                  obscure: _obscurePassword,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18,
                    ),
                    color: AppColors.textSub,
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 12),

                // Display Name (optional)
                _buildTextField(
                  controller: _displayNameController,
                  label: 'Display Name (optional)',
                  hint: 'My Server',
                  icon: LucideIcons.tag,
                ),

                // Test result
                if (_testResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_testSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_testSuccess ? Colors.green : Colors.red).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testSuccess ? LucideIcons.checkCircle : LucideIcons.xCircle,
                          size: 18,
                          color: _testSuccess ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              color: _testSuccess ? Colors.green : Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _testing ? null : _testConnection,
                      child: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Connection'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _protocolColor,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Connect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textMain, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSub, fontSize: 13),
        hintStyle: TextStyle(color: AppColors.textSub.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSub),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _protocolColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
