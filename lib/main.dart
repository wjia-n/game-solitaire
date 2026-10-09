import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/solitaire_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = SolitaireSettings();
  await settings.load();
  final audio = TableAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(SolitaireApp(settings: settings, audio: audio));
}

class SolitaireApp extends StatefulWidget {
  final SolitaireSettings settings;
  final TableAudio audio;
  const SolitaireApp({super.key, required this.settings, required this.audio});

  @override
  State<SolitaireApp> createState() => _SolitaireAppState();
}

class _SolitaireAppState extends State<SolitaireApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      SolitaireAppState.pauseEngine?.call();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
      SolitaireAppState.resumeEngine?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final theme = FeltThemes.byId(
          widget.settings.themeId,
          custom: widget.settings.customTheme,
        );
        return MaterialApp(
          title: 'Solitaire',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: theme.feltDark,
            colorScheme: ColorScheme.dark(
              primary: theme.accent,
              surface: theme.feltDark,
            ),
          ),
          home: SplashScreen(audio: widget.audio, settings: widget.settings),
        );
      },
    );
  }
}

/// App-scoped hooks the game screen registers so lifecycle events can
/// pause/resume the engine without the engine knowing about the app.
class SolitaireAppState {
  static void Function()? pauseEngine;
  static void Function()? resumeEngine;
}
