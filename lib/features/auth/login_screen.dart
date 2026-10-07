import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';
import 'auth_layout.dart';
import 'register_screen.dart';

/// Same frame as Create Account, with the email and password fields only.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_identifier.text, _password.text);
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go(Routes.profile);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: authSheet,
        body: Stack(
          children: [
            SizedBox(
              height: 250,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const AppImage(authHeroImage),
                  const DecoratedBox(decoration: BoxDecoration(color: Color(0xB3101C66))),
                  Positioned(
                    left: 10,
                    top: top + 4,
                    child: IconButton(
                      onPressed: () => context.go(Routes.welcome),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 196),
              child: Container(
                decoration: const BoxDecoration(
                  color: authSheet,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.sand300,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          s.loginTitle,
                          style: AppText.sans(24, weight: FontWeight.w800, color: AppColors.sand900),
                        ),
                        const SizedBox(height: 8),
                        Text(s.loginSubtitle2, style: AppText.sans(14, color: AppColors.sand500, height: 1.4)),
                        const SizedBox(height: 20),
                        FormErrorBanner(_error),
                        RoundField(
                          controller: _identifier,
                          hint: s.usernameOrEmail,
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          validator: (v) => (v?.trim().isEmpty ?? true) ? s.fieldRequired : null,
                        ),
                        const SizedBox(height: 12),
                        RoundField(
                          controller: _password,
                          hint: s.password,
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _submit,
                          validator: (v) => (v?.isEmpty ?? true) ? s.fieldRequired : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push(Routes.forgotPassword),
                            child: Text(
                              s.forgotPassword,
                              style: AppText.sans(13.5, weight: FontWeight.w600, color: authViolet),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: authViolet,
                              minimumSize: const Size(0, 54),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                  )
                                : Text(
                                    s.login,
                                    style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(s.orLoginWith, style: AppText.sans(12.5, color: AppColors.sand400)),
                        ),
                        const SizedBox(height: 12),
                        SocialButton(
                          label: s.signInWithGoogle,
                          onTap: () => showToast(context, '${s.signInWithGoogle} — ${s.socialSoon}'),
                          logo: const GoogleLogo(),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.noAccountYet, style: AppText.sans(14, color: AppColors.sand700)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => context.pushReplacement(Routes.register),
                              child: Text(
                                s.registerCta,
                                style: AppText.sans(14, weight: FontWeight.w700, color: authViolet),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
