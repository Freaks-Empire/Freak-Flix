// lib/screens/setup_screen.dart
//
// Linear onboarding wizard with checklist progress, library type cards,
// source connection cards, adult privacy, and required final review.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/library_folder.dart';
import '../models/stash_endpoint.dart';
import '../providers/library_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../services/graph_auth_service.dart';
import '../services/metadata_service.dart';
import '../widgets/onboarding/source_connection_cards.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hasDraft = false;
  bool _isResuming = false;

  // API Step controllers
  final TextEditingController _tmdbKeyController = TextEditingController();
  final TextEditingController _stashKeyController = TextEditingController();

  // Profile Step controllers
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  int _selectedColorValue = 0xFF2196F3;

  final List<int> _colors = [
    0xFF2196F3,
    0xFFF44336,
    0xFF4CAF50,
    0xFFFFC107,
    0xFF9C27B0,
    0xFFFF5722,
    0xFF607D8B,
    0xFFE91E63,
  ];

  @override
  void initState() {
    super.initState();
    _checkForDraft();
  }

  Future<void> _checkForDraft() async {
    final onboarding = context.read<OnboardingProvider>();
    await onboarding.resumeDraft();
    if (mounted && onboarding.selectedLibraryTypes.isNotEmpty) {
      setState(() => _hasDraft = true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tmdbKeyController.dispose();
    _stashKeyController.dispose();
    _profileNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleResume() async {
    setState(() => _isResuming = true);
    final onboarding = context.read<OnboardingProvider>();
    // Resume from last step
    _goToPage(onboarding.currentStep + 1);
    setState(() {
      _isResuming = false;
      _hasDraft = false;
    });
  }

  Future<void> _handleRestart() async {
    final onboarding = context.read<OnboardingProvider>();
    await onboarding.restartFromBeginning();
    setState(() => _hasDraft = false);
  }

  Future<void> _completeSetup() async {
    final name = _profileNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name is required')),
      );
      return;
    }

    final settings = context.read<SettingsProvider>();
    final profiles = context.read<ProfileProvider>();

    if (_tmdbKeyController.text.isNotEmpty) {
      await settings.setTmdbApiKey(_tmdbKeyController.text);
    }
    if (_stashKeyController.text.isNotEmpty) {
      final ep = StashEndpoint(
        id: const Uuid().v4(),
        name: 'StashDB',
        url: 'https://stashdb.org/graphql',
        apiKey: _stashKeyController.text,
        enabled: true,
      );
      await settings.addStashEndpoint(ep);
    }

    // Apply adult content setting from onboarding
    final onboarding = context.read<OnboardingProvider>();
    await settings.toggleAdultContent(onboarding.isAdultLibrarySelected);

    final pin = _pinController.text.trim();

    await profiles.addProfile(
      name,
      'assets/logo.png',
      _selectedColorValue,
      pin: pin.isNotEmpty && pin.length == 4 ? pin : null,
    );

    await settings.completeSetup();

    if (profiles.profiles.isNotEmpty) {
      await profiles.selectProfile(profiles.profiles.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show resume prompt if draft exists
    if (_hasDraft && !_isResuming) {
      return _buildResumePrompt();
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomeStep(),
                  _buildLibraryTypesStep(),
                  _buildAdultPrivacyStep(),
                  _buildSourceConnectionsStep(),
                  _buildApiStep(),
                  _buildProfileStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildResumePrompt() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.playCircle, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Continue Setup?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'You have an incomplete onboarding draft. Would you like to continue where you left off?',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _handleRestart,
                    child: const Text('Start Over'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _handleResume,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = [
      'Welcome',
      'Library Types',
      'Adult Privacy',
      'Sources',
      'API',
      'Profile',
      'Review',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              final isActive = index <= _currentPage;
              final isCurrent = index == _currentPage;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blueAccent : Colors.grey[800],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentPage + 1} of ${steps.length}: ${steps[_currentPage]}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(LucideIcons.film, size: 80, color: Colors.blueAccent),
          SizedBox(height: 24),
          Text(
            'Welcome to Freak-Flix',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            "Let's get you set up.\nWe'll walk you through a few quick steps.",
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryTypesStep() {
    return Consumer<OnboardingProvider>(
      builder: (context, onboarding, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What do you want to add?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the library types you want to organize. You can change this later.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildLibraryTypeCard(
                    context,
                    LibraryType.movies,
                    'Movies',
                    LucideIcons.film,
                    Colors.blue,
                    onboarding,
                  ),
                  _buildLibraryTypeCard(
                    context,
                    LibraryType.tv,
                    'TV Shows',
                    LucideIcons.tv,
                    Colors.green,
                    onboarding,
                  ),
                  _buildLibraryTypeCard(
                    context,
                    LibraryType.anime,
                    'Anime',
                    LucideIcons.star,
                    Colors.purple,
                    onboarding,
                  ),
                  _buildLibraryTypeCard(
                    context,
                    LibraryType.adult,
                    'Adult',
                    LucideIcons.users,
                    Colors.orange,
                    onboarding,
                  ),
                ],
              ),
              if (onboarding.selectedLibraryTypes.isEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select at least one library type to continue.',
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLibraryTypeCard(
    BuildContext context,
    LibraryType type,
    String label,
    IconData icon,
    Color color,
    OnboardingProvider onboarding,
  ) {
    final isSelected = onboarding.selectedLibraryTypes.contains(type);

    return GestureDetector(
      onTap: () => onboarding.toggleLibraryTypeCard(type),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF3A3A3A),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.white70,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(LucideIcons.check, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdultPrivacyStep() {
    return Consumer<OnboardingProvider>(
      builder: (context, onboarding, _) {
        final isAdultSelected = onboarding.isAdultLibrarySelected;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adult Content',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.shieldAlert, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Adult content is hidden by default. Enable it only if you want access to adult libraries.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (isAdultSelected) ...[
                const Text(
                  'You selected Adult library.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: onboarding.hasAcknowledgedAdultPrivacy,
                  onChanged: (value) =>
                      onboarding.setAdultPrivacyAcknowledged(value ?? false),
                  title: const Text('I understand adult content will be visible when enabled.'),
                  subtitle: const Text('This is an explicit opt-in.'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ] else ...[
                const Text(
                  'No adult library selected.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceConnectionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect Sources (Optional)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add local folders or cloud accounts. You can skip this and add sources later.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          OnboardingSourceConnectionCards(
            library: context.read<LibraryProvider>(),
            graphAuth: context.read<GraphAuthService>(),
            metadata: context.read<MetadataService>(),
            onStatusChanged: (event) {
              // Update onboarding provider with source status
              final onboarding = context.read<OnboardingProvider>();
              // Map source type to library type for status tracking
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApiStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API Configuration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add API keys for metadata. You can add these later in Settings.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tmdbKeyController,
              decoration: const InputDecoration(
                labelText: 'TMDB API Key',
                helperText: 'Required for movie & TV metadata',
                border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.clapperboard),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _stashKeyController,
              decoration: const InputDecoration(
                labelText: 'Stash API Key (Optional)',
                helperText: 'Optional StashDB credential',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.lock),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Your Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Color(_selectedColorValue),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.user, size: 50, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _colors
                .map((c) => GestureDetector(
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
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _profileNameController,
            decoration: const InputDecoration(
              labelText: 'Profile Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(LucideIcons.user),
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
              prefixIcon: Icon(LucideIcons.lock),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Consumer<OnboardingProvider>(
      builder: (context, onboarding, _) {
        final summary = onboarding.buildReviewSummary();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review & Finish',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please review your selections before finishing.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Library Types Summary
              _buildSummarySection(
                'Library Types',
                (summary['selectedLibraryTypes'] as List).isEmpty
                    ? 'None selected'
                    : (summary['selectedLibraryTypes'] as List).join(', '),
                LucideIcons.folder,
              ),

              const SizedBox(height: 16),

              // Adult Privacy
              _buildSummarySection(
                'Adult Library',
                summary['adultPrivacy']['adultSelected'] == true
                    ? 'Enabled (acknowledged)'
                    : 'Not enabled',
                Icons.shield,
              ),

              const SizedBox(height: 16),

              // Sources - simplified
              _buildSummarySection(
                'Sources',
                'Optional - you can add sources later in Settings',
                Icons.folder,
              ),

              const SizedBox(height: 32),

              // Final Review Acknowledgement
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Before you finish:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: onboarding.hasAcknowledgedFinalReview,
                      onChanged: (value) =>
                          onboarding.setFinalReviewAcknowledged(value ?? false),
                      title: const Text(
                        'I have reviewed my selections and understand I can change these later in Settings.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummarySection(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Consumer<OnboardingProvider>(
      builder: (context, onboarding, _) {
        final isFirstPage = _currentPage == 0;
        final isLastPage = _currentPage == 6;

        // Check if can proceed
        bool canProceed = true;
        if (_currentPage == 1 && onboarding.selectedLibraryTypes.isEmpty) {
          canProceed = false;
        }
        if (_currentPage == 2 &&
            onboarding.isAdultLibrarySelected &&
            !onboarding.hasAcknowledgedAdultPrivacy) {
          canProceed = false;
        }
        if (_currentPage == 6 && !onboarding.hasAcknowledgedFinalReview) {
          canProceed = false;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isFirstPage)
                TextButton(
                  onPressed: () {
                    onboarding.goToPreviousStep();
                    _goToPage(_currentPage - 1);
                  },
                  child: const Text('Back'),
                )
              else
                const SizedBox.shrink(),
              if (!isLastPage)
                FilledButton(
                  onPressed: canProceed
                      ? () {
                          onboarding.goToNextStep();
                          _goToPage(_currentPage + 1);
                        }
                      : null,
                  child: const Text('Next'),
                )
              else
                FilledButton.icon(
                  onPressed: canProceed ? _completeSetup : null,
                  icon: const Icon(LucideIcons.check),
                  label: const Text('Finish'),
                ),
            ],
          ),
        );
      },
    );
  }
}
