import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _verifierController = TextEditingController();
  bool _awaitingVerifier = false;

  @override
  void dispose() {
    _verifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obsidian Portal Login'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text(
                'Connect to Obsidian Portal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your Obsidian Portal account to browse your campaigns.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (authState.error != null) ...[
                Text(
                  authState.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              if (!_awaitingVerifier) ...[
                ElevatedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          await ref
                              .read(authStateProvider.notifier)
                              .startOAuthFlow();
                          if (mounted) {
                            setState(() => _awaitingVerifier = true);
                          }
                        },
                  icon: authState.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Sign in with Obsidian Portal'),
                ),
              ],
              if (_awaitingVerifier) ...[
                const Text(
                  'A browser window has opened. Authorize the app, then paste the PIN below:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _verifierController,
                    decoration: const InputDecoration(
                      labelText: 'Verification PIN',
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          ref
                              .read(authStateProvider.notifier)
                              .submitVerifier(_verifierController.text);
                        },
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _awaitingVerifier = false);
                    _verifierController.clear();
                  },
                  child: const Text('Start over'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
