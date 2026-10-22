import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';

/// Where the per-install browse session id is kept.
const browseSessionKey = 'ams-travel:browse-session';

/// Opening a page counts as a browse, for Popular: `POST /popular/events`
/// (public; it counts the traveller when signed in). A signed-in traveller
/// opening an attraction, stay, food place or activity also feeds the
/// Browser badge, through `PUT /badges/me/explorations/{id}`, which counts
/// for Popular as well; a corridor is not a destination and only counts for
/// Popular. Never waited on; its errors are ignored.
void recordBrowse(BuildContext context, CardType type, String id) {
  try {
    final api = context.read<AmsApi>();
    if (type != CardType.corridor && context.read<AuthProvider>().isSignedIn) {
      api.recordExploration(id).ignore();
      return;
    }
    final prefs = context.read<SharedPreferences>();
    var session = prefs.getString(browseSessionKey);
    if (session == null || session.isEmpty) {
      final r = Random.secure();
      session = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      unawaited(prefs.setString(browseSessionKey, session));
    }
    api.recordBrowse(type, id, sessionId: session).ignore();
  } catch (_) {
    // A browse that cannot be recorded changes nothing on the page.
  }
}

/// Records one browse of [type] [id] when it first appears; see [recordBrowse].
class BrowseRecorder extends StatefulWidget {
  const BrowseRecorder({super.key, required this.type, required this.id, required this.child});

  final CardType type;
  final String id;
  final Widget child;

  @override
  State<BrowseRecorder> createState() => _BrowseRecorderState();
}

class _BrowseRecorderState extends State<BrowseRecorder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) recordBrowse(context, widget.type, widget.id);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
