import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/settings_provider.dart';
import '../../services/stash_db_service.dart';
import '../../models/stash_endpoint.dart';
import '../settings_widgets.dart';

class SettingsAdvancedSection extends StatefulWidget {
  const SettingsAdvancedSection({Key? key}) : super(key: key);

  @override
  State<SettingsAdvancedSection> createState() => _SettingsAdvancedSectionState();
}

class _SettingsAdvancedSectionState extends State<SettingsAdvancedSection> {
  final StashDbService _stashService = StashDbService();
  String _version = '';

  static final _appInstallerUri = Uri.parse('https://freaks-empire.github.io/Freak-Flix/FreakFlix.appinstaller');

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
              title: 'Enable Adult Content',
              subtitle: 'Unlocks StashDB integration & adult libraries',
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
                  subtitle: 'Skip StashDB locks unless a performer match ≥50% is found',
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
                  trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textSub),
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
                          icon: const Icon(LucideIcons.edit2, size: 16, color: AppColors.textSub),
                          onPressed: () => _showEndpointDialog(context, settings, ep),
                        ),
                         IconButton(
                          icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.textSub),
                          onPressed: () => settings.removeStashEndpoint(ep.id),
                        ),
                      ],
                    ),
                  )),
                
                // ADD ENDPOINT BUTTON
                SettingsTile(
                  icon: LucideIcons.plus,
                  title: 'Add Stash Endpoint',
                  trailing: const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.accent),
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
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
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

  Future<void> _showEndpointDialog(BuildContext context, SettingsProvider settings, StashEndpoint? existing) async {
      _stashNameCtrl.text = existing?.name ?? '';
      _stashUrlCtrl.text = existing?.url ?? 'https://stashdb.org/graphql';
      _stashKeyCtrl.text = existing?.apiKey ?? '';
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
                      decoration: const InputDecoration(labelText: 'Name (e.g. Local Stash)'),
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
                        suffixIcon: IconButton(
                          icon: Icon(obscureKey ? LucideIcons.eye : LucideIcons.eyeOff),
                          onPressed: () => setDialogState(() => obscureKey = !obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                        onPressed: isTesting ? null : () async {
                            setDialogState(() => isTesting = true);
                            final ok = await _stashService.testConnection(
                              _stashKeyCtrl.text, 
                              _stashUrlCtrl.text
                            );
                            setDialogState(() => isTesting = false);
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Connected!' : 'Connection Failed'),
                                  backgroundColor: ok ? Colors.green : Colors.red,
                                )
                              );
                            }
                        }, 
                        icon: isTesting 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                     if (_stashNameCtrl.text.isEmpty || _stashUrlCtrl.text.isEmpty) return;
                     
                     final newEp = StashEndpoint(
                       id: existing?.id,
                       name: _stashNameCtrl.text,
                       url: _stashUrlCtrl.text,
                       apiKey: _stashKeyCtrl.text,
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
          }

          Future<void> _launchUpdater() async {
            if (!await launchUrl(_appInstallerUri, mode: LaunchMode.externalApplication)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to open updater')), 
                );
              }
            }
          }
        ),
      );
  }
}
