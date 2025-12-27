/// lib/screens/setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/profile_provider.dart';
import '../models/user_profile.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 1: APIs
  final TextEditingController _tmdbKeyController = TextEditingController();
  final TextEditingController _stashKeyController = TextEditingController();

  // Step 2: Profile
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  int _selectedColorValue = 0xFF2196F3;
  
  // Available profile colors
  final List<int> _colors = [
    0xFF2196F3, // Blue
    0xFFF44336, // Red
    0xFF4CAF50, // Green
    0xFFFFC107, // Amber
    0xFF9C27B0, // Purple
    0xFFFF5722, // Deep Orange
    0xFF607D8B, // Blue Grey
    0xFFE91E63, // Pink
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _tmdbKeyController.dispose();
    _stashKeyController.dispose();
    _profileNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeSetup() async {
    final settings = context.read<SettingsProvider>();
    final profiles = context.read<ProfileProvider>();

    if (_tmdbKeyController.text.isNotEmpty) {
      await settings.setTmdbApiKey(_tmdbKeyController.text);
    }
    if (_stashKeyController.text.isNotEmpty) {
      await settings.setStashApiKey(_stashKeyController.text);
    }

    final name = _profileNameController.text.trim();
    if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile name is required')));
        return;
    }

    final pin = _pinController.text.trim();
    
    // Create Admin Profile
    await profiles.addProfile(
        name, 
        'assets/avatars/default.png', 
        _selectedColorValue, 
        pin: pin.isNotEmpty && pin.length == 4 ? pin : null
    );

    await settings.completeSetup();
    
    // Select the new profile automatically
    if (profiles.profiles.isNotEmpty) {
        await profiles.selectProfile(profiles.profiles.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomeStep(),
                  _buildApiStep(),
                  _buildProfileStep(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.movie_filter, size: 80, color: Colors.blueAccent),
          SizedBox(height: 24),
          Text(
            'Welcome to Freak-Flix',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Let\'s get you set up.\nWe need a few details to get started.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApiStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'API Configuration',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _tmdbKeyController,
            decoration: const InputDecoration(
              labelText: 'TMDB API Key',
              helperText: 'Required for movie & TV metadata',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.movie),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stashKeyController,
            decoration: const InputDecoration(
              labelText: 'Stash API Key (Optional)',
              helperText: 'For adult content integration',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            'Create Admin Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
           Center(
             child: Container(
               width: 100,
               height: 100,
               decoration: BoxDecoration(
                 color: Color(_selectedColorValue),
                 shape: BoxShape.circle,
               ),
               child: const Icon(Icons.person, size: 50, color: Colors.white),
             ),
           ),
           const SizedBox(height: 24),
           Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _colors.map((c) => GestureDetector(
                onTap: () => setState(() => _selectedColorValue = c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: _selectedColorValue == c 
                        ? Border.all(color: Colors.white, width: 3) 
                        : null,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _profileNameController,
              decoration: const InputDecoration(
                labelText: 'Profile Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN (Optional)',
                helperText: '4-digit lock code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: _previousPage,
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),

          if (_currentPage < 2)
            FilledButton(
              onPressed: _nextPage,
              child: const Text('Next'),
            )
          else
            FilledButton.icon(
              onPressed: _completeSetup,
              icon: const Icon(Icons.check),
              label: const Text('Finish'),
            ),
        ],
      ),
    );
  }
}
