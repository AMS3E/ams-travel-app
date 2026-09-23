import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/auth_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

/// The account form: name, contact, where you are, and a new password.
class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _province;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _filled = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Starts from what the account already holds.
  void _fillOnce(AppUser? user) {
    if (_filled || user == null) return;
    _filled = true;
    final parts = user.username.split(RegExp(r'[ .]'));
    _first.text = user.firstName ?? parts.first;
    _last.text = user.lastName ?? (parts.length > 1 ? parts.last : '');
    _email.text = user.email;
    _phone.text = user.phone ?? '';
    _province = user.location?.split(',').first.trim();
  }

  Future<void> _save() async {
    final s = S.read(context);
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      context.push(Routes.login);
      return;
    }
    if (_password.text.isNotEmpty && _password.text != _confirm.text) {
      showToast(context, s.passwordsDoNotMatch);
      return;
    }
    await auth.updateUser(
      user.copyWith(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        location: _province == null ? null : '$_province, Cambodia',
      ),
    );
    if (!mounted) return;
    // TODO(api): a new password needs `PATCH /me/password` behind it.
    showToast(context, _password.text.isEmpty ? s.accountSaved : s.passwordLater);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = context.watch<AuthProvider>().user;
    _fillOnce(user);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.accountInfo, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: AsyncView<List<Province>>(
        load: context.read<TravelRepository>().getProvinces,
        builder: (context, provinces, _) => ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            _Field(controller: _first, hint: s.firstName),
            _Field(controller: _last, hint: s.lastName),
            _Field(controller: _email, hint: s.email, keyboard: TextInputType.emailAddress),

            // Phone, with the country code fixed in front of it.
            _Shell(
              child: Row(
                children: [
                  Text('+855', style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand900)),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 22, color: AppColors.sand200),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: _bare('12 345 6789'),
                    ),
                  ),
                ],
              ),
            ),

            _Shell(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _province,
                  isExpanded: true,
                  hint: Text(s.provinceOrCapital, style: AppText.sans(15, color: AppColors.sand400)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.sand500),
                  items: [
                    for (final p in provinces)
                      DropdownMenuItem(value: p.name, child: Text(p.name, style: AppText.sans(15))),
                  ],
                  onChanged: (v) => setState(() => _province = v),
                ),
              ),
            ),

            _Field(
              controller: _password,
              hint: s.password,
              obscure: !_showPassword,
              trailing: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.sand500,
                ),
              ),
            ),
            _Field(
              controller: _confirm,
              hint: s.reEnterPassword,
              obscure: !_showConfirm,
              trailing: IconButton(
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
                icon: Icon(
                  _showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.sand500,
                ),
              ),
            ),

            const SizedBox(height: 26),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand600,
                minimumSize: const Size(0, 54),
              ),
              onPressed: _save,
              child: Text(s.save, style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's fields are filled and outlined by default; inside these pills
/// they have to be plain.
InputDecoration _bare(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: AppText.sans(15, color: AppColors.sand400),
  filled: false,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(vertical: 12),
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
);

/// One rounded field.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.obscure = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              obscureText: obscure,
              decoration: _bare(hint),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The rounded outline every row on this page sits in.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.sand200),
      ),
      child: child,
    );
  }
}
