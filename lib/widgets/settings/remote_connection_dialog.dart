// lib/widgets/settings/remote_connection_dialog.dart
// Dialog for adding SFTP/FTP/WebDAV connections

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../services/remote_storage_service.dart';
import '../../services/sftp_client.dart';
import '../../services/ftp_client_wrapper.dart';
import '../../services/webdav_client_wrapper.dart';
import '../../services/onboarding_source_connection_service.dart';
import '../settings_widgets.dart';
import '../../utils/input_validation.dart';
import '../../utils/security_policies.dart';
import '../../utils/security_validation_result.dart';

class RemoteConnectionDialog extends StatefulWidget {
  final RemoteStorageType type;
  final bool returnOutcome;
  
  const RemoteConnectionDialog({
    super.key,
    required this.type,
    this.returnOutcome = false,
  });

  @override
  State<RemoteConnectionDialog> createState() => _RemoteConnectionDialogState();
}

class _RemoteConnectionDialogState extends State<RemoteConnectionDialog> {
  static const int _escalationThreshold = 3;

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
  String? _connectionErrorField;
  int _connectionFailureCount = 0;
  SecurityValidationResult? _hostTypingWarning;
  SecurityValidationResult? _submitValidationResult;
  String? _submitValidationField;
  final Map<String, int> _blockedSubmitAttempts = {};

  @override
  void initState() {
    super.initState();
    _portController.text = RemoteStorageAccount.defaultPort(widget.type).toString();
    
    // Lightweight typing-time validation (strict checks happen on submit).
    _hostController.addListener(() {
      final warning = widget.type == RemoteStorageType.webdav
          ? null
          : InputValidation.getTypingHostWarning(_hostController.text);
      if (warning?.reason != _hostTypingWarning?.reason) {
        setState(() {
          _hostTypingWarning = warning;
        });
      }
    });
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

    final strictValidation = _validateStrictFields(isSubmit: false);
    if (!strictValidation) return;
    
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? RemoteStorageAccount.defaultPort(widget.type);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final attempt = await _attemptConnection(
      host: host,
      port: port,
      username: username,
      password: password,
    );

    if (attempt.success) {
      setState(() {
        _testing = false;
        _testSuccess = true;
        _testResult = 'Connection successful!';
        _connectionErrorField = null;
      });
    } else {
      setState(() {
        _testing = false;
      });
      _registerConnectionFailure(attempt.error ?? 'Connection failed.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final strictValidation = _validateStrictFields(isSubmit: true);
    if (!strictValidation) return;
    
    // Show security warning for FTP
    if (widget.type == RemoteStorageType.ftp) {
      final confirmed = await _showFtpSecurityWarning();
      if (!confirmed) return;
    }

    setState(() => _saving = true);

    final attempt = await _attemptConnection(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text) ??
          RemoteStorageAccount.defaultPort(widget.type),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    if (!attempt.success) {
      setState(() => _saving = false);
      _registerConnectionFailure(
        attempt.error ?? 'Connection failed during validation.',
      );
      return;
    }

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
      if (widget.returnOutcome) {
        Navigator.of(context).pop(
          OnboardingRemoteConnectResult(
            outcome: OnboardingRemoteOutcome.connected,
            account: account,
            message: '${account.displayName} connected successfully.',
          ),
        );
      } else {
        Navigator.of(context).pop(account);
      }
    }
  }

  Future<({bool success, String? error})> _attemptConnection({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      bool success;
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
      return (
        success: success,
        error: success ? null : 'Unable to establish a $_protocolName session.',
      );
    } catch (error) {
      return (success: false, error: error.toString());
    }
  }

  bool _validateStrictFields({required bool isSubmit}) {
    final hostField = widget.type == RemoteStorageType.webdav ? 'url' : 'host';
    final hostResult = widget.type == RemoteStorageType.webdav
        ? InputValidation.strictValidateWebDavUrl(_hostController.text)
        : InputValidation.strictValidateHostname(_hostController.text);
    if (hostResult.isBlocking) {
      _registerBlockingResult(hostField, hostResult, isSubmit: isSubmit);
      return false;
    }

    final portResult = InputValidation.strictValidatePort(_portController.text);
    if (portResult.isBlocking) {
      _registerBlockingResult('port', portResult, isSubmit: isSubmit);
      return false;
    }

    final usernameResult = InputValidation.strictValidateUsername(_usernameController.text);
    if (usernameResult.isBlocking) {
      _registerBlockingResult('username', usernameResult, isSubmit: isSubmit);
      return false;
    }

    setState(() {
      _submitValidationResult = null;
      _submitValidationField = null;
    });
    return true;
  }

  void _registerBlockingResult(
    String field,
    SecurityValidationResult result, {
    required bool isSubmit,
  }) {
    if (isSubmit) {
      _blockedSubmitAttempts[field] = (_blockedSubmitAttempts[field] ?? 0) + 1;
    }

    setState(() {
      _submitValidationField = field;
      _submitValidationResult = result;
      _testSuccess = false;
      _testResult = result.reason;
    });
  }

  void _registerConnectionFailure(String errorMessage) {
    setState(() {
      _connectionFailureCount += 1;
      _testSuccess = false;
      _testResult = errorMessage;
      _connectionErrorField = _classifyConnectionErrorField(errorMessage);
    });
  }

  String? _classifyConnectionErrorField(String errorMessage) {
    final normalized = errorMessage.toLowerCase();
    if (normalized.contains('auth') ||
        normalized.contains('credential') ||
        normalized.contains('password') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized')) {
      return 'password';
    }
    if (normalized.contains('port') || normalized.contains('refused')) {
      return 'port';
    }
    if (normalized.contains('user') || normalized.contains('login')) {
      return 'username';
    }
    return 'host';
  }

  bool _showEscalatedGuidance() {
    final field = _submitValidationField;
    if (field == null) return false;
    return (_blockedSubmitAttempts[field] ?? 0) >= 3;
  }

  bool _showEscalatedConnectionGuidance() {
    return _connectionFailureCount >= _escalationThreshold;
  }

  Future<void> _handleCancel() async {
    if (!mounted) return;
    if (!widget.returnOutcome) {
      Navigator.pop(context);
      return;
    }

    if (_connectionFailureCount > 0) {
      Navigator.of(context).pop(
        OnboardingRemoteConnectResult(
          outcome: OnboardingRemoteOutcome.failed,
          message: _testResult ?? 'Remote setup was closed after connection errors.',
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      const OnboardingRemoteConnectResult(
        outcome: OnboardingRemoteOutcome.cancelled,
        message: 'Remote setup cancelled before finishing.',
      ),
    );
  }

  void _applySafeDefault() {
    final safeDefault = _submitValidationResult?.safeDefault;
    if (safeDefault == null) return;

    switch (_submitValidationField) {
      case 'host':
      case 'url':
        _hostController.text = safeDefault;
        break;
      case 'port':
        _portController.text = safeDefault;
        break;
      case 'username':
        _usernameController.text = safeDefault;
        break;
    }

    setState(() {
      _submitValidationResult = null;
      _submitValidationField = null;
    });
  }

  Future<void> _openSecurityHelp() async {
    final uri = Uri.parse(SecurityPolicies.securityHelpUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _showFtpSecurityWarning() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.amber.shade600),
            const SizedBox(width: 8),
            const Text('Security Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FTP connections are not secure:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Credentials are transmitted in plaintext'),
            const Text('• Data is not encrypted during transfer'),
            const Text('• Vulnerable to network interception'),
            const SizedBox(height: 12),
            const Text(
              'Consider using SFTP or WebDAV for secure connections instead.',
              style: TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 8),
            const Text('Do you want to continue with this insecure connection?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    ) ?? false;
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, color: Colors.amber.shade600, size: 16),
                                const SizedBox(width: 4),
                                const Text(
                                  'Insecure Connection',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      color: AppColors.textSub,
                      onPressed: _handleCancel,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Host
                _buildTextField(
                  controller: _hostController,
                  label: widget.type == RemoteStorageType.webdav ? 'URL' : 'Host',
                  hint: widget.type == RemoteStorageType.webdav 
                      ? 'https://cloud.example.com/remote.php/dav'
                      : 'server.example.com',
                  icon: LucideIcons.server,
                  validator: widget.type == RemoteStorageType.webdav
                      ? InputValidation.validateWebDavUrl
                      : InputValidation.validateHostname,
                  errorText: _connectionErrorField == 'host'
                      ? _testResult
                      : null,
                ),
                const SizedBox(height: 12),

                // Port
                _buildTextField(
                  controller: _portController,
                  label: 'Port',
                  hint: RemoteStorageAccount.defaultPort(widget.type).toString(),
                  icon: LucideIcons.hash,
                  keyboardType: TextInputType.number,
                  validator: InputValidation.validatePort,
                  errorText: _connectionErrorField == 'port'
                      ? _testResult
                      : null,
                ),
                const SizedBox(height: 12),

                // Username
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'username',
                  icon: LucideIcons.user,
                  validator: InputValidation.validateUsername,
                  errorText: _connectionErrorField == 'username'
                      ? _testResult
                      : null,
                ),
                const SizedBox(height: 12),

                // Password
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  icon: LucideIcons.key,
                  obscure: _obscurePassword,
                  validator: InputValidation.validatePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18,
                    ),
                    color: AppColors.textSub,
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  errorText: _connectionErrorField == 'password'
                      ? _testResult
                      : null,
                ),
                const SizedBox(height: 12),

                // Display Name (optional)
                _buildTextField(
                  controller: _displayNameController,
                  label: 'Display Name (optional)',
                  hint: 'My Server',
                  icon: LucideIcons.tag,
                  validator: InputValidation.validateDisplayName,
                ),

                if (_connectionFailureCount > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Troubleshooting before retry',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('1. Confirm host, port, and protocol match your server configuration.', style: TextStyle(fontSize: 12)),
                        const Text('2. Verify username/password are valid for this protocol.', style: TextStyle(fontSize: 12)),
                        const Text('3. Retry "Test Connection" before saving the profile.', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],

                if (_showEscalatedConnectionGuidance()) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Repeated failures checklist',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('- Try connecting from the same network using another client to confirm server availability.', style: TextStyle(fontSize: 12)),
                        const Text('- Confirm firewall rules allow inbound traffic on this protocol port.', style: TextStyle(fontSize: 12)),
                        const Text('- Prefer SFTP/WebDAV over FTP for secure credentials and transport.', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _openSecurityHelp,
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Open security and network docs'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Lightweight typing-time warning.
                if (_hostTypingWarning != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange.shade600, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Network Warning',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hostTypingWarning!.reason,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hostTypingWarning!.fixExample,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_submitValidationResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'We blocked this entry to protect your connection settings.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_submitValidationResult!.reason),
                        const SizedBox(height: 4),
                        Text('Try this: ${_submitValidationResult!.fixExample}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _submitValidationResult!.safeDefault == null
                                    ? null
                                    : _applySafeDefault,
                                child: const Text('Use safe default'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _submitValidationResult = null;
                                  });
                                },
                                child: const Text('Edit manually'),
                              ),
                            ),
                          ],
                        ),
                        if (_showEscalatedGuidance()) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Need help? We noticed repeated blocked attempts. Open security guidance for examples and allowed formats.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _openSecurityHelp,
                              icon: const Icon(Icons.help_outline, size: 16),
                              label: const Text('Open security help'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Security warning for FTP
                if (widget.type == RemoteStorageType.ftp) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, color: Colors.amber.shade600, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Security Notice',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'FTP transmits your username, password, and all data in plaintext over the network.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Anyone on the same network can intercept your credentials.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use SFTP (SSH) or WebDAV (HTTPS) for secure encrypted connections.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
    String? errorText,
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
        errorText: errorText,
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
