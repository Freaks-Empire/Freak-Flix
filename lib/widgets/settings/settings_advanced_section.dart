import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/settings_provider.dart';
import '../../services/stash_db_service.dart';
import '../../models/stash_endpoint.dart';
import '../settings_widgets.dart';

class SettingsAdvancedSection extends StatefulWidget {
  const SettingsAdvancedSection({Key? key}) : super(key: key);

  @override
  State<SettingsAdvancedSection> createState() =>
      _SettingsAdvancedSectionState();
}

class _SettingsAdvancedSectionState extends State<SettingsAdvancedSection> {
  final StashDbService _stashService = StashDbService();
  String _version = '';

  // GitHub API endpoint to check latest release
  static const _githubApiUrl =
      'https://api.github.com/repos/Freaks-Empire/Freak-Flix/releases/latest';

  // Controllers for Dialog
  final _stashNameCtrl = TextEditingController();
  final _stashUrlCtrl = TextEditingController();
  final _stashKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    const gitVersion = String.fromEnvironment('GIT_VERSION');
    if (gitVersion.isNotEmpty) {
      if (mounted) setState(() => _version = gitVersion);
      return;
    }

    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = info.version);
    }
  }

  @override
  void dispose() {
    _stashNameCtrl.dispose();
    _stashUrlCtrl.dispose();
    _stashKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      children: [
        // FEATURES
        SettingsGroup(
          title: 'Features',
          children: [
            SettingsTile(
              icon: LucideIcons.lock,
              title: 'Show Adult Library (Opt-In)',
              subtitle:
                  'Off by default. Enable only when you want adult routes and tabs visible.',
              trailing: Switch.adaptive(
                value: settings.enableAdultContent,
                activeColor: AppColors.accent,
                onChanged: (v) => settings.toggleAdultContent(v),
              ),
              isLast: !settings.enableAdultContent,
            ),
            if (settings.enableAdultContent) ...[
              const Divider(height: 1, color: AppColors.border),
              SettingsTile(
                icon: LucideIcons.shieldCheck,
                title: 'Require performer match',
                subtitle:
                    'Skip StashDB locks unless a performer match ≥50% is found',
                trailing: Switch.adaptive(
                  value: settings.requirePerformerMatch,
                  activeColor: AppColors.accent,
                  onChanged: (v) => settings.toggleRequirePerformerMatch(v),
                ),
                isLast: false,
              ),
              const Divider(height: 1, color: AppColors.border),
              SettingsTile(
                icon: LucideIcons.database,
                title: 'StashDB Integration',
                subtitle: settings.stashEndpoints.isEmpty
                    ? 'No endpoints configured'
                    : '${settings.stashEndpoints.length} endpoints active',
                trailing: const Icon(LucideIcons.chevronRight,
                    size: 16, color: AppColors.textSub),
                // Expand to show list or just show dialog for "Manage"
                // For simplicity, let's keep the inline list approach from the original but cleaner
                isLast: false,
              ),
              // ENDPOINTS LIST (Inline)
              if (settings.stashEndpoints.isNotEmpty)
                ...settings.stashEndpoints.map((ep) => SettingsTile(
                      icon: LucideIcons.server,
                      title: ep.name,
                      subtitle: ep.url,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch.adaptive(
                            value: ep.enabled,
                            onChanged: (val) {
                              ep.enabled = val;
                              settings.updateStashEndpoint(ep);
                            },
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.edit2,
                                size: 16, color: AppColors.textSub),
                            onPressed: () =>
                                _showEndpointDialog(context, settings, ep),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2,
                                size: 16, color: AppColors.textSub),
                            onPressed: () =>
                                settings.removeStashEndpoint(ep.id),
                          ),
                        ],
                      ),
                    )),

              // ADD ENDPOINT BUTTON
              SettingsTile(
                icon: LucideIcons.plus,
                title: 'Add Stash Endpoint',
                trailing: const Icon(LucideIcons.arrowRight,
                    size: 16, color: AppColors.accent),
                onTap: () => _showEndpointDialog(context, settings, null),
                isLast: true,
              ),
            ],
          ],
        ),

        // ABOUT
        SettingsGroup(
          title: 'About',
          children: [
            SettingsTile(
              icon: LucideIcons.info,
              title: 'App Version',
              subtitle: _version.isEmpty ? 'Loading...' : _version,
              trailing: FilledButton.icon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _launchUpdater,
                icon: const Icon(LucideIcons.refreshCcw, size: 16),
                label: const Text('Check update'),
              ),
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showEndpointDialog(BuildContext context,
      SettingsProvider settings, StashEndpoint? existing) async {
    _stashNameCtrl.text = existing?.name ?? '';
    _stashUrlCtrl.text = existing?.url ?? 'https://stashdb.org/graphql';
    _stashKeyCtrl.clear();
    bool obscureKey = true;
    bool isTesting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(existing == null ? 'Add Endpoint' : 'Edit Endpoint'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _stashNameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Name (e.g. Local Stash)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stashUrlCtrl,
                    decoration: const InputDecoration(labelText: 'GraphQL URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stashKeyCtrl,
                    obscureText: obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      helperText: existing == null
                          ? null
                          : 'Stored securely. Leave blank to keep current key.',
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureKey ? LucideIcons.eye : LucideIcons.eyeOff),
                        onPressed: () =>
                            setDialogState(() => obscureKey = !obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: isTesting
                        ? null
                        : () async {
                            setDialogState(() => isTesting = true);
                            final keyForTest =
                                _stashKeyCtrl.text.trim().isNotEmpty
                                    ? _stashKeyCtrl.text.trim()
                                    : (existing?.apiKey ?? '');
                            final ok = await _stashService.testConnection(
                              keyForTest,
                              _stashUrlCtrl.text,
                            );
                            setDialogState(() => isTesting = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    ok ? 'Connected!' : 'Connection Failed'),
                                backgroundColor: ok ? Colors.green : Colors.red,
                              ));
                            }
                          },
                    icon: isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.zap),
                    label: const Text('Test Connection'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (_stashNameCtrl.text.isEmpty || _stashUrlCtrl.text.isEmpty)
                    return;

                  final submittedKey = _stashKeyCtrl.text.trim();
                  final endpointKey = submittedKey.isNotEmpty
                      ? submittedKey
                      : (existing?.apiKey ?? '');

                  final newEp = StashEndpoint(
                    id: existing?.id,
                    name: _stashNameCtrl.text.trim(),
                    url: _stashUrlCtrl.text.trim(),
                    apiKey: endpointKey,
                    enabled: existing?.enabled ?? true,
                  );

                  if (existing == null) {
                    settings.addStashEndpoint(newEp);
                  } else {
                    settings.updateStashEndpoint(newEp);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _launchUpdater() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Get current app version
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      // Show loading indicator
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Checking for updates...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Fetch latest release from GitHub API
      final res = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (res.statusCode != 200) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Update check failed. Please try again later.'),
        ));
        return;
      }

      final data = jsonDecode(res.body);
      final tagName = data['tag_name'] as String? ?? '';
      final releaseName = data['name'] as String? ?? 'Unknown';
      final releaseBody =
          data['body'] as String? ?? 'No release notes available.';
      final htmlUrl = data['html_url'] as String? ??
          'https://github.com/Freaks-Empire/Freak-Flix/releases';

      // Extract build number from tag (e.g., "build-123" -> 123)
      final buildMatch = RegExp(r'build-(\d+)').firstMatch(tagName);
      final remoteBuild = int.tryParse(buildMatch?.group(1) ?? '0') ?? 0;

      if (remoteBuild > currentBuild) {
        // New version available
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Row(
              children: [
                const Icon(LucideIcons.downloadCloud, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Update Available',
                        style: TextStyle(fontSize: 18))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A new version is available!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current: Build $currentBuild',
                    style: TextStyle(color: AppColors.textSub),
                  ),
                  Text(
                    'Latest: $releaseName',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Release Notes:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                              fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          releaseBody.length > 500
                              ? '${releaseBody.substring(0, 500)}...'
                              : releaseBody,
                          style:
                              TextStyle(color: AppColors.textSub, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Later'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: const Text('View Release'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // Open browser to releases page
          final uri = Uri.parse(htmlUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            messenger.showSnackBar(const SnackBar(
              content:
                  Text('Could not open browser. Please visit GitHub manually.'),
            ));
          }
        }
      } else {
        // Up to date
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.checkCircle2, color: Colors.green),
                SizedBox(width: 8),
                Text('You are on the latest version!'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update check failed: $e'),
        ),
      );
    }
  }
}
