import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/solitaire_themes.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu: mode selection (draw-1/draw-3, timed/relaxed), daily deal,
/// settings, PRO, share, rate. Store is initialized once here and shared.
class MenuScreen extends StatefulWidget {
  final TableAudio audio;
  final SolitaireSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final StoreService _store;
  DateTime? _dailyPlayed;

  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.gameswajiha.solitaire';

  @override
  void initState() {
    super.initState();
    _store = StoreService();
    _store.init();
    _store.proPurchased.addListener(_onProChanged);
    widget.audio.startMenuMusic();
  }

  void _onProChanged() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
    }
  }

  @override
  void dispose() {
    _store.proPurchased.removeListener(_onProChanged);
    _store.dispose();
    super.dispose();
  }

  FeltThemeDef get _t => FeltThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  void _play({DateTime? daily}) {
    widget.audio.click();
    setState(() => _dailyPlayed = daily);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          daily: daily,
        ),
      ),
    );
  }

  Future<void> _share() async {
    widget.audio.click();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'I\'m playing Solitaire by WAJIHA — the classic card table, free forever! $_storeUrl',
          subject: 'Solitaire by WAJIHA',
        ),
      );
    } catch (_) {}
  }

  Future<void> _rate() async {
    widget.audio.click();
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: 'com.gameswajiha.solitaire');
      }
    } catch (_) {}
  }

  void _howToPlay() {
    widget.audio.click();
    showDialog(
      context: context,
      builder: (_) => const _HowToPlayDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.3,
            colors: [t.feltLight, t.feltDark],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _iconBtn(t, Icons.settings, 'Settings', () {
                        widget.audio.click();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: s,
                              store: _store,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 8),
                      _iconBtn(t, Icons.star, 'PRO', () {
                        widget.audio.click();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProScreen(
                              audio: widget.audio,
                              settings: s,
                              store: _store,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/solitaire_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text('Solitaire',
                      style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: t.ink,
                          fontFamily: 'serif',
                          shadows: [
                            Shadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                offset: const Offset(0, 3),
                                blurRadius: 8)
                          ])),
                  Text('Howdy, ${s.playerName}!',
                      style: TextStyle(
                          fontSize: 15,
                          color: t.accentLight,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  // mode cards
                  _modeCard(
                    t,
                    title: 'Draw',
                    options: const ['Draw 1', 'Draw 3'],
                    selected: s.drawCount == 1 ? 0 : 1,
                    onPick: (i) {
                      widget.audio.click();
                      s.setDrawCount(i == 0 ? 1 : 3);
                    },
                  ),
                  const SizedBox(height: 10),
                  _modeCard(
                    t,
                    title: 'Pace',
                    options: const ['Relaxed', 'Timed'],
                    selected: s.timed ? 1 : 0,
                    onPick: (i) {
                      widget.audio.click();
                      s.setTimed(i == 1);
                    },
                  ),
                  const SizedBox(height: 16),
                  _bigBtn(t, '▶  Deal the cards', () => _play()),
                  const SizedBox(height: 10),
                  _bigBtn(
                    t,
                    _dailyPlayed != null &&
                            _isToday(_dailyPlayed!) &&
                            s.dailyScore(DateTime.now()) != null
                        ? '✓  Daily deal played'
                        : '📅  Daily deal',
                    () => _play(daily: DateTime.now()),
                    outlined: true,
                  ),
                  const SizedBox(height: 10),
                  _bigBtn(t, '❓  How to play', _howToPlay, outlined: true),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _smallBtn(t, Icons.share, 'Share', _share),
                      const SizedBox(width: 12),
                      _smallBtn(t, Icons.star_border, 'Rate', _rate),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 2,
                              color:
                                  t.ink.withValues(alpha: 0.6))),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Widget _iconBtn(
      FeltThemeDef t, IconData icon, String tip, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.rail.withValues(alpha: 0.9),
          border: Border.all(color: t.accent.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(0, 2),
                blurRadius: 5),
          ],
        ),
        child: Icon(icon, color: t.accentLight, size: 22),
      ),
    );
  }

  Widget _modeCard(FeltThemeDef t,
      {required String title,
      required List<String> options,
      required int selected,
      required void Function(int) onPick}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: t.accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  color: t.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const Spacer(),
          for (int i = 0; i < options.length; i++) ...[
            GestureDetector(
              onTap: () => onPick(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: i == selected
                      ? t.accent.withValues(alpha: 0.95)
                      : Colors.transparent,
                  border: Border.all(
                      color: t.accent.withValues(alpha: 0.6)),
                ),
                child: Text(options[i],
                    style: TextStyle(
                        color: i == selected ? t.railDeep : t.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
            if (i < options.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _bigBtn(FeltThemeDef t, String label, VoidCallback onTap,
      {bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: outlined
              ? Colors.black.withValues(alpha: 0.28)
              : t.accent.withValues(alpha: 0.95),
          border: Border.all(color: t.accent, width: 1.5),
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      offset: const Offset(0, 4),
                      blurRadius: 10),
                ],
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: outlined ? t.accentLight : t.railDeep,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
      ),
    );
  }

  Widget _smallBtn(
      FeltThemeDef t, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: t.rail.withValues(alpha: 0.9),
          border: Border.all(color: t.accent.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: t.accentLight),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _HowToPlayDialog extends StatelessWidget {
  const _HowToPlayDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2E1A0C),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('How to play',
          style: TextStyle(
              color: Color(0xFFE8CE7A),
              fontFamily: 'serif',
              fontWeight: FontWeight.w800)),
      content: const SingleChildScrollView(
        child: Text(
          'Goal: build all four suits from Ace to King on the four '
          'foundation piles.\n\n'
          '• Tap the stock (top-left) to draw cards.\n'
          '• Build tableau columns down in alternating colors '
          '(red 7 on black 8).\n'
          '• Only a King starts an empty column.\n'
          '• Foundations build up by suit from the Ace.\n'
          '• Tap a card to select it, then tap where it goes.\n'
          '• Double-tap a card to send it to its foundation.\n'
          '• Draw-1 recycles the stock freely; Draw-3 is one pass.\n'
          '• Tap Finish when the table is clear to auto-complete.',
          style: TextStyle(color: Color(0xFFF5EFE0), fontSize: 14),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it!',
              style: TextStyle(color: Color(0xFFE8CE7A))),
        ),
      ],
    );
  }
}
