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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('OneDrive accounts',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton.icon(
                      onPressed: _oneDriveLoading
                          ? null
                          : () async {
                              setState(() => _oneDriveLoading = true);
                              try {
                                final user =
                                    await _graphAuth.connectWithDeviceCode();
                                if (!mounted) return;
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Connected as ${user.userPrincipalName}'),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('OneDrive error: $e')),
                                );
                              } finally {
                                if (mounted)
                                  setState(() => _oneDriveLoading = false);
                              }
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Add account'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_oneDriveLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (_graphAuth.accounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No OneDrive accounts connected.'),
                  )
                else
                  ..._graphAuth.accounts.map(
                    (account) => RadioListTile<String>(
                      value: account.id,
                      groupValue: _graphAuth.activeAccountId,
                      title: Text(account.displayName.isNotEmpty
                          ? account.displayName
                          : account.userPrincipalName),
                      subtitle: Text(account.userPrincipalName),
                      onChanged: (value) async {
                        if (value == null) return;
                        await _graphAuth.setActiveAccount(value);
                        if (mounted) setState(() {});
                      },
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove account',
                        onPressed: () async {
                          await _graphAuth.removeAccount(account.id);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ),
                if (_graphAuth.accounts.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        await _graphAuth.disconnect();
                        if (mounted) setState(() {});
                      },
                      child: const Text('Disconnect all'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _oneDriveLoading || _graphAuth.activeAccount == null
              ? null
              : () async {
                  setState(() => _oneDriveLoading = true);
                  try {
                    final selection = await Navigator.of(context)
                        .push<OneDriveFolderSelection>(
                      MaterialPageRoute(
                        builder: (_) => OneDriveFolderPicker(auth: _graphAuth),
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
