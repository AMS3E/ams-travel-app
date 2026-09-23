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

const authViolet = Color(0xFF5B2EE5);
const authSheet = Color(0xFFF1F1F5);
const authHeroImage = 'https://images.unsplash.com/photo-1566706546199-a93ba33ce9f7?auto=format&fit=crop&w=1000&q=70';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _password, _confirm]) {
      c.dispose();
    }
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
      // The form asks for an email, so the username starts as its first part.
      // TODO(api): drop this if the backend derives the username itself.
      final email = _email.text.trim();
      await context.read<AuthProvider>().register(email.split('@').first, email, _password.text);
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
            // Photo behind the top of the screen.
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
                      onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ),

            // Form sheet over the photo.
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
                          s.createAccountTitle,
                          style: AppText.sans(24, weight: FontWeight.w800, color: AppColors.sand900),
                        ),
                        const SizedBox(height: 8),
                        Text(s.createAccountSubtitle, style: AppText.sans(14, color: AppColors.sand500, height: 1.4)),
                        const SizedBox(height: 20),
                        FormErrorBanner(_error),
                        RoundField(
                          controller: _email,
                          hint: s.email,
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return s.fieldRequired;
                            return Validators.isEmail(v) ? null : s.invalidEmail;
                          },
                        ),
                        const SizedBox(height: 12),
                        RoundField(
                          controller: _password,
                          hint: s.password,
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) return s.fieldRequired;
                            return Validators.isStrongPassword(v) ? null : s.weakPassword;
                          },
                        ),
                        const SizedBox(height: 12),
                        RoundField(
                          controller: _confirm,
                          hint: s.confirmPassword,
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _submit,
                          validator: (v) => v != _password.text ? s.passwordsDontMatch : null,
                        ),
                        const SizedBox(height: 20),
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
                                    s.registerCta,
                                    style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(s.orRegisterWith, style: AppText.sans(12.5, color: AppColors.sand400)),
                        ),
                        const SizedBox(height: 12),
                        SocialButton(
                          label: s.signInWithGoogle,
                          onTap: () => showToast(context, '${s.signInWithGoogle} — ${s.socialSoon}'),
                          logo: const GoogleLogo(),
                        ),
                        const SizedBox(height: 10),
                        SocialButton(
                          label: s.signInWithApple,
                          dark: true,
                          onTap: () => showToast(context, '${s.signInWithApple} — ${s.socialSoon}'),
                          logo: const Icon(Icons.apple, color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.alreadyHaveAccount, style: AppText.sans(14, color: AppColors.sand700)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => context.pushReplacement(Routes.login),
                              child: Text(
                                s.login,
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

/// Pill-shaped field with a boxed icon, as in the design.
class RoundField extends StatefulWidget {
  const RoundField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<RoundField> createState() => _RoundFieldState();
}

class _RoundFieldState extends State<RoundField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color),
    );

    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      validator: widget.validator,
      style: AppText.sans(15.5, color: AppColors.sand900),
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.sand300),
            ),
            child: Icon(widget.icon, size: 19, color: AppColors.sand500),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.obscure
            ? IconButton(
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.sand400,
                  size: 21,
                ),
              )
            : null,
        border: border(AppColors.sand300),
        enabledBorder: border(AppColors.sand300),
        focusedBorder: border(authViolet),
        errorBorder: border(AppColors.sunset500),
        focusedErrorBorder: border(AppColors.sunset500),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({super.key, required this.label, required this.logo, required this.onTap, this.dark = false});

  final String label;
  final Widget logo;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: dark ? const Color(0xFF16161A) : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: dark ? Colors.transparent : authViolet.withValues(alpha: 0.5))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              logo,
              const SizedBox(width: 12),
              Text(
                label,
                style: AppText.sans(15.5, weight: FontWeight.w600, color: dark ? Colors.white : AppColors.sand900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The official Google mark, bundled in assets/images.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset('assets/images/google_logo.png', width: size, height: size);
}
