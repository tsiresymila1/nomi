import 'package:flutter/material.dart';
import 'package:gena/features/home/presentation/widgets/intro_icon.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppIntroductionGate extends StatefulWidget {
  const AppIntroductionGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppIntroductionGate> createState() => _AppIntroductionGateState();
}

class _AppIntroductionGateState extends State<AppIntroductionGate> {
  static const String _prefsKeySeen = 'gena_intro_seen_v1';

  bool _loading = true;
  bool _seen = false;

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsKeySeen) ?? false;
    if (!mounted) {
      return;
    }

    setState(() {
      _seen = seen;
      _loading = false;
    });
  }

  Future<void> _finishIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeySeen, true);
    if (!mounted) {
      return;
    }

    setState(() {
      _seen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_seen) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IntroductionScreen(
      pages: <PageViewModel>[
        PageViewModel(
          titleWidget: Text(
            'Welcome to Nomi',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bodyWidget: Text(
            'Your private AI workspace for local and remote chat models, all in one app.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          image: const IntroIcon(icon: Icons.smart_toy_rounded),
        ),
        PageViewModel(
          titleWidget: Text(
            'Manage Models',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bodyWidget: Text(
            'Add model files or URLs, install them, and switch active models anytime.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          image: const IntroIcon(icon: Icons.download_for_offline_rounded),
        ),
        PageViewModel(
          titleWidget: Text(
            'Chat with Tools',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bodyWidget: Text(
            'Use chat threads with optional tools, vision, and workspace context for better answers.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          image: const IntroIcon(icon: Icons.chat_bubble_outline_rounded),
        ),
        PageViewModel(
          titleWidget: Text(
            'You are ready',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bodyWidget: Text(
            'Open Downloads to install a model, then start chatting from Home.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
          image: const IntroIcon(icon: Icons.rocket_launch_rounded),
        ),
      ],
      showSkipButton: true,
      skip: const Text('Skip'),
      next: const Icon(Icons.arrow_forward_rounded),
      done: const Text('Start'),
      onDone: _finishIntro,
      onSkip: _finishIntro,
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),
        activeSize: const Size(22, 8),
        activeColor: Theme.of(context).colorScheme.primary,
        color: isDark ? Colors.white24 : Colors.black26,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      controlsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      globalBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
