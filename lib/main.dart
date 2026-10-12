import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'analytics.dart';
import 'billing.dart';
import 'notification_log.dart';
import 'notifications.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/profile.dart';
import 'store.dart';
import 'theme.dart';

late final Billing billing;
late final Store store;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  billing = Billing();
  store = Store(billing);
  await billing.load();
  await store.load();
  await Analytics.instance.load();
  await NotificationLog.instance.load();
  await Notifier.init();
  Analytics.instance.log(Ev.opened);
  runApp(const UseItUpApp());
}

class UseItUpApp extends StatelessWidget {
  const UseItUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Use It Up: Food Expiry Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: store,
        builder: (_, _) => store.onboarded ? const Shell() : const OnboardingScreen(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), ProfileScreen()];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
