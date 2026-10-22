import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/auth/keycloak.dart';
import '../../state/auth_provider.dart';
import '../../widgets/common.dart';

/// Opens Keycloak's sign-in page. True when the traveller came back signed in.
/// Keycloak's page also has the links to register and to reset a password.
Future<bool> signIn(BuildContext context) => _open(context, (auth) => auth.signIn());

/// Opens Keycloak's registration page, which ends with the six-digit email code.
Future<bool> register(BuildContext context) => _open(context, (auth) => auth.register());

Future<bool> _open(BuildContext context, Future<bool> Function(AuthProvider auth) open) async {
  final auth = context.read<AuthProvider>();
  final s = S.read(context);
  try {
    return await open(auth);
  } catch (e, st) {
    authError('sign-in failed', e, st);
    if (context.mounted) showToast(context, s.signInFailed);
    return false;
  }
}

/// What a page shows a guest: why it needs an account, and a Log in button.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: EmptyState(
      icon: icon,
      title: title,
      body: body,
      actionLabel: S.of(context).logIn,
      onAction: () => signIn(context),
    ),
  );
}

/// For actions that need an account (save, review, check in): runs [action]
/// when signed in, otherwise says why and offers to sign in.
Future<void> whenSignedIn(BuildContext context, String reason, VoidCallback action) async {
  if (context.read<AuthProvider>().isSignedIn) {
    action();
    return;
  }
  final s = S.read(context);
  showToast(context, reason, actionLabel: s.logIn, onAction: () => signIn(context));
}
