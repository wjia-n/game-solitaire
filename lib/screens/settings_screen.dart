import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/solitaire_themes.dart';
import '../widgets/cards.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// Settings: renameable player profile, audio controls, felt theme picker
/// (14 + custom), card-back picker (10), and stats.
class SettingsScreen extends StatefulWidget {
  final TableAudio audio;
  final SolitaireSettings settings;
  final StoreService store;
  const SettingsScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtl;
  late final FocusNode _nameFocus;
  Timer? _nameDebounce;

  @override
  void initState() {
    super.initState();
    _nameCtl =
        TextEditingController(text: widget.settings.playerName);
    _nameFocus = FocusNode();
    // Commit the in-progress name on focus loss (not just keyboard-done).
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) {
        _nameDebounce?.cancel();
        _commitName();
      }
    });
  }

  /// Save the trimmed name to the single-JSON profile.
  void _commitName() {
    widget.settings.setPlayerName(_nameCtl.text);
    _nameCtl.text = widget.settings.playerName;
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameCtl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  FeltThemeDef get _t => FeltThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  void _goPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.accentLight),
          onPressed: () {
            widget.audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Settings',
            style: TextStyle(
                color: t.ink,
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                fontSize: 22)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.3,
            colors: [t.feltLight, t.feltDark],
          ),
        ),
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(t, 'Player'),
                _card(
                  t,
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtl,
                          focusNode: _nameFocus,
                          style: TextStyle(color: t.ink, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Your name',
                            hintStyle: TextStyle(
                                color: t.ink.withValues(alpha: 0.4)),
                            border: InputBorder.none,
                          ),
                          // Save on every keystroke (debounced) — never
                          // rely on keyboard-done alone for persistence.
                          onChanged: (v) {
                            _nameDebounce?.cancel();
                            _nameDebounce = Timer(
                              const Duration(milliseconds: 600),
                              () {
                                if (mounted) {
                                  widget.settings.setPlayerName(v);
                                }
                              },
                            );
                          },
                          onSubmitted: (v) {
                            _nameDebounce?.cancel();
                            widget.audio.click();
                            _commitName();
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _nameDebounce?.cancel();
                          widget.audio.click();
                          _commitName();
                          FocusScope.of(context).unfocus();
                        },
                        child: Text('Save',
                            style: TextStyle(
                                color: t.accentLight,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(t, 'Sound'),
                _card(
                  t,
                  Column(
                    children: [
                      _switchRow(t, 'Music', s.musicOn, (v) {
                        s.setMusic(v);
                        widget.audio.configure(
                            musicOn: v,
                            sfxOn: s.sfxOn,
                            volume: s.volume);
                        if (v) {
                          widget.audio.startMenuMusic();
                        }
                      }),
                      _switchRow(t, 'Sound effects', s.sfxOn, (v) {
                        s.setSfx(v);
                        widget.audio.configure(
                            musicOn: s.musicOn,
                            sfxOn: v,
                            volume: s.volume);
                        widget.audio.click();
                      }),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Text('Volume',
                                style: TextStyle(
                                    color: t.ink, fontSize: 15)),
                            Expanded(
                              child: Slider(
                                value: s.volume,
                                activeColor: t.accent,
                                inactiveColor: t.accent
                                    .withValues(alpha: 0.3),
                                onChanged: (v) {
                                  s.setVolume(v);
                                  widget.audio.configure(
                                      musicOn: s.musicOn,
                                      sfxOn: s.sfxOn,
                                      volume: v);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(t,
                    'Table felt  ·  ${s.isPro ? "14 + custom" : "4 free — PRO unlocks all"}'),
                _card(
                  t,
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final th in FeltThemes.all)
                        _themeSwatch(t, s, th),
                      _customSwatch(t, s),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(t,
                    'Card backs  ·  ${s.isPro ? "10 styles" : "3 free — PRO unlocks all"}'),
                _card(
                  t,
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final b in CardBackStyle.all)
                        _backSwatch(t, s, b),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(t, 'Your table record'),
                _card(
                  t,
                  Column(
                    children: [
                      _statLine(t, 'Deals played', '${s.gamesPlayed}'),
                      _statLine(t, 'Deals won', '${s.wins}'),
                      _statLine(
                          t,
                          'Win rate',
                          s.gamesPlayed == 0
                              ? '—'
                              : '${(100 * s.wins / s.gamesPlayed).round()}%'),
                      _statLine(t, 'Win streak', '${s.winStreak}'),
                      _statLine(t, 'Best score', '${s.bestScore}'),
                      _statLine(
                          t,
                          'Fastest win',
                          s.bestTimeSecs == 0
                              ? '—'
                              : '${s.bestTimeSecs ~/ 60}:${(s.bestTimeSecs % 60).toString().padLeft(2, '0')}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(FeltThemeDef t, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
              color: t.accentLight,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 1)),
    );
  }

  Widget _card(FeltThemeDef t, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: t.accent.withValues(alpha: 0.45)),
      ),
      child: child,
    );
  }

  Widget _switchRow(
      FeltThemeDef t, String label, bool value, void Function(bool) on) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: t.ink, fontSize: 15)),
          const Spacer(),
          Switch(
            value: value,
            activeThumbColor: t.accent,
            onChanged: (v) {
              widget.audio.click();
              on(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _themeSwatch(
      FeltThemeDef t, SolitaireSettings s, FeltThemeDef th) {
    final locked = th.pro && !s.isPro;
    final selected = s.themeId == th.id;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
          return;
        }
        s.setTheme(th.id);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [th.feltLight, th.feltDark],
              ),
              border: Border.all(
                color: selected ? t.accentLight : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 2),
                    blurRadius: 5),
              ],
            ),
            child: locked
                ? const Icon(Icons.lock,
                    size: 20, color: Colors.white70)
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 62,
            child: Text(th.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.ink.withValues(alpha: 0.85),
                    fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _customSwatch(FeltThemeDef t, SolitaireSettings s) {
    final locked = !s.isPro;
    final selected = s.themeId == 'custom';
    final c = s.customTheme;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomThemeScreen(
              audio: widget.audio,
              settings: s,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.feltLight, c.feltDark],
              ),
              border: Border.all(
                color: selected ? t.accentLight : t.accent,
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: Center(
              child: locked
                  ? const Icon(Icons.lock,
                      size: 20, color: Colors.white70)
                  : const Text('🎨',
                      style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 62,
            child: Text('My Felt',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.ink.withValues(alpha: 0.85),
                    fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _backSwatch(
      FeltThemeDef t, SolitaireSettings s, CardBackStyle b) {
    final locked = b.pro && !s.isPro;
    final selected = s.cardBackId == b.id;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
          return;
        }
        s.setCardBack(b.id);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? t.accentLight : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 2),
                    blurRadius: 5),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                CustomPaint(
                  painter: CardBackPainter(b.id),
                  child: Container(),
                ),
                if (locked)
                  Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: const Center(
                      child: Icon(Icons.lock,
                          size: 18, color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 58,
            child: Text(b.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.ink.withValues(alpha: 0.85),
                    fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _statLine(FeltThemeDef t, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style:
                  TextStyle(color: t.ink.withValues(alpha: 0.7), fontSize: 14)),
          Text(v,
              style: TextStyle(
                  color: t.accentLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
