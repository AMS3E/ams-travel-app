import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';
import 'auth_layout.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
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
      await context.read<AuthProvider>().forgotPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AuthLayout(
      title: s.resetPassword,
      subtitle: s.resetSubtitle,
      children: [
        if (_sent) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFE7F5EE), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.resetSent, style: AppText.sans(14, color: AppColors.sand800, height: 1.45)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: () => context.pop(), child: Text(s.backToLogin)),
        ] else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormErrorBanner(_error),
                FieldLabel(s.email),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return s.fieldRequired;
                    return Validators.isEmail(v) ? null : s.invalidEmail;
                  },
                ),
                const SizedBox(height: 24),
                SubmitButton(label: s.sendResetLink, loading: _loading, onPressed: _submit),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.pop(), child: Text(s.backToLogin)),
              ],
            ),
          ),
      ],
    );
  }
}
