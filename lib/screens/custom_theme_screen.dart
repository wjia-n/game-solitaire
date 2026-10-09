import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/solitaire_themes.dart';

/// PRO: design your own table felt. Eight color wells with a preset palette,
/// live preview, and reset.
class CustomThemeScreen extends StatefulWidget {
  final TableAudio audio;
  final SolitaireSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const _labels = {
    'feltLight': 'Felt light',
    'feltDark': 'Felt dark',
    'rail': 'Rail',
    'railDeep': 'Rail deep',
    'accent': 'Trim',
    'accentLight': 'Trim light',
    'ink': 'Text',
    'cardFace': 'Card face',
  };

  static const _palette = [
    0xFF0E7A48, 0xFF05422A, 0xFF1E4D8C, 0xFF0B2447,
    0xFF7A2436, 0xFF420E1B, 0xFF5C2E8C, 0xFF2E1247,
    0xFF8C1E2E, 0xFF470812, 0xFF14607A, 0xFF08303F,
    0xFF5A3820, 0xFF2E1A0C, 0xFFC9A227, 0xFFE8CE7A,
    0xFF8A6D1A, 0xFFF5EFE0, 0xFFFFFEF8, 0xFF1B1B1B,
    0xFF3A3F45, 0xFF16181C, 0xFFE8DCC0, 0xFFB3A480,
  ];

  String? _editing;

  FeltThemeDef get _t => widget.settings.customTheme;

  @override
  Widget build(BuildContext context) {
    final t = FeltThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    final preview = _t;
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
        title: Text('My Felt',
            style: TextStyle(
                color: t.ink,
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                fontSize: 22)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              widget.audio.click();
              widget.settings.resetCustomColors();
            },
            child: Text('Reset',
                style: TextStyle(
                    color: t.accentLight, fontWeight: FontWeight.w700)),
          ),
        ],
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
          listenable: widget.settings,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // live preview
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [preview.feltLight, preview.feltDark],
                    ),
                    border:
                        Border.all(color: preview.accent, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: preview.cardFace,
                        border: Border.all(
                            color: preview.accentLight, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              offset: const Offset(0, 4),
                              blurRadius: 8),
                        ],
                      ),
                      child: Center(
                        child: Text('A♠',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: preview.ink)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tap a part, then pick a color',
                    style: TextStyle(
                        color: t.accentLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in _labels.entries)
                      GestureDetector(
                        onTap: () {
                          widget.audio.click();
                          setState(() => _editing = e.key);
                        },
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black.withValues(alpha: 0.28),
                            border: Border.all(
                              color: _editing == e.key
                                  ? t.accentLight
                                  : t.accent.withValues(alpha: 0.4),
                              width: _editing == e.key ? 2.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(widget.settings
                                          .customColors[e.key] ??
                                      0xFF000000),
                                  border: Border.all(
                                      color: Colors.white54),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(e.value,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: t.ink, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (_editing != null) ...[
                  const SizedBox(height: 16),
                  Text('Color for ${_labels[_editing]}',
                      style: TextStyle(
                          color: t.accentLight,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _palette)
                        GestureDetector(
                          onTap: () {
                            widget.audio.click();
                            widget.settings
                                .setCustomColor(_editing!, c);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(c),
                              border: Border.all(
                                color: widget.settings.customColors[
                                            _editing!] ==
                                        c
                                    ? t.accentLight
                                    : Colors.white24,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      widget.settings.setTheme('custom');
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: t.accent.withValues(alpha: 0.95),
                      ),
                      child: Text('Use my felt',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: t.railDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ),
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
}
