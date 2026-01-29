/// lib/screens/manage_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/profile_provider.dart';
import '../providers/library_provider.dart';
import '../models/user_profile.dart';
import '../models/library_folder.dart';

class ManageProfileScreen extends StatefulWidget {
  final UserProfile? profile;

  const ManageProfileScreen({super.key, this.profile});

  @override
  State<ManageProfileScreen> createState() => _ManageProfileScreenState();
}

class _ManageProfileScreenState extends State<ManageProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  late int _selectedColor;
  late String _avatarId;
  List<String>? _allowedFolderIds; // Null means all

  final List<int> _colors = [
    Colors.blue.value,
    Colors.red.value,
    Colors.green.value,
    Colors.orange.value,
    Colors.purple.value,
    Colors.pink.value,
    Colors.teal.value,
    Colors.yellow.value,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _pinController = TextEditingController(text: widget.profile?.pin ?? '');
    _selectedColor = widget.profile?.colorValue ?? _colors[0];
    _avatarId = widget.profile?.avatarId ?? 'assets/logo.png';
    // Copy list to avoid mutation issues
    _allowedFolderIds = widget.profile?.allowedFolderIds != null
        ? List.from(widget.profile!.allowedFolderIds!)
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryProvider>();
    final folders = library.libraryFolders;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? 'Add Profile' : 'Edit Profile'),
        actions: [
          if (widget.profile != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar & Name
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(_selectedColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Profile Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Profile PIN (Optional)',
                helperText: '4-digit code to lock profile',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            
            // Color Picker
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Profile Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((c) => GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: _selectedColor == c 
                        ? Border.all(color: Colors.white, width: 4) 
                        : null,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),

            // Access Control
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Allowed Libraries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Access All Libraries'),
              value: _allowedFolderIds == null,
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _allowedFolderIds = null; // Access all
                  } else {
                    _allowedFolderIds = []; // Start empty
                  }
                });
              },
            ),
            const Divider(),
            if (_allowedFolderIds != null) ...[
                if (folders.isEmpty)
                   const Padding(
                     padding: EdgeInsets.all(16.0),
                     child: Text("No libraries found. Add libraries in Settings first."),
                   ),
                ...folders.map((f) {
                  final isChecked = _allowedFolderIds!.contains(f.id);
                  return CheckboxListTile(
                    title: Text(f.displayName),
                    subtitle: Text(
                      '${libraryTypeDisplayName(f.type)} • ${f.isCloud ? 'OneDrive' : 'Local'}',
                      style: TextStyle(
                        color: _getTypeColor(f.type),
                        fontSize: 12,
                      ),
                    ),
                    secondary: Icon(
                      _getTypeIcon(f.type),
                      color: _getTypeColor(f.type),
                      size: 20,
                    ),
                    value: isChecked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _allowedFolderIds!.add(f.id);
                        } else {
                          _allowedFolderIds!.remove(f.id);
                        }
                      });
                    },
                  );
                }),
            ],

            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.save),
              label: const Text('Save Profile'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
            ),

            if (widget.profile != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              ListTile(
                title: const Text('Import Legacy History'),
                subtitle: const Text('Import watched status from old database versions.'),
                leading: const Icon(LucideIcons.history),
                onTap: _importLegacyHistory,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _saveProfile() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    
    final pin = _pinController.text.trim();
    if (pin.isNotEmpty && pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN must be 4 digits or empty.'))
      );
      return;
    }
    final validatedPin = pin.isEmpty ? null : pin;

    final provider = context.read<ProfileProvider>();
    
    if (widget.profile == null) {
      provider.addProfile(
        name,
        _avatarId,
        _selectedColor,
        allowedFolderIds: _allowedFolderIds,
        pin: validatedPin,
      );
    } else {
      final updated = widget.profile!.copyWith(
        name: name,
        colorValue: _selectedColor,
        avatarId: _avatarId,
        allowedFolderIds: _allowedFolderIds,
        pin: validatedPin,
        clearPin: validatedPin == null,
      );
      provider.updateProfile(updated);
    }
    
    Navigator.of(context).pop();
  }

  void _deleteProfile() async {
     final provider = context.read<ProfileProvider>();
     if (provider.profiles.length <= 1) {
         ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Cannot delete the last profile.'))
         );
         return;
     }

     final confirm = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Delete Profile?'),
         content: Text('Permanently delete ${widget.profile!.name}? History will be lost.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

     if (confirm == true) {
       await provider.deleteProfile(widget.profile!.id);
       if (context.mounted) Navigator.pop(context);
     }
  }

  Future<void> _importLegacyHistory() async {
    final library = context.read<LibraryProvider>();
    final profile = context.read<ProfileProvider>();
    
    // 1. Extract
    final legacyData = library.extractLegacyHistory();
    if (legacyData.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No legacy history found to import.')),
      );
      return;
    }

    // 2. Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Legacy History?'),
        content: Text(
          'Found ${legacyData.length} watched items in the library database.\n'
          'This will merge them into this profile\'s history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 3. Import
    await profile.importUserData(legacyData);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully imported ${legacyData.length} items.')),
    );
  }

  IconData _getTypeIcon(LibraryType type) {
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
}
