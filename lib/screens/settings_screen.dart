// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/library_folder.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/graph_auth_service.dart';
import '../services/metadata_service.dart';
import '../services/tmdb_service.dart';
import '../services/stash_db_service.dart';
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

  late final TextEditingController _stashKeyController;
  bool _initializedStash = false;
  bool _obscureStash = true;
  bool _isTestingStash = false;
  final StashDbService _stashService = StashDbService();

  @override
  void initState() {
    super.initState();
    _tmdbController = TextEditingController();
    _stashKeyController = TextEditingController();
    _graphAuth.loadFromPrefs().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tmdbController.dispose();
    _stashKeyController.dispose();
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

    if (!_initializedStash || _stashKeyController.text != settings.stashApiKey) {
      _stashKeyController
        ..text = settings.stashApiKey
        ..selection =
            TextSelection.collapsed(offset: settings.stashApiKey.length);
      _initializedStash = true;
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
          return const Chip(
            avatar: Icon(Icons.help_outline, size: 18),
            label: Text('TMDB key: not tested'),
          );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User Profile Section
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.user;
            if (user != null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (user.name != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Name',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall),
                                    Text(user.name!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (user.email != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.email, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Email',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall),
                                    Text(user.email!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await authProvider.logout();
                            if (context.mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(height: 16),
        // Sync Section
        Consumer<SyncProvider>(
          builder: (context, sync, _) {
            if (!context.watch<AuthProvider>().isAuthenticated) return const SizedBox.shrink();
            
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync, size: 20),
                        const SizedBox(width: 8),
                        Text('Cloud Sync', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (sync.isSyncing)
                      const Row(
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Syncing...'),
                        ],
                      )
                    else if (sync.lastError != null)
                      Row(
                        children: [
                          const Icon(Icons.error, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Error: ${sync.lastError}')),
                        ],
                      )
                    else 
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(sync.lastSyncTime != null 
                              ? 'Synced at ${sync.lastSyncTime!.toLocal().toString().split('.')[0]}'
                              : 'Ready to sync'),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: sync.isSyncing ? null : () => sync.forceSync(),
                        child: const Text('Sync Now'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Library', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => library.pickAndScan(metadata: metadata),
              child: const Text('Select / Rescan Folder(s)'),
            ),
            const SizedBox(width: 12),
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
                              BuildContext? dialogContext;
                              try {
                                final user = await _graphAuth.connectWithDeviceCode(
                                  onUserCode: (session) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) {
                                        dialogContext = ctx;
                                        return AlertDialog(
                                          title: const Text('Connect Microsoft Account'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('1. Visit the link below:', style: TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              InkWell(
                                                onTap: () => launchUrl(Uri.parse(session.verificationUri)),
                                                child: Text(
                                                  session.verificationUri,
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              const Text('2. Enter this code:', style: TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      session.userCode,
                                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                            fontFamily: 'monospace',
                                                            letterSpacing: 2,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(Icons.copy),
                                                      tooltip: 'Copy Code',
                                                      onPressed: () {
                                                        Clipboard.setData(ClipboardData(text: session.userCode));
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Code copied to clipboard!')),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              const CircularProgressIndicator(),
                                              const SizedBox(height: 8),
                                              const Text('Waiting for approval...'),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              child: const Text('Cancel'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                                
                                // Close dialog on success
                                if (dialogContext != null && dialogContext!.mounted) {
                                  Navigator.of(dialogContext!).pop();
                                }

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
                            ...folders.map((f) => _buildFolderTile(f, library, metadata)),
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
        Text('Maintenance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: library.isLoading
                  ? null
                  : () async {
                      await library.rescanAll(
                        auth: _graphAuth,
                        metadata: metadata,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Library scan completed')),
                        );
                      }
                    },
              icon: const Icon(Icons.sync),
              label: const Text('Rescan All Libraries'),
            ),
            OutlinedButton.icon(
              onPressed: library.isLoading
                  ? null
                  : () async {
                      await library.refetchAllMetadata(metadata);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Metadata refresh completed')),
                        );
                      }
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh All Metadata'),
            ),
          ],
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
        const Divider(height: 32),
        ExpansionTile(
          title: Text('Advanced Settings', style: Theme.of(context).textTheme.titleLarge),
          children: [
            SwitchListTile(
              title: const Text('Enable Adult Content'),
              subtitle: const Text('Show adult content features and integrations (e.g. StashDB)'),
              value: settings.enableAdultContent,
              onChanged: (v) => settings.toggleAdultContent(v),
            ),
            if (settings.enableAdultContent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_person, size: 20),
                            const SizedBox(width: 8),
                            Text('StashDB Integration', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use StashDB.org metadata for matching file names. Does NOT provide streaming.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _stashKeyController,
                          obscureText: _obscureStash,
                          decoration: InputDecoration(
                            labelText: 'StashDB API Key',
                            hintText: 'Paste your API Key from stashdb.org',
                            border: const OutlineInputBorder(),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: _obscureStash ? 'Show key' : 'Hide key',
                                  icon: Icon(
                                      _obscureStash ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscureStash = !_obscureStash),
                                ),
                                IconButton(
                                  tooltip: 'Get API Key',
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () async {
                                    final uri = Uri.parse('https://stashdb.org/users/');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          onChanged: (value) => settings.setStashApiKey(value),
                          onSubmitted: (value) => settings.setStashApiKey(value),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _isTestingStash || settings.stashApiKey.isEmpty
                                ? null
                                : () async {
                                    setState(() => _isTestingStash = true);
                                    final ok = await _stashService.testConnection(settings.stashApiKey);
                                    if (!mounted) return;
                                    setState(() => _isTestingStash = false);
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'StashDB Connection Successful!'
                                            : 'Connection Failed. Check your API Key.'),
                                        backgroundColor: ok ? Colors.green : Colors.red,
                                      ),
                                    );
                                  },
                            icon: _isTestingStash
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Test Connection'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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
            items: [
              const DropdownMenuItem(
                  value: LibraryType.movies, child: Text('Movies')),
              const DropdownMenuItem(value: LibraryType.tv, child: Text('TV Shows')),
              const DropdownMenuItem(value: LibraryType.anime, child: Text('Anime')),
              // Only show Adult option if enabled in settings
              if (Provider.of<SettingsProvider>(context, listen: false).enableAdultContent)
                const DropdownMenuItem(value: LibraryType.adult, child: Text('Adult Content')),
              const DropdownMenuItem(value: LibraryType.other, child: Text('Other')),
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
      case LibraryType.adult:
        return const Icon(Icons.lock_outline);
      case LibraryType.other:
        return const Icon(Icons.folder);
    }
  }

  Widget _buildFolderTile(LibraryFolder folder, LibraryProvider library, MetadataService metadata) {
    final stats = library.getFolderStats(folder);
    final sizeStr = _formatSize(stats.sizeBytes);
    
    return ListTile(
      dense: true,
      leading: _typeIcon(folder.type),
      title: Text(folder.path),
      subtitle: Text(
          '${_typeLabel(folder.type)} • ${stats.count} files • $sizeStr'),
      trailing: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.autorenew_rounded, size: 18),
            label: const Text('Rescan library'),
            onPressed: library.isLoading
                ? null
                : () async {
                    await library.rescanOneDriveFolder(
                      auth: _graphAuth,
                      folder: folder,
                      metadata: metadata,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Rescanned ${_typeLabel(folder.type)} library'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refetch metadata'),
            onPressed: library.isLoading
                ? null
                : () async {
                    final scopedRoot =
                        'onedrive:${folder.accountId}${folder.path.isEmpty ? '/' : folder.path}';
                    await library.refetchMetadataForFolder(
                      scopedRoot,
                      _typeLabel(folder.type),
                      metadata,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Refreshed ${_typeLabel(folder.type)} metadata'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove folder',
            onPressed: () async {
              await library.removeLibraryFolder(folder);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  String _typeLabel(LibraryType type) {
    switch (type) {
      case LibraryType.movies:
        return 'Movies';
      case LibraryType.tv:
        return 'TV';
      case LibraryType.anime:
        return 'Anime';
      case LibraryType.adult:
        return 'Adult';
      case LibraryType.other:
      default:
        return 'Other';
    }
  }
  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
