import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/library_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/data_backup_service.dart';
import '../../services/graph_auth_service.dart';
import '../../utils/downloader/downloader.dart'; // For downloadJson on web
import '../settings_widgets.dart';

class SettingsSyncSection extends StatefulWidget {
  const SettingsSyncSection({Key? key}) : super(key: key);

  @override
  State<SettingsSyncSection> createState() => _SettingsSyncSectionState();
}

class _SettingsSyncSectionState extends State<SettingsSyncSection> {
  final GraphAuthService _graphAuth = GraphAuthService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _graphAuth.loadFromPrefs().then((_) {
      if (mounted) setState(() {});
    });
  }

  // Check if running on Windows desktop
  bool get _isWindowsDesktop => !kIsWeb && Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final primaryAccount = settings.primaryBackupAccountId == null
        ? null
        : _graphAuth.accounts.cast<GraphAccount?>().firstWhere(
              (a) => a?.id == settings.primaryBackupAccountId,
              orElse: () => null,
            );

    return Column(
      children: [
        // ONEDRIVE BACKUP (Works on all platforms via Microsoft Graph)
        SettingsGroup(
          title: 'OneDrive Backup',
          children: [
            SettingsTile(
              icon: LucideIcons.cloud,
              title: primaryAccount?.displayName ?? 'Select Backup Account',
              subtitle: primaryAccount?.userPrincipalName ?? 'Choose a OneDrive account for backups',
              trailing: Icon(
                  primaryAccount != null
                      ? LucideIcons.check
                      : LucideIcons.chevronRight,
                  size: 16,
                  color: AppColors.textSub),
              onTap: () => _showAccountPicker(context, settings),
            ),
            const Divider(height: 1, color: AppColors.border),
            if (primaryAccount != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.surface.withOpacity(0.5),
                child: Row(children: [
                  Icon(Icons.circle, size: 8, color: Colors.blue.shade400),
                  const SizedBox(width: 8),
                  Text('Backup to: ${primaryAccount.displayName}',
                      style: TextStyle(
                          color: Colors.blue.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(LucideIcons.download, size: 16),
                    label: const Text('Restore from OneDrive'),
                    onPressed: (_isProcessing || primaryAccount == null)
                        ? null
                        : () => _restoreFromOneDrive(context, settings, primaryAccount),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0078D4), // OneDrive blue
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.uploadCloud, size: 16),
                    label: const Text('Backup to OneDrive'),
                    onPressed: (_isProcessing || primaryAccount == null)
                        ? null
                        : () => _backupToOneDrive(context, settings, primaryAccount),
                  ),
                ],
              ),
            ),
            if (primaryAccount != null) ...[
                const Divider(height: 1, color: AppColors.border),
                SwitchListTile(
                   title: const Text('Auto Backup', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.normal, fontSize: 16)),
                   subtitle: const Text('Backup to OneDrive every 30 mins.', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                   tileColor: Colors.transparent, 
                   activeColor: const Color(0xFF0078D4),
                   value: settings.autoBackupEnabled,
                   onChanged: (val) => settings.toggleAutoBackup(val),
                ),
            ],
          ],
        ),

        // LOCAL BACKUP
        SettingsGroup(
          title: 'Local Backup',
          children: [
            SettingsTile(
              icon: LucideIcons.save,
              title: 'Export to JSON',
              subtitle: 'Save settings to a local file',
              trailing: const Icon(LucideIcons.arrowRight,
                  size: 16, color: AppColors.textSub),
              onTap: () => _exportLocalData(context, settings),
            ),
            const Divider(height: 1, color: AppColors.border),
            SettingsTile(
              icon: LucideIcons.fileInput,
              title: 'Import from JSON',
              subtitle: 'Restore settings from a local file',
              trailing: const Icon(LucideIcons.arrowRight,
                  size: 16, color: AppColors.textSub),
              onTap: () => _importLocalData(context, settings),
            ),
            const Divider(height: 1, color: AppColors.border),
            SettingsTile(
              icon: LucideIcons.clipboardList,
              title: 'Paste JSON',
              subtitle: 'Import from clipboard text',
              trailing: const Icon(LucideIcons.arrowRight,
                  size: 16, color: AppColors.textSub),
              onTap: () => _showImportDialog(context),
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }

  void _showAccountPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Needed for DraggableScrollableSheet
      backgroundColor: Colors.transparent, // Let sheet handle UI
      builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Select Backup Account',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain)),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (_graphAuth.accounts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                                'No accounts found. Please add one in Library settings first.',
                                style: TextStyle(color: AppColors.textSub)),
                          ),
                        ..._graphAuth.accounts.map((acc) => ListTile(
                              leading: const Icon(LucideIcons.cloud,
                                  color: AppColors.textSub),
                              title: Text(acc.displayName,
                                  style: const TextStyle(
                                      color: AppColors.textMain)),
                              subtitle: Text(acc.userPrincipalName,
                                  style: const TextStyle(
                                      color: AppColors.textSub)),
                              trailing:
                                  settings.primaryBackupAccountId == acc.id
                                      ? const Icon(LucideIcons.check,
                                          color: AppColors.accent)
                                      : null,
                              onTap: () {
                                settings.setPrimaryBackupAccountId(acc.id);
                                Navigator.pop(ctx);
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }

  Future<void> _createRestorePoint(BuildContext context,
      SettingsProvider settings, GraphAccount account) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
          const SnackBar(content: Text('Creating Restore Point...')));
      final backupService = DataBackupService(
        settings: settings,
        library: Provider.of<LibraryProvider>(context, listen: false),
        profiles: Provider.of<ProfileProvider>(context, listen: false),
      );
      // Get JSON and decode to Map
      final jsonStr = await backupService.createBackupJson();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      await SyncService()
          .createSnapshot(data, kIsWeb ? 'Web' : defaultTargetPlatform.name);

      messenger.clearSnackBars();
      messenger.showSnackBar(
          const SnackBar(content: Text('✅ Restore Point Created')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showVersionHistory(
      BuildContext context, SettingsProvider settings, GraphAccount account) {
    showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (ctx) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: SyncService().getSnapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData)
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator()));

              final list = snapshot.data!;
              if (list.isEmpty)
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No restore points found.'));

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Version History',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final date =
                            (item['savedAt'] as Timestamp?)?.toDate() ??
                                DateTime.now();
                        final device = item['deviceName'] ?? 'Unknown';
                        return ListTile(
                          leading: const Icon(LucideIcons.clock),
                          title: Text(date.toString().split('.')[0]),
                          subtitle: Text(device),
                          trailing: const Icon(LucideIcons.rotateCcw),
                          onTap: () async {
                            Navigator.pop(ctx);
                            _confirmRestore(context, item);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }));
  }

  Future<void> _confirmRestore(
      BuildContext context, Map<String, dynamic> snapshotItem) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Restore this version?'),
        content: const Text('This will overwrite current settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dataMap = snapshotItem['data'] as Map<String, dynamic>;
      // Restore via BackupService
      final backupService = DataBackupService(
        settings: context.read<SettingsProvider>(),
        library: context.read<LibraryProvider>(),
        profiles: context.read<ProfileProvider>(),
      );
      // We need to re-encode to JSON because restoreBackup expects String?
      // Or refactor restoreBackup to take Map.
      // For minimal refactor, encode back.
      await backupService.restoreBackup(jsonEncode(dataMap));

      messenger.showSnackBar(
          const SnackBar(content: Text('✅ Restored successfully')));
      if (mounted) setState(() {});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportLocalData(
      BuildContext context, SettingsProvider settings) async {
    final backupService = DataBackupService(
      settings: settings,
      library: Provider.of<LibraryProvider>(context, listen: false),
      profiles: Provider.of<ProfileProvider>(context, listen: false),
    );

    final jsonStr = await backupService.createBackupJson();
    final fileName =
        'freakflix_backup_${DateTime.now().millisecondsSinceEpoch}.json';

    if (kIsWeb) {
      await downloadJson(jsonStr, fileName);
    } else {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        await backupService.exportBackupToFile(outputFile);
      }
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Export completed')));
  }

  Future<void> _importLocalData(
      BuildContext context, SettingsProvider settings) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final backupService = DataBackupService(
          settings: settings,
          library: Provider.of<LibraryProvider>(context, listen: false),
          profiles: Provider.of<ProfileProvider>(context, listen: false),
        );

        if (kIsWeb) {
          if (file.bytes != null) {
            final jsonStr = utf8.decode(file.bytes!);
            await backupService.restoreBackup(jsonStr);
          }
        } else {
          if (file.path != null) {
            await backupService.importBackupFromFile(file.path!);
          }
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Restore successful!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _showImportDialog(BuildContext context) async {
    // (Implementation same as original but using AppColors/Widgets where applicable)
    // For brevity, using standard dialog but matching theme
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Import JSON Text'),
              content: TextField(
                controller: controller,
                maxLines: 5,
                decoration:
                    const InputDecoration(hintText: 'Paste JSON here...'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () async {
                      final jsonStr = controller.text;
                      if (jsonStr.isNotEmpty) {
                        final backupService = DataBackupService(
                          settings: Provider.of<SettingsProvider>(context,
                              listen: false),
                          library: Provider.of<LibraryProvider>(context,
                              listen: false),
                          profiles: Provider.of<ProfileProvider>(context,
                              listen: false),
                        );
                        await backupService.restoreBackup(jsonStr);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Restored from text')));
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Import')),
              ],
            ));
  }

  /// Backup data to OneDrive (for Windows)
  Future<void> _backupToOneDrive(BuildContext context, SettingsProvider settings, GraphAccount account) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Creating backup...')));
      
      final backupService = DataBackupService(
        settings: settings,
        library: Provider.of<LibraryProvider>(context, listen: false),
        profiles: Provider.of<ProfileProvider>(context, listen: false),
      );
      
      messenger.clearSnackBars();
      messenger.showSnackBar(const SnackBar(content: Text('Uploading to OneDrive...')));

      await backupService.backupToOneDrive(account.id);
      
      messenger.clearSnackBars();
      messenger.showSnackBar(const SnackBar(content: Text('✅ Backup saved to OneDrive!')));
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Restore data from OneDrive (for Windows)
  Future<void> _restoreFromOneDrive(BuildContext context, SettingsProvider settings, GraphAccount account) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Finding backups on OneDrive...')));
      
      // List backup files in OneDrive App folder
      final backups = await _graphAuth.listBackupFiles(account.id, 'freakflix_backups');
      
      messenger.clearSnackBars();
      
      if (backups.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No backups found on OneDrive')));
        return;
      }
      
      // Show picker dialog
      final selectedBackup = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SimpleDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Select Backup to Restore', style: TextStyle(color: AppColors.textMain)),
          children: backups.map((backup) {
            final name = backup['name'] as String? ?? 'Unknown';
            final size = backup['size'] as int? ?? 0;
            final sizeStr = size < 1024 * 1024 
                ? '${(size / 1024).toStringAsFixed(1)} KB'
                : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, backup),
              child: ListTile(
                leading: const Icon(LucideIcons.file, color: AppColors.textSub),
                title: Text(name, style: const TextStyle(color: AppColors.textMain)),
                subtitle: Text(sizeStr, style: const TextStyle(color: AppColors.textSub)),
              ),
            );
          }).toList(),
        ),
      );
      
      if (selectedBackup == null) return;
      
      // Download and restore
      messenger.showSnackBar(const SnackBar(content: Text('Downloading backup...')));
      
      final itemId = selectedBackup['id'] as String;
      final bytes = await _graphAuth.downloadFile(account.id, itemId);
      final jsonStr = utf8.decode(bytes);
      
      // Restore
      final backupService = DataBackupService(
        settings: settings,
        library: Provider.of<LibraryProvider>(context, listen: false),
        profiles: Provider.of<ProfileProvider>(context, listen: false),
      );
      await backupService.restoreBackup(jsonStr);
      
      messenger.clearSnackBars();
      messenger.showSnackBar(const SnackBar(content: Text('✅ Restored from OneDrive!')));
      if (mounted) setState(() {});
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}
