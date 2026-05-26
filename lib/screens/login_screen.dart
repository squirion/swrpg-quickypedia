import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/link.dart';
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
  void initState() {
    super.initState();
    // Pre-fetch the OAuth request token so the authorization URL is in
    // memory before the user taps. The sign-in button below renders as
    // a `Link` (a real `<a>` on web), and iOS Safari only honours new-
    // tab navigation that's triggered synchronously from a user gesture
    // — any `await` between tap and `window.open` causes Safari to
    // silently drop the popup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).prepareAuthorizationUrl();
    });
  }

  @override
  void dispose() {
    _verifierController.dispose();
    super.dispose();
  }

  void _startOver() {
    setState(() {
      _awaitingVerifier = false;
      _verifierController.clear();
    });
    final notifier = ref.read(authStateProvider.notifier);
    notifier.clearAuthorizationUrl();
    notifier.prepareAuthorizationUrl();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final url = authState.authorizationUrl;

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
                _SignInButton(
                  url: url,
                  isLoading: authState.isLoading,
                  onTapped: () => setState(() => _awaitingVerifier = true),
                ),
              ],
              if (_awaitingVerifier) ...[
                const Text(
                  'A browser tab has opened. Authorize the app, then paste the PIN below:',
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
                  onPressed: _startOver,
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

/// Renders the "Sign in with Obsidian Portal" button.
///
/// While the authorization URL is being fetched, shows a disabled
/// button with a spinner. Once the URL is ready, wraps the button in a
/// [Link] so that on web the click is handled by a real `<a>` anchor
/// (sidestepping iOS Safari's popup blocker) and on native it falls
/// back to `launchUrl`.
class _SignInButton extends StatelessWidget {
  final String? url;
  final bool isLoading;
  final VoidCallback onTapped;

  const _SignInButton({
    required this.url,
    required this.isLoading,
    required this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Preparing sign-in…'),
      );
    }

    return Link(
      uri: Uri.parse(url!),
      target: LinkTarget.blank,
      builder: (context, followLink) {
        return ElevatedButton.icon(
          onPressed: (isLoading || followLink == null)
              ? null
              : () async {
                  await followLink();
                  onTapped();
                },
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Obsidian Portal'),
        );
      },
    );
  }
}
