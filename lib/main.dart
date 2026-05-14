import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/login_screen.dart';
import 'package:swrpg_quickypedia/screens/campaign_input_screen.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/web_drop_intercept_io.dart'
    if (dart.library.js_interop)
        'package:swrpg_quickypedia/widgets/web_drop_intercept_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  // Web only: install a capture-phase drop handler globally so the
  // unconditional null-deref in `desktop_drop_web`'s `window.ondrop`
  // never gets a chance to run. Without this, any stray browser drag
  // (e.g. one triggered by mousing over an `<img>` while dragging the
  // scrollbar thumb) crashes the app. No-op on native.
  initWebDropIntercept();
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
