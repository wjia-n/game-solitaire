import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/solitaire_themes.dart';

/// Persisted settings + stats for Solitaire.
///
/// The player profile (display name) is persisted as ONE JSON string under
/// [ _kProfile ]. Android's SharedPreferences stores StringLists as an
/// unordered StringSet, so setStringList must NEVER be used for ordered or
/// profile data. Legacy keys are migrated once and dropped.
class SolitaireSettings extends ChangeNotifier {
  static const _kProfile = 'solitaire_profile_json'; // {"name": "..."}
  static const _kLegacyName = 'solitaire_player_name'; // legacy plain key
  static const _kMusic = 'solitaire_music_on';
  static const _kSfx = 'solitaire_sfx_on';
  static const _kVolume = 'solitaire_volume';
  static const _kTheme = 'solitaire_theme_id';
  static const _kCardBack = 'solitaire_card_back';
  static const _kDraw = 'solitaire_draw_count';
  static const _kTimed = 'solitaire_timed';
  static const _kIsPro = 'solitaire_is_pro';
  static const _kGames = 'solitaire_games_played';
  static const _kWins = 'solitaire_wins';
  static const _kBestScore = 'solitaire_best_score';
  static const _kBestTime = 'solitaire_best_time_secs';
  static const _kStreak = 'solitaire_win_streak';
  static const _kDailyPrefix = 'solitaire_daily_'; // + yyyy-MM-dd → score
  static const _kCustomPrefix = 'solitaire_custom_';

  static const defaultName = 'Player';

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  String playerName = defaultName;

  String themeId = 'classic';
  String cardBackId = 'classic';
  int drawCount = 1; // 1 or 3
  bool timed = false;

  int gamesPlayed = 0;
  int wins = 0;
  int bestScore = 0;
  int bestTimeSecs = 0; // 0 = none yet
  int winStreak = 0;

  bool isPro = true; // everything unlocked — no Pro version

  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'feltLight': 0xFF0E7A48,
    'feltDark': 0xFF05422A,
    'rail': 0xFF5A3820,
    'railDeep': 0xFF2E1A0C,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFE8CE7A,
    'ink': 0xFFF5EFE0,
    'cardFace': 0xFFFFFEF8,
  };

  FeltThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return FeltThemeDef(
      id: 'custom',
      name: 'My Felt',
      feltLight: c('feltLight'),
      feltDark: c('feltDark'),
      rail: c('rail'),
      railDeep: c('railDeep'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      ink: c('ink'),
      cardFace: c('cardFace'),
      cardInk: const Color(0xFF1B1B1B),
      placeholder: c('feltDark'),
      shadow: const Color(0xFF000000),
    );
  }

  SharedPreferences? _prefs;

  static String encodeProfile(String name) => jsonEncode({'name': name});

  static String decodeProfile(String? raw, String? legacy) {
    if (raw != null) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) {
          final n = (d['name'] as String? ?? '').trim();
          if (n.isNotEmpty) return n;
        }
      } catch (_) {}
    }
    final l = (legacy ?? '').trim();
    return l.isNotEmpty ? l : defaultName;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    playerName = decodeProfile(p.getString(_kProfile), p.getString(_kLegacyName));
    themeId = p.getString(_kTheme) ?? 'classic';
    cardBackId = p.getString(_kCardBack) ?? 'classic';
    drawCount = (p.getInt(_kDraw) ?? 1).clamp(1, 3);
    if (drawCount == 2) drawCount = 1;
    timed = p.getBool(_kTimed) ?? false;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    wins = p.getInt(_kWins) ?? 0;
    bestScore = p.getInt(_kBestScore) ?? 0;
    bestTimeSecs = p.getInt(_kBestTime) ?? 0;
    winStreak = p.getInt(_kStreak) ?? 0;
    isPro = true; // everything unlocked
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfile, encodeProfile(playerName));
    await p.remove(_kLegacyName); // one-time legacy migration
    await p.setString(_kTheme, themeId);
    await p.setString(_kCardBack, cardBackId);
    await p.setInt(_kDraw, drawCount);
    await p.setBool(_kTimed, timed);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kWins, wins);
    await p.setInt(_kBestScore, bestScore);
    await p.setInt(_kBestTime, bestTimeSecs);
    await p.setInt(_kStreak, winStreak);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || FeltThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    final back = CardBackStyle.byId(cardBackId);
    if (back.pro) {
      cardBackId = 'classic';
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? defaultName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || FeltThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCardBack(String id) async {
    if (!isPro && CardBackStyle.byId(id).pro) return;
    cardBackId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setDrawCount(int v) async {
    drawCount = v == 3 ? 3 : 1;
    notifyListeners();
    await _save();
  }

  Future<void> setTimed(bool v) async {
    timed = v;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  /// Record a finished deal. [won] true on a cleared board.
  Future<void> recordGame(
      {required bool won,
      required int score,
      required int seconds,
      DateTime? daily}) async {
    gamesPlayed++;
    if (won) {
      wins++;
      winStreak++;
      if (score > bestScore) bestScore = score;
      if (seconds > 0 && (bestTimeSecs == 0 || seconds < bestTimeSecs)) {
        bestTimeSecs = seconds;
      }
    } else {
      winStreak = 0;
    }
    if (daily != null && won) {
      await _prefs?.setInt(_dailyKey(daily), score);
    }
    notifyListeners();
    await _save();
  }

  String _dailyKey(DateTime d) =>
      '$_kDailyPrefix${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int? dailyScore(DateTime d) => _prefs?.getInt(_dailyKey(d));
}
