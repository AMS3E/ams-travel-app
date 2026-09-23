import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class AmsTravelApp extends StatefulWidget {
  const AmsTravelApp({super.key, this.showWelcome = false});

  /// First launch starts on the welcome slides.
  final bool showWelcome;

  @override
  State<AmsTravelApp> createState() => _AmsTravelAppState();
}

class _AmsTravelAppState extends State<AmsTravelApp> {
  late final GoRouter _router = createRouter(showWelcome: widget.showWelcome);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AMS Travel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
