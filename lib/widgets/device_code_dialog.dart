// lib/widgets/device_code_dialog.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/graph_auth_service.dart';
import '../services/onboarding_source_connection_service.dart';

Future<GraphAccount?> showDeviceCodeDialog(
  BuildContext context,
  GraphAuthService auth,
) async {
  final result = await showDeviceCodeDialogOutcome(context, auth);
  if (result.outcome == OnboardingOneDriveOutcome.connected) {
    return result.account;
  }
  return null;
}

Future<OnboardingOneDriveAuthResult> showDeviceCodeDialogOutcome(
  BuildContext context,
  GraphAuthService auth,
) async {
  final result = await showDialog<OnboardingOneDriveAuthResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DeviceCodeDialog(auth: auth),
  );

  return result ??
      const OnboardingOneDriveAuthResult(
        outcome: OnboardingOneDriveOutcome.cancelled,
        message: 'Microsoft sign-in was closed before completion.',
      );
}

class DeviceCodeDialog extends StatefulWidget {
  final GraphAuthService auth;

  const DeviceCodeDialog({super.key, required this.auth});

  @override
  State<DeviceCodeDialog> createState() => _DeviceCodeDialogState();
}

class _DeviceCodeDialogState extends State<DeviceCodeDialog> {
  static const int _escalationThreshold = 3;
  static const String _troubleshootingDocsUrl =
      'https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code';

  DeviceCodeSession? _session;
  String _status = 'Requesting code from Microsoft...';
  String? _error;
  bool _loading = true;
  bool _finished = false;
  bool _isPolling = false;
  bool _timedOut = false;
  int _failedAttempts = 0;
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  int _interval = 5;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      final session = await widget.auth.requestDeviceCode();
      if (!mounted) return;
      setState(() {
        _session = session;
        _interval = session.interval;
        _status = 'Enter the code on the Microsoft page to continue.';
        _loading = false;
        _timedOut = false;
        _error = null;
      });
      _startCountdown();
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _failedAttempts += 1;
        _loading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = _session;
      if (session == null) return;
      final remaining = session.expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        _timedOut = true;
        _complete(
          const OnboardingOneDriveAuthResult(
            outcome: OnboardingOneDriveOutcome.timedOut,
            message: 'Microsoft device code timed out before completion.',
          ),
        );
      } else {
        if (mounted) setState(() {});
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      Duration(seconds: _interval),
      (_) => _pollOnce(),
    );
    _isPolling = true;
  }

  Future<void> _pollOnce() async {
    final session = _session;
    if (session == null || _finished) return;

    setState(() {
      _isPolling = true;
      _status = 'Waiting for confirmation...';
    });

    try {
      final result = await widget.auth.pollDeviceCode(session);
      if (!mounted) return;
      switch (result.state) {
        case DeviceCodePollState.pending:
          setState(() {
            _status = 'Still waiting for you to finish in the browser...';
          });
          break;
        case DeviceCodePollState.slowDown:
          setState(() {
            _status = 'Microsoft asked us to slow down...';
            _interval = result.recommendedInterval ?? (_interval + 5);
          });
          _startPolling();
          break;
        case DeviceCodePollState.declined:
          _stopPollingWithError(
            result.error ?? 'Authorization declined by user.',
          );
          break;
        case DeviceCodePollState.expired:
          _timedOut = true;
          _complete(
            OnboardingOneDriveAuthResult(
              outcome: OnboardingOneDriveOutcome.timedOut,
              message: result.error ?? 'Device code expired before completion.',
            ),
          );
          break;
        case DeviceCodePollState.error:
          _stopPollingWithError(result.error ?? 'Authentication error.');
          break;
        case DeviceCodePollState.success:
          _complete(
            OnboardingOneDriveAuthResult(
              outcome: OnboardingOneDriveOutcome.connected,
              account: result.account,
              message: 'OneDrive connected successfully.',
            ),
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _stopPollingWithError('Polling failed: $e');
    }
  }

  void _stopPollingWithError(String message) {
    _pollingTimer?.cancel();
    setState(() {
      _isPolling = false;
      _error = message;
      _failedAttempts += 1;
    });
  }

  void _cancelFromUser() {
    _complete(
      const OnboardingOneDriveAuthResult(
        outcome: OnboardingOneDriveOutcome.cancelled,
        message: 'Microsoft sign-in was cancelled by the user.',
      ),
    );
  }

  void _complete(OnboardingOneDriveAuthResult result) {
    if (!mounted || _finished) return;
    _finished = true;
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    Navigator.of(context).pop(result);
  }

  Future<void> _copyCodeToClipboard() async {
    final code = _session?.userCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied to clipboard')),
    );
  }

  Future<void> _openVerificationUrl() async {
    final url = _session?.verificationUri ?? 'https://www.microsoft.com/link';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the verification URL')),
      );
    }
  }

  Future<void> _openTroubleshootingDocs() async {
    final uri = Uri.parse(_troubleshootingDocsUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool get _showEscalatedGuidance => _failedAttempts >= _escalationThreshold;

  String _formatRemaining() {
    final session = _session;
    if (session == null) return '';
    final remaining = session.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '00:00';
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Dialog(
      backgroundColor: Colors.grey[900],
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 760,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Login with Microsoft',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.white70,
                    onPressed: _cancelFromUser,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the specific code on the browser page to complete this authorization. Once completed, it might take a few seconds to load.',
                style: TextStyle(color: Colors.grey[300]),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Text(
                        session?.userCode ?? '—',
                        style: const TextStyle(
                          letterSpacing: 2.0,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: (session == null || _loading)
                        ? null
                        : () async {
                            await _copyCodeToClipboard();
                            await _openVerificationUrl();
                          },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Copy and open'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${_formatRemaining()} before the code expires',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 16),
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    if (_isPolling)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _timedOut
                            ? 'The code expired before sign-in completed.'
                            : (_error ?? _status),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _error != null
                              ? Colors.red[300]
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_error != null && !_timedOut) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Troubleshooting before retry',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('1. Confirm the code was entered on the same Microsoft account you want to use.'),
                      const Text('2. Ensure your app registration allows public client device-code flow.'),
                      const Text('3. Retry with a fresh code if this one is stale.'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _begin,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Get new code'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _openTroubleshootingDocs,
                            icon: const Icon(Icons.help_outline, size: 16),
                            label: const Text('Open docs'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_showEscalatedGuidance) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Still stuck? Quick checklist',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('- Check tenant/client IDs in your environment file.'),
                      const Text('- Verify network access to login.microsoftonline.com.'),
                      const Text('- Confirm admin consent includes Files.Read and offline_access.'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _openTroubleshootingDocs,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open Microsoft device-code docs'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _cancelFromUser,
                  child: const Text(
                    'Return to source list',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
