import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../services/tmdb_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _controller = TextEditingController();
  bool _obscureText = true;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final tmdb = context.read<TmdbService>();
    final isTesting = settings.isTestingTmdbKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Freak-Flix'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.movie_filter_outlined, size: 64, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(
                'Setup TMDB API',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Freak-Flix requires a TMDB API key to fetch metadata for your movies and TV shows.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'TMDB API Key',
                  hintText: 'Paste your v3 API key here',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: isTesting
                    ? null
                    : () async {
                        final key = _controller.text.trim();
                        if (key.isEmpty) {
                          setState(() => _errorText = 'Please enter an API key');
                          return;
                        }

                        // Temporarily set it to test
                        await settings.setTmdbApiKey(key);
                        
                        await settings.testTmdbKey((_) => tmdb.validateKey());
                        
                        if (!mounted) return;

                        if (settings.tmdbStatus == TmdbKeyStatus.valid) {
                           // Success state is handled by the parent widget checking hasTmdbKey/valid status
                           // But to be sure, we just let the reactive rebuild happen.
                        } else {
                          setState(() => _errorText = 'Invalid API key. Please check and try again.');
                          // Clear it so they have to fix it, or leave it? 
                          // If invalid, settings might keep it but status is invalid.
                          // The main app router needs to check for "valid" or at least "hasKey".
                          // User requested "force user to feed api key". 
                          // Ideally verification passes.
                        }
                      },
                child: isTesting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verify & Continue'),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('https://www.themoviedb.org/settings/api');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Get API Key'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
