import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/l10n/app_strings.dart';
import 'features/welcome/welcome_screen.dart';
import 'core/network/api_client.dart';
import 'data/api/ams_api.dart';
import 'data/auth/keycloak.dart';
import 'state/auth_provider.dart';
import 'state/collections_provider.dart';
import 'state/notifications_provider.dart';
import 'state/locale_provider.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts ship inside the app (assets/google_fonts) so text renders offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/google_fonts/OFL-Inter.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], text);
  });

  // UI text in English and Khmer (lib/l10n/*.json), the saved settings and
  // the stored sign-in, read side by side.
  final store = SecureTokenStore();
  final stored = store.read();
  final (_, prefs, _) = await (S.load(), SharedPreferences.getInstance(), stored).wait;

  // Every read is public; once signed in the client sends the Keycloak token.
  final client = ApiClient();
  final api = AmsApi(client);
  final auth = AuthProvider(keycloak: AppAuthKeycloak(), store: store, api: api, prefs: prefs);
  client.tokens = auth;
  await auth.restore(stored);

  // Content in the app's language: the API asks for Khmer while it is on.
  final locale = LocaleProvider(prefs);
  api.khmer = locale.isKhmer;
  locale.addListener(() => api.khmer = locale.isKhmer);

  final folders = FoldersProvider(prefs);
  final saved = SavedProvider(api, auth);
  final notifications = NotificationsProvider(api, auth);

  runApp(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<AmsApi>.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: locale),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider.value(value: saved),
        ChangeNotifierProvider.value(value: notifications),
        ChangeNotifierProvider.value(value: folders),
      ],
      child: AmsTravelApp(showWelcome: !(prefs.getBool(WelcomeScreen.seenKey) ?? false)),
    ),
  );
}
