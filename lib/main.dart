import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/api_config.dart';
import 'features/welcome/welcome_screen.dart';
import 'core/network/api_client.dart';
import 'data/repositories/api_travel_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/mock_travel_repository.dart';
import 'data/repositories/travel_repository.dart';
import 'state/auth_provider.dart';
import 'state/collections_provider.dart';
import 'state/locale_provider.dart';
import 'state/settings_provider.dart';
import 'state/travel_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts ship inside the app (assets/google_fonts) so text renders offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/google_fonts/OFL-Geist.txt',
    );
    yield LicenseEntryWithLineBreaks(['google_fonts'], text);
  });

  final prefs = await SharedPreferences.getInstance();

  // The API client reads the token lazily, so it always sends the current one.
  late final AuthProvider auth;
  final api = ApiClient(tokenProvider: () => auth.token);

  // One switch decides mock vs real backend — see ApiConfig.
  final TravelRepository travel = ApiConfig.useMockData
      ? MockTravelRepository()
      : ApiTravelRepository(api);
  final AuthRepository authRepo = ApiConfig.useMockData
      ? MockAuthRepository()
      : ApiAuthRepository(api);
  auth = AuthProvider(authRepo, prefs);

  // Sample folders on first launch, so Saved has something in it.
  final folders = FoldersProvider(prefs);
  await folders.seedFromAssets();

  runApp(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<TravelRepository>.value(value: travel),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => SavedProvider(prefs)),
        ChangeNotifierProvider(create: (_) => StampsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => BrowseCounter(prefs)),
        ChangeNotifierProvider(create: (_) => BadgeLog(prefs)),
        ChangeNotifierProvider.value(value: folders),
        ChangeNotifierProvider(create: (_) => TravelPreferences(prefs)),
      ],
      child: AmsTravelApp(
        showWelcome: !(prefs.getBool(WelcomeScreen.seenKey) ?? false),
      ),
    ),
  );
}
