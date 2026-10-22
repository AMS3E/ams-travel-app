import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../widgets/common.dart';
import 'account_info_screen.dart';
import 'profile_screen.dart';

/// The short form behind the pencil on the profile: the photo
/// (`POST /media/files` type avatar, then `PUT /users/me` with its key) and
/// the name.
///
/// One "Full name" input (the first/last split was declined 2026-10-14,
/// R-060); the phone and the home province are on the account form.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.pickPhoto = false});

  /// Opens the photo picker at once, from the profile completion popup.
  final bool pickPhoto;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  String? _filledFor;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.pickPhoto) WidgetsBinding.instance.addPostFrameCallback((_) => _changePhoto());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _fill(UserProfile? user) {
    if (user == null || _filledFor == user.id) return;
    _filledFor = user.id;
    _name.text = user.fullName ?? '';
  }

  Future<void> _changePhoto() async {
    final s = S.read(context);
    final api = context.read<AmsApi>();
    final authState = context.read<AuthProvider>();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final file = await api.uploadFile(picked.path, type: 'avatar');
      await authState.updateProfile(avatarKey: file.key);
      if (mounted) showToast(context, s.photoUpdated);
    } catch (_) {
      if (mounted) showToast(context, s.saveFailed);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final s = S.read(context);
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateProfile(fullName: _name.text.trim());
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
    final user = context.watch<AuthProvider>().user;
    _fill(user);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.editProfile, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ProfileAvatar(user: user, radius: 42),
                          if (_uploading)
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.violet),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _uploading ? null : _changePhoto,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18, color: AppColors.sand700),
                        label: Text(
                          s.changePhoto,
                          style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FieldOutline(
                  child: TextField(controller: _name, decoration: bareInput(s.fullName)),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    minimumSize: const Size(0, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
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
