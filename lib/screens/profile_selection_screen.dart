/// lib/screens/profile_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../models/user_profile.dart';
import 'manage_profile_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  bool isEditing = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final profiles = provider.profiles;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Image.asset('assets/logo.png', height: 40, errorBuilder: (_,__,___) => const Text('Freak-Flix', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
              });
            },
            icon: Icon(isEditing ? Icons.check : Icons.edit, color: Colors.white),
            label: Text(isEditing ? 'Done' : 'Manage', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Who's watching?",
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                ...profiles.map((p) => _buildProfileCard(context, p, provider)),
                _buildAddProfileCard(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, UserProfile profile, ProfileProvider provider) {
    return GestureDetector(
      onTap: () async {
        if (isEditing) {
          _editProfile(context, profile);
        } else {
          if (profile.pin != null && profile.pin!.isNotEmpty) {
             final bool? verified = await showDialog<bool>(
               context: context,
               builder: (_) => _PinDialog(correctPin: profile.pin!),
             );
             if (verified != true) return;
          }
          provider.selectProfile(profile.id);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: profile.color,
                  borderRadius: BorderRadius.circular(8),
                  image: profile.avatarId.startsWith('assets') 
                      ? DecorationImage(image: AssetImage(profile.avatarId), fit: BoxFit.cover)
                      : null,
                ),
                child: profile.avatarId.startsWith('assets') ? null : const Icon(Icons.person, size: 64, color: Colors.white),
              ),
              if (isEditing)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: Icon(Icons.edit, color: Colors.white, size: 32)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAddProfileCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
         _addNewProfile(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_circle, size: 64, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          const Text(
            'Add Profile',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _addNewProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageProfileScreen(profile: null)),
    );
  }

  void _editProfile(BuildContext context, UserProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ManageProfileScreen(profile: profile)),
    );
  }
}

class _PinDialog extends StatefulWidget {
  final String correctPin;

  const _PinDialog({required this.correctPin});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '****',
              errorText: _error ? 'Incorrect PIN' : null,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
            onChanged: (val) {
              setState(() => _error = false);
              if (val.length == 4) {
                if (val == widget.correctPin) {
                  Navigator.pop(context, true);
                } else {
                  setState(() {
                    _error = true;
                    _controller.clear();
                  });
                }
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
