import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'analytics.dart';
import 'auth.dart';
import 'billing.dart';
import 'feedback_log.dart';
import 'firebase_options.dart';
import 'install_info.dart';
import 'notification_log.dart';
import 'notifications.dart';
import 'screens/foods.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/splash.dart';
import 'screens/profile.dart';
import 'store.dart';
import 'review.dart';
import 'theme.dart';
import 'toast.dart';

late final Billing billing;
late final Store store;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  billing = Billing();
  store = Store(billing);
  await billing.load();
  await billing.initStore(); // real build only: connects to App Store / Google Play
  await store.load();
  if (!Auth.demoSignIn) await Firebase.initializeApp(options: FirebaseConfig.current);
  await Auth.instance.load();
  await Analytics.instance.load();
  await NotificationLog.instance.load();
  await FeedbackLog.instance.load();
  await Notifier.init();
  Analytics.instance.log(Ev.opened);
  unawaited(InstallInfo.collect()); // Android: where the install came from. Never blocks the app.
  runApp(const UseItUpApp());
  store.refreshGeneralReminders(); // weekly overview + inactivity nudge, counted fresh
}

class UseItUpApp extends StatefulWidget {
  const UseItUpApp({super.key});

  @override
  State<UseItUpApp> createState() => _UseItUpAppState();
}

class _UseItUpAppState extends State<UseItUpApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app pushes the "you have been away" nudge out again.
    if (state == AppLifecycleState.resumed) {
      store.refreshGeneralReminders();
      store.purgeUsed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Use It Up: Food Expiry Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: rootMessenger,
      home: const _Gate(),
    );
  }
}

/// Brand splash for a moment, then onboarding (first run) or Home.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _splash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _splash
          ? const SplashScreen(key: ValueKey('splash'))
          : ListenableBuilder(
              key: const ValueKey('app'),
              listenable: Listenable.merge([store, Auth.instance]),
              // No guest accounts: after onboarding, nobody gets in without signing in.
              builder: (_, _) => !store.onboarded ? const OnboardingFlow() : (Auth.signedIn ? const Shell() : const SignInRequired()),
            ),
    );
  }
}

/// Ask the shell to open the Foods tab, on a given sub-tab (0 Foods, 1 Expired, 2 Used).
class FoodsRequest {
  final int subTab;
  FoodsRequest(this.subTab);
}

final ValueNotifier<FoodsRequest?> openFoods = ValueNotifier(null);

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  int _foodsSub = 0;
  int _foodsKey = 0; // changes when another screen asks for a specific Foods tab

  @override
  void initState() {
    super.initState();
    openFoods.addListener(_onRequest);
    WidgetsBinding.instance.addObserver(this);
    // Once a week, until they have rated: a small "Enjoying Use It Up?" question.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Review.maybeAskWeekly(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    openFoods.removeListener(_onRequest);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) Review.maybeAskWeekly(context);
  }

  void _onRequest() {
    final r = openFoods.value;
    if (r == null) return;
    setState(() {
      _tab = 1;
      _foodsSub = r.subTab;
      _foodsKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      FoodsScreen(key: ValueKey(_foodsKey), initialTab: _foodsSub),
      const ProfileScreen(),
    ];
    // Back goes to Home first. On Home it asks before leaving the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_tab != 0) {
          setState(() => _tab = 0);
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Leave Use It Up?'),
            content: const Text('Your food and reminders are saved.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true) SystemNavigator.pop();
      },
      child: Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.kitchen_outlined), selectedIcon: Icon(Icons.kitchen), label: 'Fridge'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    ));
  }
}
