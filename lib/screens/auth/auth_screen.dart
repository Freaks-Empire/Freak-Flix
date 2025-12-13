import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _error;

  Future<void> _login({bool signup = false}) async {
    final auth = context.read<AuthProvider>();
    setState(() => _error = null);
    try {
      await auth.login();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign in',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: auth.isLoading ? null : () => _login(),
                      icon: const Icon(Icons.lock_open),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(auth.isLoading
                            ? 'Working...'
                            : 'Continue with Auth0'),
                      ),
                    ),
                  ),
                  if (auth.isLoading && !kIsWeb && Platform.isWindows)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => auth.cancelLogin(),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed:
                        auth.isLoading ? null : () => _login(signup: true),
                    child: const Text('Need an account? Sign up via Auth0'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
