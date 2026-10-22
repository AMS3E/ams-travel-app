import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/common.dart';
import '../auth/sign_in.dart';
import 'reviews_screen.dart' show visitTypeLabel;

/// Writing a review of a place, stay, food place or corridor: the score, who
/// you went with, the month, a title, the review and photos. The photos go
/// up first (`POST /media/files`, type `review`), then the review is one
/// `POST /reviews`. Signed in only; pops with true once sent.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.type, required this.id, this.picker});
  final CardType type;
  final String id;

  /// For tests; the device's picker otherwise.
  final Future<List<String>> Function()? picker;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _maxPhotos = 6;

  final _title = TextEditingController();
  final _body = TextEditingController();
  int _rating = 0;
  VisitType? _visitType;
  late DateTime _visited = DateTime.now();

  /// Files picked on the device, uploaded when the review is sent.
  final _photos = <String>[];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// A rating is the whole point of a review; the words are the traveller's
  /// own business, however few.
  bool get _canSubmit => _rating > 0 && !_saving;

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visited,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: S.read(context).whenDidYouVisit,
    );
    if (picked != null && mounted) setState(() => _visited = picked);
  }

  Future<void> _addPhotos() async {
    final left = _maxPhotos - _photos.length;
    if (left <= 0) return;
    try {
      final paths =
          await (widget.picker?.call() ??
              ImagePicker()
                  .pickMultiImage(imageQuality: 85, maxWidth: 2048, limit: left > 1 ? left : null)
                  .then((files) => [for (final f in files) f.path]));
      if (mounted && paths.isNotEmpty) setState(() => _photos.addAll(paths.take(left)));
    } catch (e) {
      if (mounted) showToast(context, e.toString());
    }
  }

  void _submit() => whenSignedIn(context, S.read(context).logInToReview, _send);

  Future<void> _send() async {
    final s = S.read(context);
    final api = context.read<AmsApi>();
    setState(() => _saving = true);
    try {
      final List<String> keys;
      try {
        final uploads = await [for (final path in _photos) api.uploadFile(path, type: 'review')].wait;
        keys = [for (final u in uploads) u.key];
      } on ParallelWaitError {
        if (mounted) showToast(context, s.photoUploadFailed);
        return;
      }
      final review = await api.createReview(
        widget.type,
        widget.id,
        ReviewDraft(
          rating: _rating,
          title: _title.text.trim(),
          content: _body.text.trim(),
          visitType: _visitType,
          visitedOn: _visited,
          photoKeys: keys,
        ),
      );
      if (!mounted) return;
      showToast(context, review.isPending ? s.reviewSentForApproval : s.reviewSaved);
      context.pop(true);
    } catch (e) {
      if (mounted) showToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.reviewTitle, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          _Label(s.rateYourExperience),
          const SizedBox(height: 8),
          Stars(_rating, size: 34, onChanged: (v) => setState(() => _rating = v)),
          const SizedBox(height: 22),

          _Label(s.kindOfVisit),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in VisitType.values)
                _Choice(
                  label: visitTypeLabel(s, t),
                  selected: _visitType == t,
                  onTap: () => setState(() => _visitType = _visitType == t ? null : t),
                ),
            ],
          ),
          const SizedBox(height: 22),

          _Label(s.whenDidYouVisit),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickMonth,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sand200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(Dates.monthYear(_visited), style: AppText.sans(15, color: AppColors.sand900)),
                  ),
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.sand500),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          _Label(s.reviewTitleLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            maxLength: ReviewDraft.titleMax,
            decoration: InputDecoration(
              hintText: s.reviewTitleHint,
              counterText: '',
              border: _border,
              enabledBorder: _border,
              focusedBorder: _border,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
          ),
          const SizedBox(height: 4),
          _Hint('${s.max} ${ReviewDraft.titleMax} ${s.characters}'),
          const SizedBox(height: 18),

          _Label(s.yourReview),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            minLines: 5,
            maxLines: 8,
            maxLength: ReviewDraft.contentMax,
            decoration: InputDecoration(
              hintText: s.yourReviewHint,
              counterText: '',
              border: _border,
              enabledBorder: _border,
              focusedBorder: _border,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 18),

          _Label(s.photoOfYourVisit),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (_photos.length < _maxPhotos)
                  InkWell(
                    onTap: _saving ? null : _addPhotos,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.sand300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_camera_outlined, size: 22, color: AppColors.sand600),
                          const SizedBox(height: 4),
                          Text(s.addPhotos, style: AppText.sans(10.5, color: AppColors.sand500)),
                        ],
                      ),
                    ),
                  ),
                for (var i = 0; i < _photos.length; i++) ...[
                  const SizedBox(width: 10),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(_photos[i]),
                          width: 78,
                          height: 78,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 78,
                            height: 78,
                            color: AppColors.sand100,
                            child: const Icon(Icons.image_outlined, color: AppColors.sand300),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: _saving ? null : () => setState(() => _photos.removeAt(i)),
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 14, color: Colors.white, semanticLabel: s.delete),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sand900,
              disabledBackgroundColor: AppColors.sand300,
              minimumSize: const Size(0, 54),
            ),
            onPressed: _canSubmit ? _submit : null,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    s.submitReview,
                    style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  static final _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.sand200),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.sans(11.5, color: AppColors.sand400));
}

/// Pill that fills black when chosen, as in "Kind of visit".
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.sand900 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.sand900 : AppColors.sand200),
        ),
        child: Text(
          label,
          style: AppText.sans(13.5, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.sand800),
        ),
      ),
    );
  }
}
