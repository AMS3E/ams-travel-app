import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/locale_provider.dart';
import '../../widgets/app_image.dart';
import 'interests_step.dart';
import 'ready_step.dart';

/// Shown once, before the app itself. Four swipeable slides introducing
/// AMS Travel, then "Start My Journey" (create an account) or
/// "Explore as Guest" (straight to Home).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  /// Remembers that the welcome slides have been seen.
  static const seenKey = 'ams-travel:welcome-seen';

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

// This screen has its own deep-blue palette — the rest of the app follows the
// website's light one.
const _ink = Color(0xFF0B1552);
const _inkDeep = Color(0xFF080F3B);
const _violet = Color(0xFF5B2EE5);
const _gold = Color(0xFFF0A84E);
const _lilac = Color(0xFFB9A7F7);
const _peach = Color(0xFFF7C79C);

class _Slide {
  const _Slide({
    required this.image,
    required this.eyebrow,
    required this.titleA,
    required this.titleB,
    required this.body,
  });
  final String image;
  final String eyebrow;
  final String titleA;
  final String titleB;
  final String body;
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = PageController();
  int _page = 0;

  /// Four photo slides, then the interests step, then the ready step.
  static const _slideCount = 4;
  static const _interestsPage = _slideCount;
  static const _readyPage = _slideCount + 1;
  static const _pageCount = _slideCount + 2;

  /// The dots count steps, not slides: all the welcome slides are one step.
  static const _stepCount = 3;
  int get _step => _page < _slideCount ? 0 : _page - _slideCount + 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ends onboarding on Home. With [register], the sign-up page opens on top,
  /// so closing it lands on Home.
  void _finish({bool register = false}) {
    context.read<SharedPreferences>().setBool(WelcomeScreen.seenKey, true);
    context.go(Routes.home);
    if (register) context.push(Routes.register);
  }

  void _toPage(int page) =>
      _controller.animateToPage(page, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = context.watch<LocaleProvider>();
    final slides = [
      _Slide(
        image: 'https://images.unsplash.com/photo-1566706546199-a93ba33ce9f7?auto=format&fit=crop&w=1200&q=70',
        eyebrow: s.welcomeEyebrow1,
        titleA: s.welcomeTitleA1,
        titleB: s.welcomeTitleB1,
        body: s.welcomeBody1,
      ),
      _Slide(
        image: 'https://images.unsplash.com/photo-1704103259506-6c0ca4d6dca4?auto=format&fit=crop&w=1200&q=70',
        eyebrow: s.welcomeEyebrow2,
        titleA: s.welcomeTitleA2,
        titleB: s.welcomeTitleB2,
        body: s.welcomeBody2,
      ),
      _Slide(
        image: 'https://images.unsplash.com/photo-1656554848715-dc195c7484bb?auto=format&fit=crop&w=1200&q=70',
        eyebrow: s.welcomeEyebrow3,
        titleA: s.welcomeTitleA3,
        titleB: s.welcomeTitleB3,
        body: s.welcomeBody3,
      ),
      _Slide(
        image: 'https://images.unsplash.com/photo-1729963639012-5a6a48690ed4?auto=format&fit=crop&w=1200&q=70',
        eyebrow: s.welcomeEyebrow4,
        titleA: s.welcomeTitleA4,
        titleB: s.welcomeTitleB4,
        body: s.welcomeBody4,
      ),
    ];

    final onInterests = _page == _interestsPage;
    final onSlides = _page < _slideCount;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: onInterests ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _ink,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _pageCount,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => switch (i) {
                _interestsPage => InterestsStep(onContinue: () => _toPage(_readyPage)),
                _readyPage => ReadyStep(onStart: () => _finish(register: true)),
                _ => _SlideView(slide: slides[i]),
              },
            ),

            // Language picker, over the photo slides.
            if (!onInterests)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_LanguageButton(isKhmer: locale.isKhmer, onSelected: (km) => locale.setKhmer(km))],
                  ),
                ),
              ),

            // Dots, on the photo slides and the interests step alike.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _stepCount; i++)
                        GestureDetector(
                          onTap: () => _toPage(i == 0 ? 0 : _slideCount + i - 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _step ? 11 : 9,
                            height: i == _step ? 11 : 9,
                            decoration: BoxDecoration(
                              color: i == _step
                                  ? _violet
                                  : (onInterests ? AppColors.sand300 : Colors.white.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Buttons belong to the photo slides; the later steps have their own.
            if (onSlides)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _violet,
                              minimumSize: const Size(0, 60),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _toPage(_interestsPage),
                            child: _ButtonLabel(s.startJourney),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 60),
                              side: const BorderSide(color: _gold),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _finish,
                            child: _ButtonLabel(s.exploreAsGuest),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppImage(slide.image),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.3, 0.55, 0.78, 1],
              colors: [Color(0x660B1552), Color(0x140B1552), Color(0xB30B1552), _ink, _inkDeep],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: SafeArea(
            child: Padding(
              // Leaves room for the buttons pinned below.
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 252),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _gold.withValues(alpha: 0.8)),
                    ),
                    child: Text(
                      slide.eyebrow,
                      style: AppText.sans(
                        11.5,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ).copyWith(letterSpacing: 1.6),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Peach → white → lilac sweep across the whole headline.
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [_peach, Colors.white, Colors.white, _lilac],
                      stops: [0, 0.34, 0.62, 1],
                    ).createShader(bounds),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide.titleA,
                          style: AppText.sans(34, weight: FontWeight.w800, color: Colors.white, height: 1.18),
                        ),
                        Text(
                          slide.titleB,
                          style: AppText.sans(34, weight: FontWeight.w800, color: Colors.white, height: 1.18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // White, with the *marked* phrases picked out in gold.
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final (i, part) in slide.body.split('*').indexed)
                          TextSpan(
                            text: part,
                            style: AppText.sans(
                              15.5,
                              color: i.isOdd ? _gold : Colors.white.withValues(alpha: 0.9),
                              height: 1.55,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.sans(16, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
      const SizedBox(width: 10),
      const Icon(Icons.arrow_forward_rounded, size: 19, color: Colors.white),
    ],
  );
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.isKhmer, required this.onSelected});
  final bool isKhmer;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      onSelected: onSelected,
      initialValue: isKhmer,
      color: Colors.white,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => const [
        PopupMenuItem(value: false, child: Text('English')),
        PopupMenuItem(value: true, child: Text('ខ្មែរ')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              isKhmer ? 'ខ្មែរ' : 'EN',
              style: AppText.sans(14, weight: FontWeight.w700, color: Colors.white),
            ),
            const Icon(Icons.expand_more_rounded, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
