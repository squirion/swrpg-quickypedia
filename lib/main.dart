import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/login_screen.dart';
import 'package:swrpg_quickypedia/screens/campaign_input_screen.dart';
import 'package:swrpg_quickypedia/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: SwrpgQuickypediaApp()));
}

class SwrpgQuickypediaApp extends StatelessWidget {
  const SwrpgQuickypediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SWRPG Quickypedia',
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

/// Checks auth state and routes to Login or Campaign screen.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Defer until after the first frame to avoid modifying state during build
    Future.microtask(
      () => ref.read(authStateProvider.notifier).checkStoredAuth(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authStateProvider);

    return switch (authState.status) {
      AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated => const CampaignInputScreen(),
    };
  }
}
