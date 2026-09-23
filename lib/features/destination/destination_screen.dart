import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/collections_provider.dart';
import '../../widgets/async_view.dart';
import 'place_view.dart';

/// Loads one place and everything its page needs: the region it sits in, the
/// other places on the map (for "nearby" and "you may like") and the list of
/// interests, which decides what this category's sections are called.
class DestinationScreen extends StatefulWidget {
  const DestinationScreen({super.key, required this.region, required this.slug});
  final String region;
  final String slug;

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  @override
  void initState() {
    super.initState();
    // Opening a place counts towards the Browser badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BrowseCounter>().seen('${widget.region}/${widget.slug}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.region;
    final slug = widget.slug;
    final repo = context.read<TravelRepository>();
    return AsyncView<(Destination, Region, List<Destination>, List<Interest>)>(
      load: () => (
        repo.getDestination(region, slug),
        repo.getRegion(region),
        repo.getDestinations(),
        repo.getInterests(),
      ).wait,
      loading: const Scaffold(body: LoadingView()),
      builder: (context, data, _) => PlaceView(
        destination: data.$1,
        region: data.$2,
        allDestinations: data.$3,
        interests: data.$4,
      ),
    );
  }
}
