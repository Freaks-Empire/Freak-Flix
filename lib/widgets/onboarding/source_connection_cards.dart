// lib/widgets/onboarding/source_connection_cards.dart
// Onboarding source cards for local, OneDrive, SFTP, FTP, and WebDAV.

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/library_provider.dart';
import '../../services/graph_auth_service.dart';
import '../../services/metadata_service.dart';
import '../../services/onboarding_source_connection_service.dart';
import '../../services/remote_storage_service.dart';
import '../../utils/security_policies.dart';
import '../device_code_dialog.dart';
import '../settings/remote_connection_dialog.dart';

class OnboardingSourceConnectionCards extends StatefulWidget {
  final LibraryProvider library;
  final GraphAuthService graphAuth;
  final MetadataService? metadata;
  final OnboardingSourceConnectionService? service;
  final ValueChanged<OnboardingSourceStatusEvent>? onStatusChanged;

  const OnboardingSourceConnectionCards({
    super.key,
    required this.library,
    required this.graphAuth,
    this.metadata,
    this.service,
    this.onStatusChanged,
  });

  @override
  State<OnboardingSourceConnectionCards> createState() =>
      _OnboardingSourceConnectionCardsState();
}

class _OnboardingSourceConnectionCardsState
    extends State<OnboardingSourceConnectionCards> {
  static const String _oneDriveDocs =
      'https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code';

  late final OnboardingSourceConnectionService _service;
  final Map<OnboardingSourceType, OnboardingSourceStatusEvent> _events =
      <OnboardingSourceType, OnboardingSourceStatusEvent>{};
  final Set<OnboardingSourceType> _pending = <OnboardingSourceType>{};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingSourceConnectionService();
    for (final source in OnboardingSourceType.values) {
      _events[source] = OnboardingSourceStatusEvent(
        source: source,
        status: OnboardingSourceStatus.notStarted,
        message: 'Not started yet.',
        occurredAt: DateTime.now(),
        failures: 0,
        showEscalatedTroubleshooting: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connect sources (optional)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'You can continue onboarding even if some sources remain incomplete.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildCard(OnboardingSourceType.local),
            _buildCard(OnboardingSourceType.oneDrive),
            _buildCard(OnboardingSourceType.sftp),
            _buildCard(OnboardingSourceType.ftp),
            _buildCard(OnboardingSourceType.webdav),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(OnboardingSourceType source) {
    final event = _events[source]!;
    final isBusy = _pending.contains(source);
    final color = _statusColor(event.status);
    final icon = _sourceIcon(source);

    return Container(
      width: 270,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _sourceTitle(source),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _statusLabel(event.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: event.status == OnboardingSourceStatus.failed
                  ? Colors.red[200]
                  : Colors.white70,
              fontSize: 12,
            ),
          ),
          if (event.showEscalatedTroubleshooting) ...[
            const SizedBox(height: 8),
            const Text(
              'Repeated failures detected. Open troubleshooting docs before retrying.',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openDocsFor(source),
                child: const Text('Troubleshooting docs'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy ? null : () => _connect(source),
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_actionLabel(event.status)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(OnboardingSourceType source) async {
    setState(() {
      _pending.add(source);
      _events[source] = OnboardingSourceStatusEvent(
        source: source,
        status: OnboardingSourceStatus.inProgress,
        message: 'Starting ${_sourceTitle(source)} setup...',
        occurredAt: DateTime.now(),
        failures: _service.failureCountFor(source),
        showEscalatedTroubleshooting:
            _service.shouldEscalateTroubleshooting(source),
      );
    });

    late final OnboardingSourceStatusEvent event;
    switch (source) {
      case OnboardingSourceType.local:
        event = await _service.connectLocal(
          library: widget.library,
          metadata: widget.metadata,
        );
        break;
      case OnboardingSourceType.oneDrive:
        event = await _service.connectOneDrive(
          startAuth: () => showDeviceCodeDialogOutcome(context, widget.graphAuth),
        );
        break;
      case OnboardingSourceType.sftp:
      case OnboardingSourceType.ftp:
      case OnboardingSourceType.webdav:
        event = await _service.connectRemote(
          source: source,
          showConnectionDialog: _showRemoteDialog,
        );
        break;
    }

    if (!mounted) return;
    setState(() {
      _pending.remove(source);
      _events[source] = event;
    });
    widget.onStatusChanged?.call(event);
  }

  Future<OnboardingRemoteConnectResult?> _showRemoteDialog(
    RemoteStorageType type,
  ) {
    return showDialog<OnboardingRemoteConnectResult>(
      context: context,
      builder: (_) => RemoteConnectionDialog(type: type, returnOutcome: true),
    );
  }

  Future<void> _openDocsFor(OnboardingSourceType source) async {
    final url = source == OnboardingSourceType.oneDrive
        ? _oneDriveDocs
        : SecurityPolicies.securityHelpUrl;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Color _statusColor(OnboardingSourceStatus status) {
    switch (status) {
      case OnboardingSourceStatus.notStarted:
        return Colors.grey;
      case OnboardingSourceStatus.inProgress:
        return Colors.blue;
      case OnboardingSourceStatus.connected:
        return Colors.green;
      case OnboardingSourceStatus.incomplete:
        return Colors.orange;
      case OnboardingSourceStatus.failed:
        return Colors.red;
    }
  }

  String _statusLabel(OnboardingSourceStatus status) {
    switch (status) {
      case OnboardingSourceStatus.notStarted:
        return 'Not started';
      case OnboardingSourceStatus.inProgress:
        return 'In progress';
      case OnboardingSourceStatus.connected:
        return 'Connected';
      case OnboardingSourceStatus.incomplete:
        return 'Incomplete';
      case OnboardingSourceStatus.failed:
        return 'Failed';
    }
  }

  String _actionLabel(OnboardingSourceStatus status) {
    switch (status) {
      case OnboardingSourceStatus.notStarted:
      case OnboardingSourceStatus.incomplete:
      case OnboardingSourceStatus.failed:
        return 'Connect';
      case OnboardingSourceStatus.inProgress:
        return 'Connecting...';
      case OnboardingSourceStatus.connected:
        return 'Reconnect';
    }
  }

  String _sourceTitle(OnboardingSourceType source) {
    switch (source) {
      case OnboardingSourceType.local:
        return 'Local Folder';
      case OnboardingSourceType.oneDrive:
        return 'OneDrive';
      case OnboardingSourceType.sftp:
        return 'SFTP';
      case OnboardingSourceType.ftp:
        return 'FTP';
      case OnboardingSourceType.webdav:
        return 'WebDAV';
    }
  }

  IconData _sourceIcon(OnboardingSourceType source) {
    switch (source) {
      case OnboardingSourceType.local:
        return LucideIcons.folderOpen;
      case OnboardingSourceType.oneDrive:
        return LucideIcons.cloud;
      case OnboardingSourceType.sftp:
        return LucideIcons.shield;
      case OnboardingSourceType.ftp:
        return LucideIcons.folderSync;
      case OnboardingSourceType.webdav:
        return LucideIcons.globe;
    }
  }
}
