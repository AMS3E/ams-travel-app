import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/common.dart';
import '../../core/utils/dates.dart';
import '../destination/reviews_screen.dart' show visitTypeLabel;

/// Changes one of the traveller's reviews with `PUT /reviews/{id}`: stars,
/// kind of visit, month of the visit, title and text. The photos stay as
/// they are (their keys are sent back). Pops with the updated review.
class EditReviewPage extends StatefulWidget {
  const EditReviewPage({super.key, required this.review, this.placeName});
  final TravelReview review;
  final String? placeName;

  @override
  State<EditReviewPage> createState() => _EditReviewPageState();
}

class _EditReviewPageState extends State<EditReviewPage> {
  late int _rating = widget.review.rating;
  late VisitType? _visit = widget.review.visitType;
  late DateTime? _month = widget.review.visitedMonth;
  late final _title = TextEditingController(text: widget.review.title ?? '');
  late final _content = TextEditingController(text: widget.review.content ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  /// The last three years of months, newest first, and the review's own.
  List<DateTime> get _months {
    final now = DateTime.now();
    final list = [for (var i = 0; i < 36; i++) DateTime(now.year, now.month - i)];
    final own = widget.review.visitedMonth;
    if (own != null && !list.contains(own)) list.add(own);
    return list;
  }

  Future<void> _save() async {
    final s = S.read(context);
    setState(() => _saving = true);
    try {
      final updated = await context.read<AmsApi>().updateReview(
        widget.review.id,
        ReviewDraft(
          rating: _rating,
          title: _title.text.trim(),
          content: _content.text.trim(),
          visitType: _visit,
          visitedOn: _month,
          photoKeys: [for (final p in widget.review.photos) ?p.key],
        ),
      );
      if (!mounted) return;
      showToast(context, s.reviewUpdated);
      Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) showToast(context, s.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final label = AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand700);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.editReview, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset(context)),
        children: [
          if (widget.placeName != null) ...[
            Text(widget.placeName!, style: AppText.display(20)),
            const SizedBox(height: 16),
          ],
          Text(s.rateYourExperience, style: label),
          const SizedBox(height: 8),
          Stars(_rating, size: 34, onChanged: (v) => setState(() => _rating = v)),
          const SizedBox(height: 20),
          Text(s.kindOfVisit, style: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in VisitType.values)
                ChoiceChip(
                  label: Text(visitTypeLabel(s, v)),
                  selected: _visit == v,
                  onSelected: (on) => setState(() => _visit = on ? v : null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(s.whenDidYouVisit, style: label),
          const SizedBox(height: 8),
          DropdownButtonFormField<DateTime?>(
            initialValue: _month,
            isExpanded: true,
            items: [
              const DropdownMenuItem<DateTime?>(value: null, child: Text('—')),
              for (final m in _months) DropdownMenuItem<DateTime?>(value: m, child: Text(Dates.monthYear(m))),
            ],
            onChanged: (v) => setState(() => _month = v),
          ),
          const SizedBox(height: 20),
          Text(s.reviewTitleLabel, style: label),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            maxLength: ReviewDraft.titleMax,
            decoration: InputDecoration(hintText: s.reviewTitleHint),
          ),
          const SizedBox(height: 12),
          Text(s.yourReview, style: label),
          const SizedBox(height: 8),
          TextField(
            controller: _content,
            maxLength: ReviewDraft.contentMax,
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(hintText: s.yourReviewHint),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet, minimumSize: const Size(0, 54)),
            onPressed: _saving ? null : _save,
            child: Text(
              s.saveChanges,
              style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
