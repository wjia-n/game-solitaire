import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/solitaire_themes.dart';
import 'menu_screen.dart';

/// Launch splash in two moments:
/// 1. WAJIHA company splash (official logo, copied untouched).
/// 2. Game splash: Solitaire logo + name, animated loading line,
///    "Credits: WAJIHA".
class SplashScreen extends StatefulWidget {
  final TableAudio audio;
  final SolitaireSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  int _moment = 0; // 0 = company, 1 = game

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _moment = 1);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FeltThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _moment == 0
            ? const _CompanySplash(key: ValueKey('company'))
            : _GameSplash(
                key: const ValueKey('game'),
                theme: theme,
                loader: _loader,
              ),
      ),
    );
  }
}

/// Moment 1: the official WAJIHA company logo, unaltered.
class _CompanySplash extends StatelessWidget {
  const _CompanySplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  offset: const Offset(0, 12),
                  blurRadius: 30,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/wajiha_logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(height: 24),
          const Text(
            'WAJIHA',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
              color: Color(0xFFF5EFE0),
              fontFamily: 'serif',
            ),
          ),
        ],
      ),
    );
  }
}

/// Moment 2: game logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final FeltThemeDef theme;
  final AnimationController loader;
  const _GameSplash(
      {super.key, required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [theme.feltLight, theme.feltDark],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    offset: const Offset(0, 12),
                    blurRadius: 28,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/solitaire_logo.png',
                  fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text(
              'Solitaire',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.w800,
                color: theme.ink,
                fontFamily: 'serif',
                letterSpacing: 2,
                shadows: [
                  Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 3),
                      blurRadius: 8)
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'THE CLASSIC CARD TABLE',
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 5,
                color: theme.accentLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                theme.accentLight,
                                theme.accent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1 ? 'Shuffling the deck…' : 'Ready!',
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.ink.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2,
                    color: theme.accentLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
