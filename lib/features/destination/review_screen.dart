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
import '../../widgets/common.dart';

/// Writing a review: the score, who you went with, when, a title, the review
/// itself and photos.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.region, required this.slug});
  final String region;
  final String slug;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _tripTypes = ['Business', 'Couples', 'Family', 'Friends', 'Solo'];
  static const _titleLimit = 120;
  static const _minWords = 25;

  final _title = TextEditingController();
  final _body = TextEditingController();
  int _rating = 0;
  String? _tripType;
  late DateTime _visited = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  int get _words => _body.text.trim().isEmpty ? 0 : _body.text.trim().split(RegExp(r'\s+')).length;
  bool get _canSubmit => _rating > 0 && _words >= _minWords && !_saving;

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

  Future<void> _submit() async {
    final s = S.read(context);
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      showToast(context, s.logInToReview, actionLabel: s.logIn, onAction: () => context.push(Routes.login));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<TravelRepository>().submitReview(
        DestinationRef(widget.region, widget.slug),
        rating: _rating,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        text: _body.text.trim(),
        tripType: _tripType,
        visitedOn: _visited,
        author: auth.user!.username,
      );
      if (!mounted) return;
      showToast(context, s.reviewSaved);
      context.pop(true);
    } on Object {
      if (mounted) showToast(context, s.somethingWentWrong);
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
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => _rating = i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.star_rounded,
                      size: 34,
                      color: i <= _rating ? AppColors.star : AppColors.sand200,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),

          _Label(s.kindOfVisit),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _tripTypes)
                _Choice(
                  label: t,
                  selected: _tripType == t,
                  onTap: () => setState(() => _tripType = _tripType == t ? null : t),
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
                    child: Text(_monthYear(_visited), style: AppText.sans(15, color: AppColors.sand900)),
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
            maxLength: _titleLimit,
            onChanged: (_) => setState(() {}),
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
          _Hint('${s.max} $_titleLimit ${s.characters}'),
          const SizedBox(height: 18),

          _Label(s.yourReview),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            minLines: 5,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s.yourReviewHint,
              border: _border,
              enabledBorder: _border,
              focusedBorder: _border,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 4),
          _Hint('${s.min} $_minWords ${s.words}  ·  $_words'),
          const SizedBox(height: 18),

          _Label(s.photoOfYourVisit),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                // TODO(api): pick and upload photos once the backend stores them.
                onTap: () => showToast(context, s.photosComingSoon),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.sand300, style: BorderStyle.solid),
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
              for (var i = 0; i < 3; i++) ...[
                const SizedBox(width: 10),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: AppColors.sand100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.image_outlined, color: AppColors.sand300),
                ),
              ],
            ],
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
                : Text(s.submitReview, style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static final _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.sand200),
  );

  static String _monthYear(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900));
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
          style: AppText.sans(
            13.5,
            weight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.sand800,
          ),
        ),
      ),
    );
  }
}
