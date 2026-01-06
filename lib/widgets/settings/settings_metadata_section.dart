import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/settings_provider.dart';
import '../../services/tmdb_service.dart';
import '../settings_widgets.dart';

class SettingsMetadataSection extends StatefulWidget {
  const SettingsMetadataSection({Key? key}) : super(key: key);

  @override
  State<SettingsMetadataSection> createState() => _SettingsMetadataSectionState();
}

class _SettingsMetadataSectionState extends State<SettingsMetadataSection> {
  late final TextEditingController _tmdbController;
  bool _initializedTmdb = false;
  bool _obscureTmdb = true;

  @override
  void initState() {
    super.initState();
    _tmdbController = TextEditingController();
  }

  @override
  void dispose() {
    _tmdbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final tmdb = Provider.of<TmdbService>(context, listen: false);

    if (!_initializedTmdb || _tmdbController.text != settings.tmdbApiKey) {
      _tmdbController
        ..text = settings.tmdbApiKey
        ..selection = TextSelection.collapsed(offset: settings.tmdbApiKey.length);
      _initializedTmdb = true;
    }

    return Column(
      children: [
        SettingsGroup(
          title: 'Primary Provider',
          children: [
            // Custom Tile for TextField to match the look
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
               child: Row(
                 children: [
                   const Icon(LucideIcons.key, color: AppColors.textSub, size: 20),
                   const SizedBox(width: 16),
                   Expanded(
                     child: TextField(
                       controller: _tmdbController,
                       obscureText: _obscureTmdb,
                       decoration: const InputDecoration(
                         labelText: 'TMDB API Key',
                         labelStyle: TextStyle(color: AppColors.textSub),
                         border: InputBorder.none,
                         focusedBorder: InputBorder.none,
                         contentPadding: EdgeInsets.zero,
                       ),
                       style: const TextStyle(color: AppColors.textMain),
                       onChanged: (value) => settings.setTmdbApiKey(value),
                       onSubmitted: (value) => settings.setTmdbApiKey(value),
                     ),
                   ),
                   IconButton(
                     icon: Icon(_obscureTmdb ? LucideIcons.eye : LucideIcons.eyeOff, color: AppColors.textSub, size: 18),
                     onPressed: () => setState(() => _obscureTmdb = !_obscureTmdb),
                   ),
                 ],
               ),
             ),
            const Divider(height: 1, color: AppColors.border),
            SettingsTile(
              icon: LucideIcons.checkCircle,
              title: 'Test API Connection',
              subtitle: _getStatusText(settings.tmdbStatus),
              trailing: settings.isTestingTmdbKey
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(settings.tmdbStatus).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TEST',
                         style: TextStyle(color: _getStatusColor(settings.tmdbStatus), fontSize: 11, fontWeight: FontWeight.bold)
                      ),
                    ),
              onTap: settings.isTestingTmdbKey 
                ? null 
                : () async {
                    await settings.testTmdbKey((_) => tmdb.validateKey());
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(settings.tmdbStatus == TmdbKeyStatus.valid ? 'TMDB Success!' : 'TMDB Failed')),
                    );
                  },
              isLast: false,
            ),
             const Divider(height: 1, color: AppColors.border),
             SettingsTile(
               icon: LucideIcons.externalLink,
               title: 'Get API Key',
               subtitle: 'themoviedb.org/settings/api',
               trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textSub, size: 16),
               isLast: true,
               onTap: () => launchUrl(Uri.parse('https://www.themoviedb.org/settings/api'), mode: LaunchMode.externalApplication),
             ),
          ],
        ),

        SettingsGroup(
          title: 'Automation',
          children: [
            SettingsTile(
              icon: LucideIcons.downloadCloud,
              title: 'Auto-fetch metadata',
              subtitle: 'Fetch data immediately after scanning',
              trailing: Switch.adaptive(
                value: settings.autoFetchAfterScan,
                activeColor: AppColors.accent,
                onChanged: (v) => settings.toggleAutoFetch(v),
              ),
              isLast: false,
            ),
            const Divider(height: 1, color: AppColors.border),
            SettingsTile(
              icon: LucideIcons.cat, // Or Rabbit/Clapperboard? Cat for "Ani"List seems fun or just standard
              title: 'Prefer AniList for Anime',
              subtitle: 'Overrides TMDB for Japanese content',
              trailing: Switch.adaptive(
                value: settings.preferAniListForAnime,
                activeColor: AppColors.accent,
                onChanged: (v) => settings.togglePreferAniList(v),
              ),
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }

  String _getStatusText(TmdbKeyStatus status) {
    switch (status) {
      case TmdbKeyStatus.valid: return 'Valid';
      case TmdbKeyStatus.invalid: return 'Invalid';
      case TmdbKeyStatus.unknown: return 'Not Checked';
    }
  }

  Color _getStatusColor(TmdbKeyStatus status) {
    switch (status) {
      case TmdbKeyStatus.valid: return Colors.green;
      case TmdbKeyStatus.invalid: return Colors.red;
      case TmdbKeyStatus.unknown: return Colors.grey;
    }
  }
}
