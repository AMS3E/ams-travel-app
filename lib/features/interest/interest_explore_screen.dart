import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import 'interest_screen.dart';

/// Browse by interest: the six groups, starting with the first, and the
/// places the server finds for the chosen interests.
class InterestExploreScreen extends StatelessWidget {
  const InterestExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<InterestGroup>>(
          load: api.interestGroups,
          builder: (context, groups, _) =>
              InterestBrowser(groups: groups, initialIndex: 0, hint: S.of(context).exploreInterest),
        ),
      ),
    );
  }
}
