import 'dart:convert';
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
        // CLOUD SYNC
        SettingsGroup(
          title: 'Cloud Sync',
          children: [
            SettingsTile(
              icon: LucideIcons.cloud,
              title: primaryAccount?.displayName ?? 'Select Backup Account',
              subtitle: primaryAccount?.userPrincipalName ?? 'Tap to configure',
              trailing: Icon(primaryAccount != null ? LucideIcons.check : LucideIcons.chevronRight, size: 16, color: AppColors.textSub),
              onTap: () => _showAccountPicker(context, settings),
            ),
             const Divider(height: 1, color: AppColors.border),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   OutlinedButton.icon(
                      icon: const Icon(LucideIcons.downloadCloud, size: 16),
                      label: const Text('Restore'),
                      onPressed: (_isProcessing || primaryAccount == null) ? null : () => _restoreFromCloud(context, settings, primaryAccount!),
                   ),
                   const SizedBox(width: 12),
                   FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                      ),
                      icon: _isProcessing 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.uploadCloud, size: 16),
                      label: const Text('Backup'),
                      onPressed: (_isProcessing || primaryAccount == null) ? null : () => _backupToCloud(context, settings, primaryAccount!),
                   ),
                 ],
               ),
             )
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
              trailing: const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.textSub),
              onTap: () => _exportLocalData(context, settings),
            ),
            const Divider(height: 1, color: AppColors.border),
             SettingsTile(
              icon: LucideIcons.fileInput,
              title: 'Import from JSON',
              subtitle: 'Restore settings from a local file',
              trailing: const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.textSub),
              onTap: () => _importLocalData(context, settings),
            ),
             const Divider(height: 1, color: AppColors.border),
             SettingsTile(
              icon: LucideIcons.clipboardList,
              title: 'Paste JSON',
              subtitle: 'Import from clipboard text',
              trailing: const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.textSub),
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
      backgroundColor: AppColors.surface,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select Backup Account', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
          ),
          if (_graphAuth.accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No accounts found. Please add one in Library settings first.', style: TextStyle(color: AppColors.textSub)),
            ),
          ..._graphAuth.accounts.map((acc) => ListTile(
            leading: const Icon(LucideIcons.cloud, color: AppColors.textSub),
            title: Text(acc.displayName, style: const TextStyle(color: AppColors.textMain)),
            subtitle: Text(acc.userPrincipalName, style: const TextStyle(color: AppColors.textSub)),
            trailing: settings.primaryBackupAccountId == acc.id 
                ? const Icon(LucideIcons.check, color: AppColors.accent) 
                : null,
            onTap: () {
              settings.setPrimaryBackupAccountId(acc.id);
              Navigator.pop(ctx);
            },
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _backupToCloud(BuildContext context, SettingsProvider settings, GraphAccount account) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Syncing to cloud...')));
      final backupService = DataBackupService(
        settings: settings,
        library: Provider.of<LibraryProvider>(context, listen: false),
        profiles: Provider.of<ProfileProvider>(context, listen: false),
      );
      final jsonStr = await backupService.createBackupJson();
      await _graphAuth.uploadFile(account.id, 'freakflix_backup.json', jsonStr);
      messenger.clearSnackBars();
      messenger.showSnackBar(const SnackBar(content: Text('✅ Backup successful')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreFromCloud(BuildContext context, SettingsProvider settings, GraphAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Restore from Cloud?'),
        content: const Text('This will overwrite all local settings and libraries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Downloading...')));
      final jsonStr = await _graphAuth.downloadFileContent(account.id, 'freakflix_backup.json');
      final backupService = DataBackupService(
        settings: settings,
        library: Provider.of<LibraryProvider>(context, listen: false),
        profiles: Provider.of<ProfileProvider>(context, listen: false),
      );
      await backupService.restoreBackup(jsonStr);
      messenger.showSnackBar(const SnackBar(content: Text('✅ Restore complete')));
     
      // Trick to refresh full app state if needed, or at least rebuild this widget
      if (mounted) setState(() {});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportLocalData(BuildContext context, SettingsProvider settings) async {
    final backupService = DataBackupService(
      settings: settings,
      library: Provider.of<LibraryProvider>(context, listen: false),
      profiles: Provider.of<ProfileProvider>(context, listen: false),
    );
    
    final jsonStr = await backupService.createBackupJson();
    final fileName = 'freakflix_backup_${DateTime.now().millisecondsSinceEpoch}.json';

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export completed')));
  }

  Future<void> _importLocalData(BuildContext context, SettingsProvider settings) async {
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
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore successful!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
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
            decoration: const InputDecoration(hintText: 'Paste JSON here...'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final jsonStr = controller.text;
                if(jsonStr.isNotEmpty) {
                   final backupService = DataBackupService(
                      settings: Provider.of<SettingsProvider>(context, listen: false), 
                      library: Provider.of<LibraryProvider>(context, listen: false),
                      profiles: Provider.of<ProfileProvider>(context, listen: false),
                   );
                   await backupService.restoreBackup(jsonStr);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored from text')));
                }
                Navigator.pop(ctx);
              }, 
              child: const Text('Import')
            ),
          ],
        )
      );
  }
}
