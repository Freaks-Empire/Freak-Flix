import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/library_folder.dart';
import '../../services/graph_auth_service.dart';
import '../../services/metadata_service.dart';
import '../settings_widgets.dart';
import '../../screens/onedrive_folder_picker.dart';
import '../../screens/remote_folder_picker.dart';
import '../../services/remote_storage_service.dart';
import 'remote_connection_dialog.dart';

class SettingsLibrarySection extends StatefulWidget {
  const SettingsLibrarySection({Key? key}) : super(key: key);

  @override
  State<SettingsLibrarySection> createState() => _SettingsLibrarySectionState();
}

class _SettingsLibrarySectionState extends State<SettingsLibrarySection> {
  final GraphAuthService _graphAuth = GraphAuthService();
  bool _oneDriveLoading = false;
  LibraryType _pendingType = LibraryType.movies;
  final TextEditingController _nameController = TextEditingController();
  
  // Track expanded state for each library type section
  final Map<LibraryType, bool> _expandedTypes = {
    LibraryType.movies: true,
    LibraryType.tv: true,
    LibraryType.anime: true,
    LibraryType.adult: false,
    LibraryType.other: false,
  };
  
  // Track expanded state for cloud providers
  final Map<String, bool> _expandedProviders = {
    'OneDrive': true,
    'SFTP': false,
    'FTP': false,
    'WebDAV': false,
  };

  @override
  void initState() {
    super.initState();
    _graphAuth.loadFromPrefs().then((_) {
      if (mounted) setState(() {});
    });
    RemoteStorageService.instance.loadFromPrefs().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final metadata = Provider.of<MetadataService>(context, listen: false);

    // Group folders by media type
    final foldersByType = <LibraryType, List<LibraryFolder>>{};
    for (final type in LibraryType.values) {
      foldersByType[type] = library.libraryFolders.where((f) => f.type == type).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LIBRARY OVERVIEW CARDS
        if (library.libraryFolders.isNotEmpty) ...[
          _buildLibraryOverview(library),
          const SizedBox(height: 24),
        ],

        // ADD LIBRARY SECTION
        _buildAddLibrarySection(context, library, metadata),
        const SizedBox(height: 24),

        // LIBRARIES GROUPED BY TYPE
        ...LibraryType.values.where((type) {
          // Only show types that have folders or are common (movies, tv, anime)
          final hasFolders = foldersByType[type]?.isNotEmpty ?? false;
          final isCommonType = type == LibraryType.movies || 
                               type == LibraryType.tv || 
                               type == LibraryType.anime;
          return hasFolders || isCommonType;
        }).expand((type) {
          final folders = foldersByType[type] ?? [];
          return [
            _buildTypeSection(type, folders, library, metadata),
            const SizedBox(height: 16),
          ];
        }),

        const SizedBox(height: 16),

        // CLOUD ACCOUNTS
        _buildCloudAccountsSection(library, metadata),
        
        const SizedBox(height: 32),

        // MAINTENANCE
        _buildSectionHeader(
          icon: LucideIcons.wrench,
          title: 'MAINTENANCE',
          color: const Color(0xFFF97316),
        ),
        const SizedBox(height: 12),
        _buildMaintenanceSection(library, metadata, context),
      ],
    );
  }

  Widget _buildMaintenanceSection(LibraryProvider library, MetadataService metadata, BuildContext context) {
    return Column(
      children: [
        _buildSettingsTile(
          icon: LucideIcons.eraser,
          title: 'Clean Unavailable Media',
          subtitle: 'Remove metadata for files that no longer exist locally',
          onTap: () async {
             // Show confirmation
             final confirm = await showDialog<bool>(
               context: context, 
               builder: (ctx) => AlertDialog(
                 title: const Text('Clean Library?'),
                 content: const Text('This will remove all items from your library that cannot be found on this device. Cloud items are ignored.'),
                 actions: [
                   TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                   FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clean')),
                 ],
               )
             );
             
             if (confirm == true) {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Cleaning library...')),
                   );
                }
                
                final count = await library.cleanLibrary();
                
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Removed $count items.')),
                   );
                }
             }
          },
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.textMain),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      ),
    );
  }

  Widget _buildAddLibrarySection(BuildContext context, LibraryProvider library, MetadataService metadata) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.15),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.folderPlus, color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Library',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Add local folders or connect cloud storage',
                  style: TextStyle(
                    color: AppColors.textSub.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!kIsWeb)
            _buildMiniButton(
              icon: LucideIcons.hardDrive,
              label: 'Local',
              onTap: () => _pickAndAddLocalFolder(context, library, metadata),
            ),
          const SizedBox(width: 8),
          _buildMiniButton(
            icon: LucideIcons.cloud,
            label: 'Cloud',
            onTap: _graphAuth.accounts.isEmpty 
                ? _connectOneDrive 
                : () => _showCloudFolderPicker(context, library, metadata),
            isLoading: _oneDriveLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 14, color: AppColors.textSub),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isLoading = false,
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16, 
            vertical: compact ? 8 : 12
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (isLoading)
                SizedBox(
                  width: compact ? 14 : 20,
                  height: compact ? 14 : 20,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, color: AppColors.textSub, size: compact ? 16 : 20),
              SizedBox(width: compact ? 8 : 12),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMain,
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTypeSection(
    LibraryType type,
    List<LibraryFolder> folders,
    LibraryProvider library,
    MetadataService metadata,
  ) {
    final color = _getTypeColor(type);
    final stats = _getTypeStats(folders, library);
    final isExpanded = _expandedTypes[type] ?? true;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type header - Clickable to toggle expansion
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedTypes[type] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: Radius.circular(isExpanded ? 0 : 16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_typeIcon(type), size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            libraryTypeDisplayName(type),
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            folders.isEmpty 
                                ? 'No libraries added' 
                                : '${folders.length} ${folders.length == 1 ? 'library' : 'libraries'} • ${stats.count} files • ${_formatSize(stats.sizeBytes)}',
                            style: TextStyle(
                              color: AppColors.textSub.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                      color: AppColors.textSub,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Folder list - Only show if expanded
          if (isExpanded && folders.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: folders.map((f) => _buildCompactFolderTile(f, library, metadata)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactFolderTile(LibraryFolder folder, LibraryProvider library, MetadataService metadata) {
    final stats = library.getFolderStats(folder);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            folder.isCloud ? LucideIcons.cloud : LucideIcons.folder,
            size: 16,
            color: AppColors.textSub,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.displayName,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${stats.count} files • ${_formatSize(stats.sizeBytes)} • ${folder.sourceLabel}',
                  style: TextStyle(
                    color: AppColors.textSub.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            color: AppColors.textSub,
            tooltip: 'Rescan',
            visualDensity: VisualDensity.compact,
            onPressed: library.isLoading 
                ? null 
                : () => library.rescanFolder(folder, auth: _graphAuth, metadata: metadata),
          ),
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 14),
            color: AppColors.textSub,
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: () => _editLibrary(folder, library),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 14),
            color: AppColors.accent,
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmRemoveLibrary(folder, library),
          ),
        ],
      ),
    );
  }

  _FolderStats _getTypeStats(List<LibraryFolder> folders, LibraryProvider library) {
    int totalCount = 0;
    int totalSize = 0;
    for (final folder in folders) {
      final stats = library.getFolderStats(folder);
      totalCount += stats.count;
      totalSize += stats.sizeBytes;
    }
    return _FolderStats(totalCount, totalSize);
  }


  Widget _buildCloudAccountsSection(LibraryProvider library, MetadataService metadata) {
    // List of all supported cloud storage providers
    final providers = ['OneDrive', 'SFTP', 'FTP', 'WebDAV'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: LucideIcons.cloud,
          title: 'CLOUD ACCOUNTS',
          color: const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 12),
        
        // Loop through providers and build sections for each
        ...providers.map((provider) {
           return Padding(
             padding: const EdgeInsets.only(bottom: 16),
             child: _buildProviderSectionUnified(provider, library),
           );
        }),
      ],
    );
  }

  /// Unified provider section that handles both OneDrive and Remote Storage types
  Widget _buildProviderSectionUnified(String provider, LibraryProvider library) {
    final isExpanded = _expandedProviders[provider] ?? false;
    
    // Provider specific styling and account counts
    IconData icon = LucideIcons.cloud;
    Color color = AppColors.textMain;
    int accountCount = 0;
    
    switch (provider) {
      case 'OneDrive':
        icon = LucideIcons.cloud;
        color = const Color(0xFF0078D4); // Microsoft Blue
        accountCount = _graphAuth.accounts.length;
        break;
      case 'SFTP':
        icon = LucideIcons.shield;
        color = const Color(0xFF10B981); // Green
        accountCount = RemoteStorageService.instance.accountsByType(RemoteStorageType.sftp).length;
        break;
      case 'FTP':
        icon = LucideIcons.folderSync;
        color = const Color(0xFFF59E0B); // Amber
        accountCount = RemoteStorageService.instance.accountsByType(RemoteStorageType.ftp).length;
        break;
      case 'WebDAV':
        icon = LucideIcons.globe;
        color = const Color(0xFF6366F1); // Indigo
        accountCount = RemoteStorageService.instance.accountsByType(RemoteStorageType.webdav).length;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider Header - Clickable (Accordion)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedProviders[provider] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: Radius.circular(isExpanded ? 0 : 16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                provider,
                                style: const TextStyle(
                                  color: AppColors.textMain,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (provider == 'FTP') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Insecure',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            accountCount == 0 
                                ? 'Not connected' 
                                : '$accountCount ${accountCount == 1 ? 'account' : 'accounts'} connected',
                            style: TextStyle(
                              color: AppColors.textSub.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                      color: AppColors.textSub,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsible Content
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Render accounts based on provider type
                  if (provider == 'OneDrive') ...[
                    if (_graphAuth.accounts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No accounts connected yet.',
                          style: TextStyle(color: AppColors.textSub, fontSize: 13),
                        ),
                      )
                    else
                      ..._graphAuth.accounts.map((account) => _buildAccountTile(account, library)),
                  ] else ...[
                    // SFTP, FTP, WebDAV accounts
                    ..._buildRemoteAccountTiles(provider, library),
                  ],

                  const SizedBox(height: 12),
                  
                  // "Connect Account" button for this provider
                  _buildAddButton(
                    icon: LucideIcons.plusCircle,
                    label: 'Connect $provider Account',
                    onTap: () => _connectProvider(provider),
                    isLoading: provider == 'OneDrive' ? _oneDriveLoading : false,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build account tiles for remote storage providers (SFTP/FTP/WebDAV)
  List<Widget> _buildRemoteAccountTiles(String provider, LibraryProvider library) {
    RemoteStorageType? type;
    switch (provider) {
      case 'SFTP':
        type = RemoteStorageType.sftp;
        break;
      case 'FTP':
        type = RemoteStorageType.ftp;
        break;
      case 'WebDAV':
        type = RemoteStorageType.webdav;
        break;
    }
    
    if (type == null) return [];
    
    final accounts = RemoteStorageService.instance.accountsByType(type);
    if (accounts.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No accounts connected yet.',
            style: TextStyle(color: AppColors.textSub, fontSize: 13),
          ),
        ),
      ];
    }
    
    return accounts.map((account) => _buildRemoteAccountTile(account)).toList();
  }

  /// Build tile for a remote storage account
  Widget _buildRemoteAccountTile(RemoteStorageAccount account) {
    Color color;
    IconData icon;
    
    switch (account.type) {
      case RemoteStorageType.sftp:
        color = const Color(0xFF10B981);
        icon = LucideIcons.shield;
        break;
      case RemoteStorageType.ftp:
        color = const Color(0xFFF59E0B);
        icon = LucideIcons.folderSync;
        break;
      case RemoteStorageType.webdav:
        color = const Color(0xFF6366F1);
        icon = LucideIcons.globe;
        break;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${account.host}:${account.port}',
                  style: TextStyle(
                    color: AppColors.textSub.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 14),
            color: AppColors.accent,
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmRemoveRemoteAccount(account),
          ),
        ],
      ),
    );
  }

  /// Connect to a provider based on type
  void _connectProvider(String provider) {
    switch (provider) {
      case 'OneDrive':
        _connectOneDrive();
        break;
      case 'SFTP':
        _showRemoteConnectionDialog(RemoteStorageType.sftp);
        break;
      case 'FTP':
        _showRemoteConnectionDialog(RemoteStorageType.ftp);
        break;
      case 'WebDAV':
        _showRemoteConnectionDialog(RemoteStorageType.webdav);
        break;
    }
  }

  /// Show dialog for adding remote storage connection
  Future<void> _showRemoteConnectionDialog(RemoteStorageType type) async {
    final result = await showDialog<RemoteStorageAccount>(
      context: context,
      builder: (ctx) => RemoteConnectionDialog(type: type),
    );
    
    if (result != null && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${result.displayName}')),
      );
    }
  }

  /// Confirm removal of remote storage account
  Future<void> _confirmRemoveRemoteAccount(RemoteStorageAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Account?', style: TextStyle(color: AppColors.textMain)),
        content: Text(
          'Remove ${account.displayName}?\n\nThis will not delete any files, but libraries using this account will stop working.',
          style: const TextStyle(color: AppColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await RemoteStorageService.instance.removeAccount(account.id);
      if (mounted) setState(() {});
    }
  }

  Widget _buildProviderSection(String provider, List<GraphAccount> accounts, LibraryProvider library) {
    final isExpanded = _expandedProviders[provider] ?? false;
    // Provider specific styling
    IconData icon = LucideIcons.cloud;
    Color color = AppColors.textMain;
    
    if (provider == 'OneDrive') {
      icon = LucideIcons.cloud; // Or a specific Microsoft icon if available
      color = const Color(0xFF0078D4); // OneDrive Blue
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider Header - Clickable (Accordion)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedProviders[provider] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: Radius.circular(isExpanded ? 0 : 16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider,
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            accounts.isEmpty 
                                ? 'Not connected' 
                                : '${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'} connected',
                            style: TextStyle(
                              color: AppColors.textSub.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                      color: AppColors.textSub,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsible Content
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (accounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No accounts connected yet.',
                        style: TextStyle(color: AppColors.textSub, fontSize: 13),
                      ),
                    )
                  else
                    ...accounts.map((account) => _buildAccountTile(account, library)),

                  const SizedBox(height: 12),
                  
                  // "Connect Account" button for this provider
                  _buildAddButton(
                    icon: LucideIcons.plusCircle,
                    label: 'Connect $provider Account',
                    onTap: () {
                      if (provider == 'OneDrive') {
                        _connectOneDrive();
                      }
                    },
                    isLoading: provider == 'OneDrive' ? _oneDriveLoading : false,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountTile(GraphAccount account, LibraryProvider library) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0078D4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.userCheck, size: 16, color: Color(0xFF0078D4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName.isNotEmpty ? account.displayName : account.userPrincipalName,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  account.userPrincipalName,
                  style: TextStyle(
                    color: AppColors.textSub.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16),
            color: AppColors.textSub,
            tooltip: 'Remove account',
            onPressed: () => _confirmRemoveAccount(account, library),
          ),
        ],
      ),
    );
  }

  void _showCloudFolderPicker(BuildContext context, LibraryProvider library, MetadataService metadata) {
    // Collect all cloud accounts
    final oneDriveAccounts = _graphAuth.accounts;
    final remoteAccounts = RemoteStorageService.instance.accounts;
    final hasAnyAccount = oneDriveAccounts.isNotEmpty || remoteAccounts.isNotEmpty;
    
    if (!hasAnyAccount) {
      // No accounts at all - prompt to connect
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cloud accounts connected. Add one in Cloud Accounts section below.')),
      );
      return;
    }
    
    // If only one account total, go directly (no dialog needed)
    final totalAccounts = oneDriveAccounts.length + remoteAccounts.length;
    if (totalAccounts == 1) {
      if (oneDriveAccounts.length == 1) {
        _pickAndAddFolder(context, oneDriveAccounts.first.id, library, metadata);
      } else if (remoteAccounts.length == 1) {
        _pickAndAddRemoteFolder(context, remoteAccounts.first, library, metadata);
      }
      return;
    }
    
    // Show account picker for multiple accounts - build options inside builder for correct context
    showDialog(
      context: context,
      builder: (dialogContext) {
        final List<Widget> accountOptions = [];
        
        // OneDrive accounts
        for (final account in oneDriveAccounts) {
          accountOptions.add(
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext); // Use dialog context!
                _pickAndAddFolder(context, account.id, library, metadata);
              },
              child: Row(
                children: [
                  const Icon(LucideIcons.cloud, size: 16, color: Color(0xFF0078D4)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.displayName.isNotEmpty ? account.displayName : account.userPrincipalName,
                          style: const TextStyle(color: AppColors.textMain),
                        ),
                        const Text('OneDrive', style: TextStyle(color: AppColors.textSub, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // SFTP/FTP/WebDAV accounts
        for (final account in remoteAccounts) {
          IconData icon;
          Color color;
          String typeName;
          
          switch (account.type) {
            case RemoteStorageType.sftp:
              icon = LucideIcons.shield;
              color = const Color(0xFF10B981);
              typeName = 'SFTP';
              break;
            case RemoteStorageType.ftp:
              icon = LucideIcons.folderSync;
              color = const Color(0xFFF59E0B);
              typeName = 'FTP';
              break;
            case RemoteStorageType.webdav:
              icon = LucideIcons.globe;
              color = const Color(0xFF6366F1);
              typeName = 'WebDAV';
              break;
          }
          
          accountOptions.add(
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext); // Use dialog context!
                _pickAndAddRemoteFolder(context, account, library, metadata);
              },
              child: Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.displayName,
                          style: const TextStyle(color: AppColors.textMain),
                        ),
                        Text('$typeName • ${account.host}', style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return SimpleDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Select Account', style: TextStyle(color: AppColors.textMain)),
          children: accountOptions,
        );
      },
    );
  }

  /// Pick folder from SFTP/FTP/WebDAV account
  Future<void> _pickAndAddRemoteFolder(BuildContext context, RemoteStorageAccount account, LibraryProvider library, MetadataService metadata) async {
    final result = await Navigator.of(context).push<RemoteFolderSelection>(
      MaterialPageRoute(
        builder: (_) => RemoteFolderPicker(account: account),
      ),
    );
    
    if (result == null || !mounted) return;
    
    // Show library type picker dialog
    final type = await _showLibraryTypePicker(context);
    if (type == null || !mounted) return;
    
    // Create LibraryFolder with protocol-prefixed path
    // Format: sftp:accountId/path or ftp:accountId/path or webdav:accountId/path
    final folderPath = '${account.protocolPrefix}${result.path}';
    final folder = LibraryFolder(
      id: folderPath, // Use path as ID for remote folders
      path: folderPath,
      accountId: account.id, // Store the remote account ID
      type: type,
      name: result.name,
    );
    
    // Add the library folder
    await library.addLibraryFolder(folder);
    
    // Note: Remote folder scanning is not yet implemented
    // For now, just show success message
    // TODO: Implement scanRemoteFolder in LibraryProvider
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${result.name} as ${libraryTypeDisplayName(type)} library')),
      );
      setState(() {});
    }
  }
  
  /// Show dialog to pick library type
  Future<LibraryType?> _showLibraryTypePicker(BuildContext context) async {
    return showDialog<LibraryType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Select Library Type', style: TextStyle(color: AppColors.textMain)),
        children: LibraryType.values.map((type) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, type),
            child: Row(
              children: [
                Icon(_typeIcon(type), size: 18, color: _getTypeColor(type)),
                const SizedBox(width: 12),
                Text(
                  libraryTypeDisplayName(type),
                  style: const TextStyle(color: AppColors.textMain),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }


  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSub,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryOverview(LibraryProvider library) {
    // Count by type
    final typeCount = <LibraryType, int>{};
    int totalFiles = 0;
    int totalSize = 0;
    
    for (final folder in library.libraryFolders) {
      typeCount[folder.type] = (typeCount[folder.type] ?? 0) + 1;
      final stats = library.getFolderStats(folder);
      totalFiles += stats.count;
      totalSize += stats.sizeBytes;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.15),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.library, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 10),
              const Text(
                'Library Overview',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${library.libraryFolders.length} ${library.libraryFolders.length == 1 ? 'library' : 'libraries'}',
                style: TextStyle(
                  color: AppColors.textSub.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: typeCount.entries.map((e) {
              return _buildTypeChip(e.key, e.value);
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            '$totalFiles files • ${_formatSize(totalSize)}',
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(LibraryType type, int count) {
    final color = _getTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(type), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count ${libraryTypeDisplayName(type)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(LibraryFolder folder, LibraryProvider library, MetadataService metadata) {
    final stats = library.getFolderStats(folder);
    final typeColor = _getTypeColor(folder.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header with name, type badge, and actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Type icon with color
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_typeIcon(folder.type), size: 20, color: typeColor),
                ),
                const SizedBox(width: 12),
                // Name and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              folder.displayName,
                              style: const TextStyle(
                                color: AppColors.textMain,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              libraryTypeDisplayName(folder.type),
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stats.count} files • ${_formatSize(stats.sizeBytes)}',
                        style: TextStyle(
                          color: AppColors.textSub.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                _buildActionButton(
                  icon: LucideIcons.refreshCw,
                  tooltip: 'Rescan',
                  onTap: library.isLoading 
                    ? null 
                    : () => library.rescanFolder(folder, auth: _graphAuth, metadata: metadata),
                ),
                _buildActionButton(
                  icon: LucideIcons.pencil,
                  tooltip: 'Edit',
                  onTap: () => _editLibrary(folder, library),
                ),
                _buildActionButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Remove',
                  color: AppColors.accent,
                  onTap: () => _confirmRemoveLibrary(folder, library),
                ),
              ],
            ),
          ),
          // Path footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bg.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  folder.isCloud ? LucideIcons.cloud : LucideIcons.folder,
                  size: 12,
                  color: AppColors.textSub.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    folder.path.isEmpty ? '/' : folder.path,
                    style: TextStyle(
                      color: AppColors.textSub.withOpacity(0.6),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    GraphAccount account,
    List<LibraryFolder> folders,
    LibraryProvider library,
    MetadataService metadata,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.userCheck, size: 20, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName.isNotEmpty ? account.displayName : account.userPrincipalName,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        account.userPrincipalName,
                        style: TextStyle(
                          color: AppColors.textSub.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  color: AppColors.textSub,
                  tooltip: 'Remove account',
                  onPressed: () => _confirmRemoveAccount(account, library),
                ),
              ],
            ),
          ),
          
          // Folders for this account
          if (folders.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: folders.map((f) => _buildLibraryCard(f, library, metadata)).toList(),
              ),
            ),
          ],
          
          // Add folder button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildAddButton(
              icon: LucideIcons.folderPlus,
              label: 'Add Library Folder',
              compact: true,
              onTap: _oneDriveLoading 
                ? null 
                : () => _pickAndAddFolder(context, account.id, library, metadata),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String action,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textSub.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textSub.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: Text(action),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 16),
      color: color ?? AppColors.textSub,
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }



  Widget _buildMaintenanceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            )
          : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSub),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSub.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  // --- DIALOG METHODS ---

  void _editLibrary(LibraryFolder folder, LibraryProvider library) {
    _nameController.text = folder.name ?? '';
    _pendingType = folder.type;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'Edit Library',
            style: TextStyle(color: AppColors.textMain),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Library Name',
                style: TextStyle(color: AppColors.textSub, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textMain),
                decoration: InputDecoration(
                  hintText: 'e.g., My Movies',
                  hintStyle: TextStyle(color: AppColors.textSub.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Library Type',
                style: TextStyle(color: AppColors.textSub, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<LibraryType>(
                  value: _pendingType,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  underline: const SizedBox(),
                  items: [
                    _buildTypeDropdownItem(LibraryType.movies),
                    _buildTypeDropdownItem(LibraryType.tv),
                    _buildTypeDropdownItem(LibraryType.anime),
                    if (Provider.of<SettingsProvider>(context, listen: false).enableAdultContent)
                      _buildTypeDropdownItem(LibraryType.adult),
                    _buildTypeDropdownItem(LibraryType.other),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => _pendingType = val);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSub)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final updatedFolder = folder.copyWith(
                  name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
                  type: _pendingType,
                );
                library.updateLibraryFolder(updatedFolder);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<LibraryType> _buildTypeDropdownItem(LibraryType type) {
    return DropdownMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(_typeIcon(type), size: 16, color: _getTypeColor(type)),
          const SizedBox(width: 8),
          Text(
            libraryTypeDisplayName(type),
            style: const TextStyle(color: AppColors.textMain),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveLibrary(LibraryFolder folder, LibraryProvider library) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Library?', style: TextStyle(color: AppColors.textMain)),
        content: Text(
          'Remove "${folder.displayName}" from your library? Media files will not be deleted.',
          style: TextStyle(color: AppColors.textSub.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () {
              library.removeLibraryFolder(folder);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveAccount(GraphAccount account, LibraryProvider library) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Account?', style: TextStyle(color: AppColors.textMain)),
        content: Text(
          'Remove "${account.displayName}" and all associated libraries?',
          style: TextStyle(color: AppColors.textSub.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () async {
              await _graphAuth.removeAccount(account.id);
              await library.removeLibraryFoldersForAccount(account.id);
              Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showRefreshMetadataDialog(LibraryProvider library, MetadataService metadata) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Refresh Metadata', style: TextStyle(color: AppColors.textMain)),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await library.refetchAllMetadata(metadata, onlyMissing: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Metadata refresh completed')),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Scan missing only (Fast)', style: TextStyle(color: AppColors.textMain)),
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await library.refetchAllMetadata(metadata, onlyMissing: false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Metadata refresh completed')),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Rescan everything (Slow)', style: TextStyle(color: AppColors.textMain)),
            ),
          ),
        ],
      ),
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
    // 1. Select Type and Name
    final result = await _showAddLibraryDialog();
    if (result == null) return;
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
          type: result.type,
          name: result.name,
        );
        await library.addLibraryFolder(folder);
        messenger.showSnackBar(SnackBar(content: Text('Added "${folder.displayName}"')));

        // 3. Scan
        await library.rescanOneDriveFolder(auth: _graphAuth, folder: folder, metadata: metadata);
        setState(() {});
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _oneDriveLoading = false);
    }
  }

  // --- LOCAL FOLDER LOGIC ---
  Future<void> _pickAndAddLocalFolder(BuildContext context, LibraryProvider library, MetadataService metadata) async {
    final result = await _showAddLibraryDialog();
    if (result == null) return;
    
    _pendingType = result.type;
    await library.pickAndScan(metadata: metadata, forcedType: result.type);
    
    // Update the folder name if one was provided
    if (result.name != null && result.name!.isNotEmpty) {
      final folders = library.libraryFolders.where((f) => f.accountId.isEmpty);
      if (folders.isNotEmpty) {
        final lastFolder = folders.last;
        await library.updateLibraryFolder(lastFolder.copyWith(name: result.name));
      }
    }
  }

  Future<_AddLibraryResult?> _showAddLibraryDialog() async {
    _nameController.clear();
    _pendingType = LibraryType.movies;
    
    return showDialog<_AddLibraryResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            title: const Text('Add Library', style: TextStyle(color: AppColors.textMain)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Library Name (Optional)',
                  style: TextStyle(color: AppColors.textSub, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textMain),
                  decoration: InputDecoration(
                    hintText: 'e.g., My Movies, Kids TV',
                    hintStyle: TextStyle(color: AppColors.textSub.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Library Type',
                  style: TextStyle(color: AppColors.textSub, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<LibraryType>(
                    value: _pendingType,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    underline: const SizedBox(),
                    items: [
                      _buildTypeDropdownItem(LibraryType.movies),
                      _buildTypeDropdownItem(LibraryType.tv),
                      _buildTypeDropdownItem(LibraryType.anime),
                      if (Provider.of<SettingsProvider>(context, listen: false).enableAdultContent)
                        _buildTypeDropdownItem(LibraryType.adult),
                      _buildTypeDropdownItem(LibraryType.other),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => _pendingType = val);
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSub)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context, _AddLibraryResult(
                    type: _pendingType,
                    name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
                  ));
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- HELPERS ---
  IconData _typeIcon(LibraryType type) {
    switch (type) {
      case LibraryType.movies: return LucideIcons.film;
      case LibraryType.tv: return LucideIcons.tv;
      case LibraryType.anime: return LucideIcons.sparkles;
      case LibraryType.adult: return LucideIcons.lock;
      case LibraryType.other: return LucideIcons.folder;
    }
  }

  Color _getTypeColor(LibraryType type) {
    switch (type) {
      case LibraryType.movies: return const Color(0xFFF97316);
      case LibraryType.tv: return const Color(0xFF3B82F6);
      case LibraryType.anime: return const Color(0xFFEC4899);
      case LibraryType.adult: return const Color(0xFFEF4444);
      case LibraryType.other: return const Color(0xFF6B7280);
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

class _AddLibraryResult {
  final LibraryType type;
  final String? name;
  
  _AddLibraryResult({required this.type, this.name});
}

class _FolderStats {
  final int count;
  final int sizeBytes;
  
  _FolderStats(this.count, this.sizeBytes);
}
