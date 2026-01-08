import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/library_folder.dart';
import '../../services/graph_auth_service.dart';
import '../../services/metadata_service.dart';
import '../settings_widgets.dart';
import '../../screens/onedrive_folder_picker.dart';

class SettingsLibrarySection extends StatefulWidget {
  const SettingsLibrarySection({Key? key}) : super(key: key);

  @override
  State<SettingsLibrarySection> createState() => _SettingsLibrarySectionState();
}

class _SettingsLibrarySectionState extends State<SettingsLibrarySection> {
  final GraphAuthService _graphAuth = GraphAuthService();
  bool _oneDriveLoading = false;
  LibraryType _pendingType = LibraryType.movies;

  @override
  void initState() {
    super.initState();
    _graphAuth.loadFromPrefs().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final metadata = Provider.of<MetadataService>(context, listen: false);

    return Column(
      children: [
        // LOCAL LIBRARY
        if (!kIsWeb)
           SettingsGroup(
            title: 'Local Folders',
            children: [
              SettingsTile(
                icon: LucideIcons.folderInput,
                title: 'Add Local Folder',
                subtitle: 'Scan directory for media',
                trailing: const Icon(LucideIcons.plus, color: AppColors.accent),
                onTap: () => _pickAndAddLocalFolder(context, library, metadata),
              ),
              if (library.isLoading && library.scanningStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(library.scanningStatus, style: const TextStyle(color: AppColors.textSub, fontSize: 12))),
                    ],
                  ),
                ),
              // List existing local folders
              ...library.libraryFolders.where((f) => f.accountId.isEmpty).map((f) => _buildFolderTile(f, library, metadata)),
            ],
          ),

        // CLOUD LIBRARY (OneDrive)
        SettingsGroup(
          title: 'OneDrive Accounts',
          children: [
            if (_graphAuth.accounts.isEmpty)
              const SettingsTile(
                icon: LucideIcons.cloudOff,
                title: 'No Accounts',
                subtitle: 'Connect OneDrive to stream content',
                trailing: SizedBox(),
              )
            else
              ..._graphAuth.accounts.expand((account) {
                final folders = library.libraryFoldersForAccount(account.id);
                return [
                  // Account Header
                  SettingsTile(
                    icon: LucideIcons.userCheck,
                    title: account.displayName.isNotEmpty ? account.displayName : account.userPrincipalName,
                    subtitle: account.userPrincipalName,
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.textSub),
                      tooltip: 'Remove account',
                      onPressed: () async {
                        await _graphAuth.removeAccount(account.id);
                        await library.removeLibraryFoldersForAccount(account.id);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                   // Folders for this account
                  ...folders.map((f) => _buildFolderTile(f, library, metadata)),
                  
                  // Add Folder Button for this account
                  SettingsTile(
                    icon: LucideIcons.folderPlus,
                    title: 'Add Library Folder',
                    subtitle: 'Select folder from OneDrive',
                    trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textSub),
                    onTap: _oneDriveLoading 
                        ? null 
                        : () => _pickAndAddFolder(context, account.id, library, metadata),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                ];
              }),

            // Add Account Button
            SettingsTile(
              icon: LucideIcons.plusCircle,
              title: 'Connect New Account',
              subtitle: 'Add another OneDrive account',
              trailing: _oneDriveLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.arrowRight, size: 18, color: AppColors.accent),
              onTap: _oneDriveLoading ? null : _connectOneDrive,
              isLast: true,
            ),
          ],
        ),

        // MAINTENANCE
        SettingsGroup(
          title: 'Maintenance',
          children: [
            SettingsTile(
              icon: LucideIcons.refreshCw,
              title: 'Rescan All Libraries',
              subtitle: 'Scan all folders for changes',
              trailing: library.isLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.play, size: 16, color: AppColors.accent),
              onTap: library.isLoading ? null : () async {
                 await library.rescanAll(auth: _graphAuth, metadata: metadata);
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan started')));
              },
            ),
             const Divider(height: 1, color: AppColors.border),
             SettingsTile(
              icon: LucideIcons.fileCheck,
              title: 'Enforce Metadata',
              subtitle: 'Rename files to match standards',
              trailing: const Icon(LucideIcons.checkSquare, size: 16, color: AppColors.textSub),
               onTap: library.isLoading ? null : () {
                  library.enforceSidecarsAndNaming();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enforcing...')));
               },
             ),
             const Divider(height: 1, color: AppColors.border),
             SettingsTile(
               icon: LucideIcons.search,
               title: 'Refresh Metadata',
               subtitle: 'Re-fetch details for all items',
               trailing: const Icon(LucideIcons.downloadCloud, size: 16, color: AppColors.textSub),
               onTap: library.isLoading ? null : () async {
                   final choice = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Refresh Metadata'),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Scan missing only (Fast)'),
                              ),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Rescan everything (Slow)'),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (choice == null) return; 
                      await library.refetchAllMetadata(metadata, onlyMissing: choice);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Metadata refresh completed')));
               },
               isLast: true,
             ),
          ],
        ),
      ],
    );
  }

  // --- ONE DRIVE CONNECTION LOGIC ---
  Future<void> _connectOneDrive() async {
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
                backgroundColor: AppColors.surface,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('1. Visit this link:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(session.verificationUri)),
                      child: Text(
                        session.verificationUri,
                        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('2. Enter this code:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SelectableText(
                      session.userCode,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
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
      messenger.showSnackBar(SnackBar(content: Text('Connected as ${user.userPrincipalName}')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('OneDrive error: $e')));
    } finally {
      if (mounted) setState(() => _oneDriveLoading = false);
    }
  }

  // --- FOLDER PICKING LOGIC ---
  Future<void> _pickAndAddFolder(
    BuildContext context,
    String accountId,
    LibraryProvider library,
    MetadataService metadata,
  ) async {
    // 1. Select Type
    final type = await showDialog<LibraryType>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Select Library Type'),
            content: DropdownButton<LibraryType>(
              value: _pendingType,
              dropdownColor: AppColors.border,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: LibraryType.movies, child: Text('Movies')),
                const DropdownMenuItem(value: LibraryType.tv, child: Text('TV Shows')),
                const DropdownMenuItem(value: LibraryType.anime, child: Text('Anime')),
                if (Provider.of<SettingsProvider>(context, listen: false).enableAdultContent)
                  const DropdownMenuItem(value: LibraryType.adult, child: Text('Adult Content')),
                const DropdownMenuItem(value: LibraryType.other, child: Text('Other')),
              ],
              onChanged: (val) {
                if (val != null) setDialogState(() => _pendingType = val);
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, _pendingType), child: const Text('Continue')),
            ],
          );
        }
      ),
    );

    if (type == null) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _oneDriveLoading = true);
    
    try {
      // 2. Pick Folder
      final selection = await Navigator.push<OneDriveFolderSelection>(
        context,
        MaterialPageRoute(builder: (_) => OneDriveFolderPicker(auth: _graphAuth, accountId: accountId)),
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
        messenger.showSnackBar(SnackBar(content: Text('Added ${_typeLabel(type)}: ${selection.path}')));

        // 3. Scan
        await library.rescanOneDriveFolder(auth: _graphAuth, folder: folder, metadata: metadata);
        setState(() {});
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _oneDriveLoading = false);
    }
      if (mounted) setState(() => _oneDriveLoading = false);
    }
  }

  // --- LOCAL FOLDER LOGIC ---
  Future<void> _pickAndAddLocalFolder(BuildContext context, LibraryProvider library, MetadataService metadata) async {
     // 1. Select Type
    final type = await showDialog<LibraryType>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Select Content Type'),
            content: DropdownButton<LibraryType>(
              value: _pendingType,
              dropdownColor: AppColors.border,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: LibraryType.movies, child: Text('Movies')),
                const DropdownMenuItem(value: LibraryType.tv, child: Text('TV Shows')),
                const DropdownMenuItem(value: LibraryType.anime, child: Text('Anime')),
                if (Provider.of<SettingsProvider>(context, listen: false).enableAdultContent)
                  const DropdownMenuItem(value: LibraryType.adult, child: Text('Adult Content')),
                const DropdownMenuItem(value: LibraryType.other, child: Text('Other')),
              ],
              onChanged: (val) {
                if (val != null) setDialogState(() => _pendingType = val);
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, _pendingType), child: const Text('Continue')),
            ],
          );
        }
      ),
    );

    if (type == null) return;
    
    // 2. Add Folder & Scan (Now using custom type)
    await library.pickAndScan(metadata: metadata, forcedType: type);
  }

  // --- HELPER WIDGETS ---
  Widget _buildFolderTile(LibraryFolder folder, LibraryProvider library, MetadataService metadata) {
    final stats = library.getFolderStats(folder);
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 16), // Indent for hierarchy
      child: Column(
        children: [
          Row(
            children: [
              // Type Icon (Clickable to change)
              PopupMenuButton<LibraryType>(
                tooltip: 'Change Content Type',
                icon: Icon(_typeIcon(folder.type), size: 16, color: AppColors.textSub),
                onSelected: (newType) => library.updateLibraryFolderType(folder.id, newType),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: LibraryType.movies, child: Row(children: [Icon(LucideIcons.film, size: 16), SizedBox(width: 8), Text('Movies')])),
                  const PopupMenuItem(value: LibraryType.tv, child: Row(children: [Icon(LucideIcons.tv, size: 16), SizedBox(width: 8), Text('TV Shows')])),
                  const PopupMenuItem(value: LibraryType.anime, child: Row(children: [Icon(LucideIcons.ghost, size: 16), SizedBox(width: 8), Text('Anime')])),
                  if (Provider.of<SettingsProvider>(context, listen: false).enableAdultContent)
                     const PopupMenuItem(value: LibraryType.adult, child: Row(children: [Icon(LucideIcons.lock, size: 16), SizedBox(width: 8), Text('Adult Content')])),
                  const PopupMenuItem(value: LibraryType.other, child: Row(children: [Icon(LucideIcons.folder, size: 16), SizedBox(width: 8), Text('Other')])),
                ],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folder.path, style: const TextStyle(color: AppColors.textMain, fontSize: 13)),
                    Text(
                      '${stats.count} files • ${_formatSize(stats.sizeBytes)}', 
                      style: const TextStyle(color: AppColors.textSub, fontSize: 11)
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16, color: AppColors.textSub),
                tooltip: 'Rescan',
                onPressed: library.isLoading
                  ? null 
                  : () => library.rescanFolder(folder, auth: _graphAuth, metadata: metadata),
              ), 
               IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                tooltip: 'Remove',
                onPressed: () => library.removeLibraryFolder(folder),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  IconData _typeIcon(LibraryType type) {
    switch (type) {
      case LibraryType.movies: return LucideIcons.film;
      case LibraryType.tv: return LucideIcons.tv;
      case LibraryType.anime: return LucideIcons.ghost; // Ghost for spirit/anime? :D
      case LibraryType.adult: return LucideIcons.lock;
      case LibraryType.other: return LucideIcons.folder;
    }
  }

  String _typeLabel(LibraryType type) {
    return type.toString().split('.').last;
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
