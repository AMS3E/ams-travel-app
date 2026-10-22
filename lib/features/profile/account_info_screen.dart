import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../widgets/common.dart';
import '../auth/sign_in.dart' as auth;

/// Opens Keycloak's account console, where the email and the password are
/// changed: they belong to the sign-in, not to this API.
Future<void> openAccountConsole(BuildContext context) async {
  final s = S.read(context);
  final ok = await launchUrl(Uri.parse('${ApiConfig.issuer}/account'), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showToast(context, s.somethingWentWrong);
}

/// The account form: name, phone and home province (`PUT /users/me`), the
/// email as it is, and the way to change the email or the password.
///
/// One "Full name" input: a first/last name split was declined 2026-10-14
/// (R-060), Khmer and multi-word names cannot be split honestly.
class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key, this.field});

  /// The field to start at (`name`, `phone` or `province`), from the
  /// profile completion popup: it is outlined in red, and a text field gets
  /// the cursor.
  final String? field;

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  String? _homeProvinceId;
  late final Future<List<CatalogProvince>> _provinces = context.read<AmsApi>().provinces();
  String? _filledFor;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final focus = switch (widget.field) {
      'name' => _nameFocus,
      'phone' => _phoneFocus,
      _ => null,
    };
    if (focus != null) WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  /// Starts from what the account holds.
  void _fill(UserProfile? user) {
    if (user == null || _filledFor == user.id) return;
    _filledFor = user.id;
    _name.text = user.fullName ?? '';
    _phone.text = user.phone ?? '';
    _homeProvinceId = user.homeProvinceId;
  }

  Future<void> _save() async {
    final s = S.read(context);
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        homeProvinceId: _homeProvinceId,
        clearHomeProvince: _homeProvinceId == null,
      );
      if (!mounted) return;
      showToast(context, s.accountSaved);
      context.pop();
    } catch (_) {
      if (mounted) showToast(context, s.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final authState = context.watch<AuthProvider>();
    final user = authState.user;
    _fill(user);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.accountInfo, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: !authState.isSignedIn
          ? auth.SignInPrompt(icon: Icons.person_outline_rounded, title: s.guestTitle, body: s.guestSubtitle)
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                _Label(s.fullName),
                FieldOutline(
                  highlight: widget.field == 'name',
                  child: TextField(controller: _name, focusNode: _nameFocus, decoration: bareInput(s.fullName)),
                ),
                _Label(s.phoneNumber),
                FieldOutline(
                  highlight: widget.field == 'phone',
                  child: TextField(
                    controller: _phone,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    decoration: bareInput('+855 12 345 678'),
                  ),
                ),
                _Label(s.homeProvince),
                FieldOutline(
                  highlight: widget.field == 'province' && _homeProvinceId == null,
                  child: FutureBuilder<List<CatalogProvince>>(
                    future: _provinces,
                    builder: (context, snap) {
                      final provinces = snap.data ?? const <CatalogProvince>[];
                      final known = provinces.any((p) => p.id == _homeProvinceId);
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: known ? _homeProvinceId : null,
                          hint: Text(
                            user?.homeProvinceName ?? s.chooseProvince,
                            style: AppText.sans(15, color: AppColors.sand500),
                          ),
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text(s.chooseProvince)),
                            for (final p in provinces) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
                          ],
                          onChanged: (id) => setState(() => _homeProvinceId = id),
                        ),
                      );
                    },
                  ),
                ),
                _Label(s.email),
                FieldOutline(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(user?.email ?? '', style: AppText.sans(15, color: AppColors.sand600)),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => openAccountConsole(context),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.sand100,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: AppColors.sand700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.changeEmailPassword,
                                style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand900),
                              ),
                              const SizedBox(height: 2),
                              Text(s.changeEmailPasswordNote, style: AppText.sans(12.5, color: AppColors.sand500)),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.sand500),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brand600, minimumSize: const Size(0, 54)),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    s.save,
                    style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 4, 0, 6),
    child: Text(
      text,
      style: AppText.sans(12.5, weight: FontWeight.w600, color: AppColors.sand600),
    ),
  );
}

/// The app's fields are filled and outlined by default; inside a rounded
/// outline they have to be plain.
InputDecoration bareInput(String hint) => InputDecoration(
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

/// The rounded outline each field on the account pages sits in.
class FieldOutline extends StatelessWidget {
  const FieldOutline({super.key, required this.child, this.highlight = false});
  final Widget child;

  /// Outlined in red, like the unfinished profile bar: the field the
  /// traveller was sent here to fill.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: highlight ? Border.all(color: AppColors.sunset500, width: 1.6) : Border.all(color: AppColors.sand200),
      ),
      child: child,
    );
  }
}
