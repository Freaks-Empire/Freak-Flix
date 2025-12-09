import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/graph_auth_service.dart';
import '../services/metadata_service.dart';
import 'onedrive_folder_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GraphAuthService _graphAuth = GraphAuthService();
  bool _oneDriveLoading = false;

  @override
  void initState() {
    super.initState();
    _graphAuth.loadFromPrefs().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final library = context.watch<LibraryProvider>();
    final metadata = Provider.of<MetadataService>(context, listen: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Library', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => library.pickAndScan(metadata: metadata),
              child: const Text('Select / Rescan Folder(s)'),
            ),
            const SizedBox(width: 12),
            if (settings.lastScannedFolder != null)
              Expanded(child: Text('Last: ${settings.lastScannedFolder}')),
          ],
        ),
        if (library.isLoading && library.scanningStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              library.scanningStatus,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => library.clear(),
          child: const Text('Clear Library'),
        ),
        const SizedBox(height: 24),
        Text('Cloud accounts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('OneDrive account'),
            subtitle: Text(
              _graphAuth.isConnected
                  ? 'Connected as ${_graphAuth.currentUser?.userPrincipalName ?? 'Unknown user'}'
                  : 'Not connected',
            ),
            trailing: _oneDriveLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () async {
                      setState(() => _oneDriveLoading = true);
                      try {
                        if (!_graphAuth.isConnected) {
                          final user = await _graphAuth.connectWithDeviceCode();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Connected to OneDrive as ${user.userPrincipalName}'),
                            ),
                          );
                        } else {
                          await _graphAuth.disconnect();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Disconnected from OneDrive'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('OneDrive error: $e')),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _oneDriveLoading = false);
                        }
                      }
                    },
                    child:
                        Text(_graphAuth.isConnected ? 'Disconnect' : 'Connect'),
                  ),
          ),
        ),
        if (_graphAuth.isConnected) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _oneDriveLoading
                ? null
                : () async {
                    setState(() => _oneDriveLoading = true);
                    try {
                      final selection = await Navigator.of(context)
                          .push<OneDriveFolderSelection>(
                        MaterialPageRoute(
                          builder: (_) =>
                              OneDriveFolderPicker(auth: _graphAuth),
                        ),
                      );
                      if (selection != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Selected OneDrive folder ${selection.path}')),
                        );
                        await library.scanOneDriveFolder(
                          auth: _graphAuth,
                          folderId: selection.id,
                          folderPath: selection.path,
                          metadata: metadata,
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('OneDrive error: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _oneDriveLoading = false);
                    }
                  },
            child: const Text('Choose OneDrive folder'),
          ),
        ],
        const Divider(height: 32),
        Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          title: const Text('Prefer AniList for anime'),
          value: settings.preferAniListForAnime,
          onChanged: (v) => settings.togglePreferAniList(v),
        ),
        SwitchListTile(
          title: const Text('Auto-fetch metadata after scanning'),
          value: settings.autoFetchAfterScan,
          onChanged: (v) => settings.toggleAutoFetch(v),
        ),
        SwitchListTile(
          title: const Text('Dark theme'),
          value: settings.isDarkMode,
          onChanged: (v) => settings.toggleDarkMode(v),
        ),
      ],
    );
  }
}
