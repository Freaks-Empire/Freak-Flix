import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/library_provider.dart';
import '../services/metadata_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => library.clear(),
          child: const Text('Clear Library'),
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