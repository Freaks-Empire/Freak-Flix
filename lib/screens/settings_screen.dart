// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/library_folder.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/graph_auth_service.dart';
import '../services/metadata_service.dart';
import '../services/tmdb_service.dart';
import 'onedrive_folder_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GraphAuthService _graphAuth = GraphAuthService();
  bool _oneDriveLoading = false;
  LibraryType _pendingType = LibraryType.movies;
  late final TextEditingController _tmdbController;
  bool _initializedTmdb = false;
  bool _obscureTmdb = true;

  @override
  void initState() {
    super.initState();
    _tmdbController = TextEditingController();
    _graphAuth.loadFromPrefs().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tmdbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final library = context.watch<LibraryProvider>();
    final metadata = Provider.of<MetadataService>(context, listen: false);
    final tmdb = Provider.of<TmdbService>(context, listen: false);

    if (!_initializedTmdb || _tmdbController.text != settings.tmdbApiKey) {
      _tmdbController
        ..text = settings.tmdbApiKey
        ..selection =
            TextSelection.collapsed(offset: settings.tmdbApiKey.length);
      _initializedTmdb = true;
    }

    Widget _tmdbStatusChip() {
      switch (settings.tmdbStatus) {
        case TmdbKeyStatus.valid:
          return const Chip(
            avatar: Icon(Icons.check_circle, size: 18),
            label: Text('TMDB key: valid'),
          );
        case TmdbKeyStatus.invalid:
          return const Chip(
            avatar: Icon(Icons.error, size: 18),
            label: Text('TMDB key: invalid'),
          );
        case TmdbKeyStatus.unknown:
        default:
          return const Chip(
            avatar: Icon(Icons.help_outline, size: 18),
            label: Text('TMDB key: not tested'),
          );
      }
    }

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
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(library.scanningStatus)),
              ],
            ),
          ),
        const SizedBox(height: 16),
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
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _oneDriveLoading = true);
                              try {
                                final user =
                                    await _graphAuth.connectWithDeviceCode();
                                if (!mounted) return;
                                setState(() {});
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Connected as ${user.userPrincipalName}'),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
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
                if (_oneDriveLoading)
                  const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 8),
                if (_graphAuth.accounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No OneDrive accounts connected.'),
                  )
                else
                  ..._graphAuth.accounts.map(
                    (account) {
                      final folders =
                          library.libraryFoldersForAccount(account.id);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(account.displayName.isNotEmpty
                                ? account.displayName
                                : account.userPrincipalName),
                            subtitle: Text(account.userPrincipalName),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove account',
                              onPressed: () async {
                                await _graphAuth.removeAccount(account.id);
                                await library
                                    .removeLibraryFoldersForAccount(account.id);
                                if (mounted) setState(() {});
                              },
                            ),
                          ),
                          if (folders.isNotEmpty)
                            ...folders.map(
                              (folder) => ListTile(
                                dense: true,
                                leading: _typeIcon(folder.type),
                                title: Text(folder.path),
                                subtitle: Text(_typeLabel(folder.type)),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.autorenew_rounded,
                                          size: 18),
                                      label: const Text('Rescan library'),
                                      onPressed: library.isLoading
                                          ? null
                                          : () async {
                                              await library
                                                  .rescanOneDriveFolder(
                                                auth: _graphAuth,
                                                folder: folder,
                                                metadata: metadata,
                                              );

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Rescanned ${_typeLabel(folder.type)} library'),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    duration: const Duration(
                                                        seconds: 2),
                                                  ),
                                                );
                                              }
                                            },
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      icon: const Icon(Icons.refresh_rounded,
                                          size: 18),
                                      label: const Text('Refetch metadata'),
                                      onPressed: library.isLoading
                                          ? null
                                          : () async {
                                              final scopedRoot =
                                                  'onedrive:${folder.accountId}${folder.path.isEmpty ? '/' : folder.path}';
                                              await library
                                                  .refetchMetadataForFolder(
                                                scopedRoot,
                                                _typeLabel(folder.type),
                                                metadata,
                                              );

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Refreshed ${_typeLabel(folder.type)} metadata'),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    duration: const Duration(
                                                        seconds: 2),
                                                  ),
                                                );
                                              }
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Remove folder',
                                      onPressed: () async {
                                        await library
                                            .removeLibraryFolder(folder);
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: _oneDriveLoading
                                  ? null
                                  : () async {
                                      await _pickAndAddFolder(context,
                                          account.id, library, metadata);
                                    },
                              child: const Text('Add library folder'),
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 32),
        Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Metadata', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _tmdbController,
          obscureText: _obscureTmdb,
          decoration: InputDecoration(
            labelText: 'TMDB API key',
            hintText: 'Paste your TMDB v3 API key',
            helperText:
                'Create a free account at themoviedb.org → Settings → API → v3 key.',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _obscureTmdb ? 'Show key' : 'Hide key',
                  icon: Icon(
                      _obscureTmdb ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureTmdb = !_obscureTmdb),
                ),
                IconButton(
                  tooltip: 'Open TMDB API page',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () async {
                    final uri =
                        Uri.parse('https://www.themoviedb.org/settings/api');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ),
          onChanged: (value) => settings.setTmdbApiKey(value),
          onSubmitted: (value) => settings.setTmdbApiKey(value),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _tmdbStatusChip(),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: settings.isTestingTmdbKey
                  ? null
                  : () async {
                      await settings.testTmdbKey((_) => tmdb.validateKey());
                      if (!mounted) return;
                      final ok = settings.tmdbStatus == TmdbKeyStatus.valid;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'TMDB key looks good!'
                              : 'TMDB key failed. Check it and try again.'),
                        ),
                      );
                    },
              icon: settings.isTestingTmdbKey
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt),
              label: const Text('Test key'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'This product uses the TMDB API but is not endorsed or certified by TMDB.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
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

  Future<void> _pickAndAddFolder(
    BuildContext context,
    String accountId,
    LibraryProvider library,
    MetadataService metadata,
  ) async {
    final type = await showDialog<LibraryType>(
      context: context,
      builder: (context) {
        var localType = _pendingType;
        return AlertDialog(
          title: const Text('Select library type'),
          content: DropdownButton<LibraryType>(
            value: localType,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                  value: LibraryType.movies, child: Text('Movies')),
              DropdownMenuItem(value: LibraryType.tv, child: Text('TV Shows')),
              DropdownMenuItem(value: LibraryType.anime, child: Text('Anime')),
              DropdownMenuItem(value: LibraryType.other, child: Text('Other')),
            ],
            onChanged: (val) {
              if (val != null) {
                localType = val;
                setState(() => _pendingType = val);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(localType),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (type == null) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _oneDriveLoading = true);
    try {
      final selection = await navigator.push<OneDriveFolderSelection>(
        MaterialPageRoute(
          builder: (_) =>
              OneDriveFolderPicker(auth: _graphAuth, accountId: accountId),
        ),
      );
      if (!mounted) return;
      if (selection != null) {
        final folder = LibraryFolder(
          id: selection.id,
          path: selection.path,
          accountId: accountId,
          type: type,
        );
        await library.addLibraryFolder(folder);
        messenger.showSnackBar(
          SnackBar(
              content: Text('Added ${_typeLabel(type)}: ${selection.path}')),
        );
        await library.scanLibraryFolder(
          auth: _graphAuth,
          folder: folder,
          metadata: metadata,
        );
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('OneDrive error: $e')),
      );
    } finally {
      if (mounted) setState(() => _oneDriveLoading = false);
    }
  }

  Icon _typeIcon(LibraryType type) {
    switch (type) {
      case LibraryType.movies:
        return const Icon(Icons.movie_creation_outlined);
      case LibraryType.tv:
        return const Icon(Icons.tv);
      case LibraryType.anime:
        return const Icon(Icons.animation_outlined);
      case LibraryType.other:
      default:
        return const Icon(Icons.folder);
    }
  }

  String _typeLabel(LibraryType type) {
    switch (type) {
      case LibraryType.movies:
        return 'Movies';
      case LibraryType.tv:
        return 'TV';
      case LibraryType.anime:
        return 'Anime';
      case LibraryType.other:
      default:
        return 'Other';
    }
  }
}
