import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/auth_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

/// The short form behind the pencil on the profile: photo, name and where
/// the traveller is.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _first = TextEditingController();
  String? _province;
  bool _filled = false;

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  void _fillOnce(AppUser? user) {
    if (_filled || user == null) return;
    _filled = true;
    _first.text = user.firstName ?? user.username.split(RegExp(r'[ .]')).first;
    _province = user.location?.split(',').first.trim();
  }

  Future<void> _save() async {
    final s = S.read(context);
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    await auth.updateUser(
      user.copyWith(
        firstName: _first.text.trim(),
        location: _province == null ? null : '$_province, Cambodia',
      ),
    );
    if (!mounted) return;
    showToast(context, s.accountSaved);
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
        title: Text(s.navProfile, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: AsyncView<List<Province>>(
        load: context.read<TravelRepository>().getProvinces,
        builder: (context, provinces, _) => ListView(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.sand200,
                    backgroundImage: user?.avatarUrl == null ? null : NetworkImage(user!.avatarUrl!),
                    child: user?.avatarUrl != null
                        ? null
                        : const Icon(Icons.photo_camera_outlined, size: 26, color: AppColors.sand600),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    // TODO(api): needs an upload endpoint before a photo can
                    // be picked and kept.
                    onPressed: () => showToast(context, s.photoLater),
                    child: Text(
                      s.changePhoto,
                      style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            _Shell(
              child: TextField(
                controller: _first,
                decoration: _bare(s.firstName),
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

            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet,
                minimumSize: const Size(0, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
);

/// The rounded outline every row on this page sits in.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.sand200),
      ),
      child: child,
    );
  }
}
