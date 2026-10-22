import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/place_list_row.dart';
import '../auth/sign_in.dart';
import '../profile/badges_screen.dart' show BadgeMedal;

// Checking in needs both the QR code a place posts on site and the phone
// standing there: `POST /stamps` {code, latitude, longitude}. The code is a
// link (`…/stamps/scan/ABCD-EFGH-JKLM`), sent whole; the letters printed under
// the QR can be typed instead. The answer names the place the code belongs
// to, which is the one shown, whatever page the scanner was opened from: a
// place may post several codes, and any scan button may scan any code.

/// Opens the scanner for a signed-in traveller; a guest is offered to log in.
void openCheckIn(BuildContext context) =>
    whenSignedIn(context, S.read(context).checkInSignIn, () => context.push(Routes.checkIn));

enum _Step { scanning, locating, sending, done, noLocation, failed }

/// The scanner, then the check-in's outcome.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key, this.locate = currentLocation});

  /// Reads where the phone is, asking for permission first if needed.
  final Future<DeviceLocation> Function() locate;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  MobileScannerController? _scanner = _newScanner();
  _Step _step = _Step.scanning;
  String? _code;
  Stamp? _stamp;

  /// The card of the place the code belongs to; null for an unknown code.
  PlaceCard? _place;
  LocationProblem? _problem;
  Object? _error;

  static MobileScannerController _newScanner() =>
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode]);

  @override
  void dispose() {
    _scanner?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_step != _Step.scanning) return;
    for (final b in capture.barcodes) {
      final text = b.rawValue?.trim() ?? '';
      if (text.isNotEmpty) {
        _submit(text);
        return;
      }
    }
  }

  /// Sends [code] with where the phone is. Location is asked for here, at
  /// the moment it is needed, not before.
  Future<void> _submit(String code) async {
    final api = context.read<AmsApi>();
    final scanner = _scanner;
    _scanner = null;
    scanner?.dispose();
    setState(() {
      _code = code;
      _step = _Step.locating;
      _error = null;
    });
    final here = await widget.locate();
    if (!mounted) return;
    if (!here.ok) {
      setState(() {
        _problem = here.problem;
        _step = _Step.noLocation;
      });
      return;
    }
    setState(() => _step = _Step.sending);
    try {
      final stamp = await api.checkIn(code, latitude: here.latitude!, longitude: here.longitude!);
      final place = stamp.hasPlace ? await api.card(stamp.destinationId, type: stamp.targetType).orNull : null;
      if (!mounted) return;
      setState(() {
        _stamp = stamp;
        _place = place;
        _step = _Step.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _step = _Step.failed;
      });
    }
  }

  void _scanAgain() => setState(() {
    _scanner ??= _newScanner();
    _step = _Step.scanning;
    _code = null;
    _stamp = null;
    _place = null;
  });

  Future<void> _typeCode() async {
    final code = await showDialog<String>(context: context, builder: (_) => const _TypeCodeDialog());
    if (code != null && code.trim().isNotEmpty && mounted) _submit(code);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.checkInTitle, style: AppText.display(20)), centerTitle: true),
      body: switch (_step) {
        _Step.scanning => _Scanner(controller: _scanner!, onDetect: _onDetect, onType: _typeCode),
        _Step.locating => _Working(text: s.nearbyLocating),
        _Step.sending => _Working(text: s.checkingIn),
        _Step.noLocation => _NoLocation(problem: _problem, onRetry: () => _submit(_code!)),
        _Step.failed => ErrorView(error: _error!, onRetry: () => _submit(_code!)),
        _Step.done => _Outcome(stamp: _stamp!, place: _place, onRetry: () => _submit(_code!), onScanAgain: _scanAgain),
      },
    );
  }
}

/// The camera with a frame to aim at, and the way to type the code.
class _Scanner extends StatelessWidget {
  const _Scanner({required this.controller, required this.onDetect, required this.onType});
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppColors.sand900,
                child: MobileScanner(
                  controller: controller,
                  onDetect: onDetect,
                  errorBuilder: (context, _) => const _CameraUnavailable(),
                ),
              ),
              // The frame to aim at, only while the camera is running.
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: controller,
                builder: (context, state, _) => !state.isRunning || state.error != null
                    ? const SizedBox.shrink()
                    : IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(24, 18, 24, 18 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.scanHint,
                style: AppText.sans(14, color: AppColors.sand700, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onType,
                icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                label: Text(s.typeCodeInstead),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// No camera (a simulator, or access refused): the code can still be typed.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 40, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              s.cameraUnavailable,
              style: AppText.display(18, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              s.cameraUnavailableBody,
              style: AppText.sans(13.5, color: Colors.white70, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The letters printed under the QR code, typed in.
class _TypeCodeDialog extends StatefulWidget {
  const _TypeCodeDialog();

  @override
  State<_TypeCodeDialog> createState() => _TypeCodeDialogState();
}

class _TypeCodeDialogState extends State<_TypeCodeDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.typeCodeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.typeCodeBody, style: AppText.sans(13.5, color: AppColors.sand600, height: 1.4)),
          const SizedBox(height: 14),
          TextField(
            controller: _field,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'ABCD-EFGH-JKLM'),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _field.text), child: Text(s.checkInTitle)),
      ],
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LoadingView(padding: EdgeInsets.zero),
        const SizedBox(height: 16),
        Text(text, style: AppText.sans(14.5, color: AppColors.sand600)),
      ],
    ),
  );
}

/// The position could not be read: why, and the way out.
class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.problem, required this.onRetry});
  final LocationProblem? problem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = problem.needsSettings;
    return SingleChildScrollView(
      child: EmptyState(
        icon: Icons.location_off_outlined,
        title: s.checkInLocationTitle,
        body: switch (problem) {
          LocationProblem.serviceOff => s.checkInLocationOff,
          LocationProblem.denied || LocationProblem.deniedForever => s.checkInLocationDenied,
          _ => s.checkInLocationUnavailable,
        },
        actionLabel: settings ? s.openSettingsAction : s.retry,
        onAction: settings ? () => openLocationSettings(problem) : onRetry,
      ),
    );
  }
}

/// "350 m", or "1.4 km" / "0.9 mi".
String _distance(int metres) => !useMiles && metres < 1000 ? '$metres m' : '${formatKm(metres / 1000)} $distanceUnit';

/// What the check-in came to, for the place the code belongs to.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.stamp, required this.place, required this.onRetry, required this.onScanAgain});
  final Stamp stamp;
  final PlaceCard? place;

  /// The same code again, with a fresh position.
  final VoidCallback onRetry;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final place = this.place;
    final name = place?.name ?? '';
    final (icon, colour, title, body) = switch (stamp.outcome) {
      CheckInOutcome.collected || null => (
        Icons.approval_rounded,
        AppColors.success,
        s.stampCollected,
        s.fill(s.stampCollectedBody, {'place': name}),
      ),
      CheckInOutcome.alreadyCollected => (
        Icons.event_available_rounded,
        AppColors.violet,
        s.alreadyCollected,
        s.fill(s.alreadyCollectedBody, {'place': name}),
      ),
      CheckInOutcome.tooFar => (
        Icons.social_distance_rounded,
        AppColors.sunset500,
        s.tooFar,
        stamp.distanceMeters == null || stamp.radiusMeters == null
            ? s.fill(s.tooFarNoDistance, {'place': name})
            : s.fill(s.tooFarBody, {
                'place': name,
                'distance': _distance(stamp.distanceMeters!),
                'radius': _distance(stamp.radiusMeters!),
              }),
      ),
      CheckInOutcome.invalidCode => (Icons.qr_code_2_rounded, AppColors.sunset500, s.invalidCode, s.invalidCodeBody),
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 32, 24, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: colour.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: colour),
          ),
        ),
        const SizedBox(height: 18),
        Text(title, style: AppText.display(22), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          body,
          style: AppText.sans(14.5, color: AppColors.sand600, height: 1.5),
          textAlign: TextAlign.center,
        ),
        if (place != null) ...[
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.sand200),
            ),
            clipBehavior: Clip.antiAlias,
            child: PlaceListRow(card: place),
          ),
        ],
        if (stamp.badgesEarned.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            s.newBadgeEarned,
            style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
          ),
          const SizedBox(height: 10),
          for (final b in stamp.badgesEarned)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  BadgeMedal(level: b.level, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      b.name,
                      style: AppText.sans(14.5, weight: FontWeight.w600, color: AppColors.sand800),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 28),
        if (stamp.outcome == CheckInOutcome.tooFar)
          FilledButton(onPressed: onRetry, child: Text(s.retry))
        else if (place != null)
          FilledButton(onPressed: () => context.pushReplacement(Routes.card(place)), child: Text(s.openThePlace)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onScanAgain,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: Text(s.scanAnother),
        ),
      ],
    );
  }
}
