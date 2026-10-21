import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../analytics.dart';
import '../auth.dart';
import '../config.dart';
import '../main.dart';
import '../notifications.dart';
import '../review.dart';
import '../theme.dart';
import '../toast.dart';
import 'paywall.dart';
import 'profile.dart' show openUrl;

/// Welcome > sign up > 3 questions > notification setup > soft paywall > Home.
/// The step is saved after every screen, so closing the app midway resumes here.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { welcome, signup, q1, q2, compare, q3, q4, notify, review, paywall }

/// The screens that share the progress bar at the top.
const _barSteps = [_Step.q1, _Step.q2, _Step.compare, _Step.q3, _Step.q4, _Step.review];

class _OnboardingFlowState extends State<OnboardingFlow> {
  late _Step _step = _Step.values[store.onbStep.clamp(0, _Step.values.length - 1)];

  void _go(_Step s) {
    setState(() => _step = s);
    store.saveOnboarding(step: s.index);
  }

  void _back() {
    if (_step.index > 0) _go(_Step.values[_step.index - 1]);
  }

  double _progress(_Step s) => (_barSteps.indexOf(s) + 1) / _barSteps.length;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _Step.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(_step), child: _screen()),
          ),
        ),
      ),
    );
  }

  Widget _screen() {
    switch (_step) {
      case _Step.welcome:
        return _Welcome(onStart: () {
          Analytics.instance.log(Ev.onboardingStarted);
          // Someone who already signed in, or already chose guest, is not asked again.
          _go(Auth.instance.provider != null ? _Step.q1 : _Step.signup);
        });
      case _Step.signup:
        return _SignUp(onBack: _back, onDone: () => _go(_Step.q1));
      case _Step.q1:
        return _Question(
          progress: _progress(_Step.q1),
          title: 'WHAT USUALLY\nGETS FORGOTTEN?',
          subtitle: 'Choose the one that sounds most like you.',
          options: const [
            _Opt('forget_fridge', "I forget what's in my fridge", icon: Icons.kitchen_outlined),
            _Opt('expires_first', 'Food expires before I use it', icon: Icons.timer_outlined),
            _Opt('buy_more', 'I buy more than I need', icon: Icons.shopping_cart_outlined),
            _Opt('leftovers', 'Leftovers get forgotten', icon: Icons.takeout_dining_outlined),
            _Opt('everything', 'A bit of everything', icon: Icons.apps_rounded),
          ],
          initial: store.problem,
          button: 'Continue',
          footer: 'Optional. You can continue without choosing.',
          onBack: _back,
          onNext: (v) {
            store.saveOnboarding(problem: v);
            _go(_Step.q2);
          },
          onSkip: () => _go(_Step.q2),
        );
      case _Step.q2:
        return _Question(
          progress: _progress(_Step.q2),
          title: 'HOW MANY PEOPLE\nARE YOU SHOPPING FOR?',
          subtitle: "We'll use this to tailor your food-saving suggestions.",
          options: const [
            _Opt('just_me', 'Just me', icon: Icons.person_outline),
            _Opt('two', '2 people', icon: Icons.people_outline),
            _Opt('three_four', '3–4 people', icon: Icons.groups_outlined),
            _Opt('five_plus', '5+ people', icon: Icons.diversity_3_outlined),
          ],
          initial: store.household,
          button: 'Continue',
          footer: 'Optional. You can continue without choosing.',
          onBack: _back,
          onNext: (v) {
            store.saveOnboarding(household: v);
            _go(_Step.compare);
          },
          onSkip: () => _go(_Step.compare),
        );
      case _Step.compare:
        return _Compare(progress: _progress(_Step.compare), onBack: _back, onNext: () => _go(_Step.q3));
      case _Step.q3:
        return _Question(
          progress: _progress(_Step.q3),
          title: 'WHEN SHOULD WE\nGIVE YOU A HEADS-UP?',
          subtitle: "Choose how early you'd like to know about food expiring soon.",
          options: const [
            _Opt('three', '3 days before', sub: 'More time to plan meals', icon: Icons.event_outlined),
            _Opt('one', '1 day before', sub: 'A helpful reminder, without too much noise', icon: Icons.today_outlined),
            _Opt('both', 'Both', sub: 'An early heads-up and a final reminder', icon: Icons.notifications_active_outlined),
          ],
          initial: store.remindWhen,
          button: 'Continue',
          footer: 'You can change this any time in Profile.',
          onBack: _back,
          onNext: (v) async {
            await store.saveOnboarding(remindWhen: v);
            await store.applyRemindChoice();
            _go(_Step.q4);
          },
          onSkip: () async {
            await store.applyRemindChoice();
            _go(_Step.q4);
          },
        );
      case _Step.q4:
        return _Question(
          progress: _progress(_Step.q4),
          title: 'WHERE DID YOU\nHEAR ABOUT US?',
          subtitle: 'This helps us reach more people who waste less food.',
          options: const [
            _Opt('tiktok', 'TikTok', icon: FontAwesomeIcons.tiktok),
            _Opt('instagram', 'Instagram', icon: FontAwesomeIcons.instagram),
            _Opt('youtube', 'YouTube', icon: FontAwesomeIcons.youtube),
            _Opt('facebook', 'Facebook', icon: FontAwesomeIcons.facebook),
            _Opt('store', 'App Store or Play Store', icon: Icons.storefront_outlined),
            _Opt('google', 'Google search', icon: FontAwesomeIcons.google),
            _Opt('friend', 'A friend or family', icon: Icons.people_alt_outlined),
            _Opt('other', 'Somewhere else', icon: Icons.more_horiz_rounded),
          ],
          initial: store.heardFrom,
          button: 'Continue',
          footer: 'Optional. You can continue without choosing.',
          onBack: _back,
          onNext: (v) async {
            await store.saveOnboarding(heardFrom: v);
            Analytics.instance.log(Ev.heardFrom, v);
            Analytics.instance.log(Ev.answered);
            _go(_Step.notify);
          },
          onSkip: () {
            Analytics.instance.log(Ev.answered);
            _go(_Step.notify);
          },
        );
      case _Step.notify:
        return _NotifySetup(onDone: () => _go(_Step.review));
      case _Step.review:
        return _ReviewStep(progress: _progress(_Step.review), onBack: _back, onDone: () => _go(_Step.paywall));
      case _Step.paywall:
        return PaywallScreen(fromOnboarding: true, onClose: () => store.finishOnboarding());
    }
  }
}

// ---------------------------------------------------------------- 1. Welcome

class _Welcome extends StatelessWidget {
  final VoidCallback onStart;
  const _Welcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return _ScrollFill(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        Image.asset('assets/brand/splash_icon.png', width: 76, height: 76),
        const SizedBox(height: 22),
        Text('YOUR FRIDGE\nCALLED.\nLET\'S SAVE\nYOUR FOOD.', style: display(52)),
        const SizedBox(height: 18),
        Text('Track expiry dates, get timely reminders, and waste less food without the hassle.',
            style: body(18)),
        const Spacer(flex: 2),
        FilledButton(style: limeButton(), onPressed: onStart, child: const Text('Get started')),
        const SizedBox(height: 12),
        Center(child: Text('Free to start · Takes less than a minute', style: body(13, FontWeight.w500, Colors.black54))),
      ]),
    ));
  }
}

// ---------------------------------------------------------------- 2. Sign up

/// The sign-up screen as a normal page. Used from Profile, for someone who started as a guest.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _SignUp(
          onBack: () => Navigator.of(context).pop(),
          onDone: () {
            Navigator.of(context).pop();
            toast(Auth.signedIn ? 'Signed in as ${Auth.displayName}' : 'Continuing as a guest');
          },
        ),
      ),
    );
  }
}

class _SignUp extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;
  const _SignUp({required this.onBack, required this.onDone});

  @override
  State<_SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<_SignUp> {
  String? _error;
  bool _busy = false;

  Future<void> _run(AuthProvider p, {String? email, String? name, String? password, bool create = true}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await Auth.instance.signIn(p, emailAddress: email, name: name, password: password, createAccount: create);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      Analytics.instance.log(Ev.signedUp, p.name);
      widget.onDone();
    } else {
      setState(() => _error = err);
    }
  }

  Future<void> _emailSheet() async {
    final nameC = TextEditingController();
    final c = TextEditingController();
    final passC = TextEditingController();
    final real = !AppConfig.mock; // a real build also asks for a password
    var create = true;
    String? note;
    final result = await showModalBottomSheet<(String, String, String, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ivory,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(!real ? 'Your name and email' : (create ? 'Create your account' : 'Welcome back'), style: body(20, FontWeight.w800)),
            const SizedBox(height: 4),
            Text(!real ? 'Demo build: no password needed.' : 'Use at least 6 characters for your password.',
                style: body(13.5, FontWeight.w400, Colors.black54)),
            const SizedBox(height: 14),
            if (create) ...[
              TextField(
                controller: nameC,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Your name'),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: c,
              keyboardType: TextInputType.emailAddress,
              textInputAction: real ? TextInputAction.next : TextInputAction.done,
              decoration: const InputDecoration(hintText: 'you@example.com'),
              onSubmitted: real ? null : (_) => Navigator.pop(ctx, (nameC.text, c.text, '', true)),
            ),
            if (real) ...[
              const SizedBox(height: 10),
              TextField(
                controller: passC,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password'),
                onSubmitted: (_) => Navigator.pop(ctx, (nameC.text, c.text, passC.text, create)),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note!, style: body(13, FontWeight.w600)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: limeButton(),
              onPressed: () => Navigator.pop(ctx, (nameC.text, c.text, passC.text, create)),
              child: Text(!real ? 'Continue' : (create ? 'Create account' : 'Sign in')),
            ),
            if (real) ...[
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                  onPressed: () => setSheet(() {
                    create = !create;
                    note = null;
                  }),
                  child: Text(create ? 'I already have an account' : 'Create a new account'),
                ),
                if (!create)
                  TextButton(
                    onPressed: () async {
                      final err = await Auth.instance.resetPassword(c.text);
                      setSheet(() => note = err ?? 'We sent a reset link to ${c.text.trim()}.');
                    },
                    child: const Text('Forgot password?'),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
    if (result != null && mounted) {
      await _run(AuthProvider.email, name: result.$1, email: result.$2, password: result.$3, create: result.$4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ScrollFill(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back), padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
        const Spacer(),
        Text("LET'S GET YOU\nSTARTED.", style: display(46)),
        const SizedBox(height: 14),
        Text('Save your food list and keep your reminders with you.', style: body(17)),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: darkButton(),
          onPressed: _busy ? null : () => _run(AuthProvider.apple),
          icon: const Icon(Icons.apple),
          label: const Text('Continue with Apple'),
        ),
        const SizedBox(height: 12),
        _outlined(Icons.g_mobiledata, 'Continue with Google', _busy ? null : () => _run(AuthProvider.google)),
        const SizedBox(height: 12),
        _outlined(Icons.mail_outline, 'Continue with email', _busy ? null : _emailSheet),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!, style: body(13.5))),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => _run(AuthProvider.guest),
            child: Text('Continue without an account', style: body(14.5, FontWeight.w700)),
          ),
        ),
        if (AppConfig.mock)
          Center(child: Text('Demo build: sign-in is simulated.', style: body(12, FontWeight.w500, Colors.black45))),
        const Spacer(flex: 2),
        Center(
          child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('By continuing, you agree to our ', style: body(12.5, FontWeight.w400, Colors.black54)),
            GestureDetector(
              onTap: () => openUrl(context, AppConfig.termsUrl),
              child: Text('Terms', style: body(12.5, FontWeight.w700).copyWith(decoration: TextDecoration.underline)),
            ),
            Text(' and ', style: body(12.5, FontWeight.w400, Colors.black54)),
            GestureDetector(
              onTap: () => openUrl(context, AppConfig.privacyUrl),
              child: Text('Privacy Policy', style: body(12.5, FontWeight.w700).copyWith(decoration: TextDecoration.underline)),
            ),
            Text('.', style: body(12.5, FontWeight.w400, Colors.black54)),
          ]),
        ),
      ]),
    ));
  }

  Widget _outlined(IconData icon, String label, VoidCallback? onTap) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: charcoal,
          backgroundColor: cardWhite,
          side: const BorderSide(color: charcoal, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: body(16, FontWeight.w600),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 26),
        label: Text(label),
      );
}

// ---------------------------------------------------------- Question screens

class _Opt {
  final String id;
  final String label;
  final String? sub;
  final Object? icon; // a Material icon, or a Font Awesome brand icon
  const _Opt(this.id, this.label, {this.sub, this.icon});
}

/// Back button, a progress bar and Skip. The same on every question screen.
class _TopBar extends StatelessWidget {
  final double progress;
  final VoidCallback onBack;
  final VoidCallback? onSkip;
  const _TopBar({required this.progress, required this.onBack, this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton.filled(
        style: IconButton.styleFrom(backgroundColor: cardWhite, foregroundColor: charcoal, fixedSize: const Size(46, 46)),
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 350),
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 9, color: charcoal, backgroundColor: const Color(0xFFD9D8CC)),
          ),
        ),
      ),
      const SizedBox(width: 6),
      if (onSkip != null)
        TextButton(onPressed: onSkip, child: Text('Skip', style: body(15, FontWeight.w700)))
      else
        const SizedBox(width: 12),
    ]);
  }
}

class _Question extends StatefulWidget {
  final double progress;
  final String title;
  final String subtitle;
  final List<_Opt> options;
  final String? initial;
  final String button;
  final String footer;
  final VoidCallback onBack;
  final void Function(String value) onNext;
  final VoidCallback onSkip;

  const _Question({
    required this.progress,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.initial,
    required this.button,
    required this.footer,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<_Question> createState() => _QuestionState();
}

class _QuestionState extends State<_Question> {
  late String? _sel = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TopBar(progress: widget.progress, onBack: widget.onBack, onSkip: widget.onSkip),
        const SizedBox(height: 22),
        Text(widget.title, style: display(34)),
        const SizedBox(height: 8),
        Text(widget.subtitle, style: body(15, FontWeight.w400, Colors.black54)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(children: [
            for (final (i, o) in widget.options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OptionRow(number: i + 1, opt: o, selected: _sel == o.id, onTap: () => setState(() => _sel = _sel == o.id ? null : o.id)),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        // Always active: with no choice made, Continue simply moves on.
        FilledButton(
          style: limeButton(),
          onPressed: () => _sel == null ? widget.onSkip() : widget.onNext(_sel!),
          child: Text(widget.button),
        ),
        const SizedBox(height: 8),
        Center(child: Text(widget.footer, style: body(12.5, FontWeight.w400, Colors.black54))),
      ]),
    );
  }
}

/// One answer: a number, an icon and the words.
class _OptionRow extends StatelessWidget {
  final int number;
  final _Opt opt;
  final bool selected;
  final VoidCallback onTap;
  const _OptionRow({required this.number, required this.opt, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: opt.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
          decoration: BoxDecoration(
            color: selected ? lime.withValues(alpha: 0.55) : cardWhite,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? charcoal : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: selected ? charcoal : const Color(0xFFE8E7DC), shape: BoxShape.circle),
              child: Text('$number', style: body(17, FontWeight.w700, selected ? lime : Colors.black54)),
            ),
            const SizedBox(width: 14),
            if (opt.icon != null) ...[
              SizedBox(
                width: 26,
                child: Center(
                  child: opt.icon is FaIconData
                      ? FaIcon(opt.icon as FaIconData, size: 22, color: charcoal)
                      : Icon(opt.icon as IconData, size: 24, color: charcoal),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(opt.label, style: body(16.5, FontWeight.w700)),
                if (opt.sub != null) Text(opt.sub!, style: body(13, FontWeight.w400, Colors.black54)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "With Use It Up vs on your own". It makes no number up: the bars show the idea, not a measurement.
class _Compare extends StatelessWidget {
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _Compare({required this.progress, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TopBar(progress: progress, onBack: onBack, onSkip: null),
        const SizedBox(height: 22),
        Text('WASTE LESS FOOD WITH\nUSE IT UP VS ON YOUR OWN', style: display(30)),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(28)),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text('On your\nown', textAlign: TextAlign.center, style: body(15, FontWeight.w600, Colors.black45))),
                Expanded(child: Text('With\nUse It Up', textAlign: TextAlign.center, style: body(15, FontWeight.w800))),
              ]),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: _GrowBar(fraction: 0.16, colors: const [Color(0xFFE6E6EA), Color(0xFFE6E6EA)])),
                  const SizedBox(width: 14),
                  Expanded(child: _GrowBar(fraction: 1, colors: const [Color(0xFFB7DD2E), lime])),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Pill('Forgotten', const Color(0xFFD9D9DE), Colors.black54)),
                Expanded(child: _Pill('Used in time', charcoal, lime)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text('Use It Up reminds you before your food expires, so you eat it in time.',
              textAlign: TextAlign.center, style: body(14.5, FontWeight.w400, Colors.black54)),
        ),
        const SizedBox(height: 14),
        FilledButton(style: limeButton(), onPressed: onNext, child: const Text('Continue')),
      ]),
    );
  }
}

class _GrowBar extends StatelessWidget {
  final double fraction;
  final List<Color> colors;
  const _GrowBar({required this.fraction, required this.colors});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: (c.maxHeight - 8) * v + 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            ),
          ),
        ),
      );
    });
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
          child: Text(text, style: body(15, FontWeight.w700, fg)),
        ),
      );
}

/// Asks for a rating. "Rate us" opens the store's own rating box.
class _ReviewStep extends StatelessWidget {
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onDone;
  const _ReviewStep({required this.progress, required this.onBack, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(children: [
        _TopBar(progress: progress, onBack: onBack, onSkip: null),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Icon(Icons.star_rounded, size: 50, color: Color(0xFFF5B800))),
        ]),
        const SizedBox(height: 22),
        Text('GIVE US A\nRATING', textAlign: TextAlign.center, style: display(46)),
        const SizedBox(height: 12),
        Text('Your rating helps more people find Use It Up and waste less food.', textAlign: TextAlign.center, style: body(16, FontWeight.w400, Colors.black54)),
        const Spacer(flex: 2),
        FilledButton(
          style: limeButton(),
          onPressed: () async {
            await Review.rateNow(context);
            onDone();
          },
          child: const Text('Rate us'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () async {
            await Review.markAsked(); // we will ask again in a week
            onDone();
          },
          child: Text('Not now', style: body(15.5, FontWeight.w700)),
        ),
      ]),
    );
  }
}


// ----------------------------------------------------- 4. Notification setup

class _NotifySetup extends StatefulWidget {
  final VoidCallback onDone;
  const _NotifySetup({required this.onDone});

  @override
  State<_NotifySetup> createState() => _NotifySetupState();
}

class _NotifySetupState extends State<_NotifySetup> {
  bool _busy = false;
  bool _denied = false;

  Future<void> _ask() async {
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await Notifier.requestPermission();
    } catch (_) {}
    await store.saveOnboarding(notifAsked: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Analytics.instance.log(Ev.notifAllowed);
    if (ok || !Notifier.supported) {
      widget.onDone();
    } else {
      // Keep the saved choice. Tell the user how to switch it on later.
      setState(() => _denied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ScrollFill(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
          child: const Icon(Icons.notifications_active_outlined, size: 42),
        ),
        const SizedBox(height: 24),
        Text('NEVER MISS\nA DATE.', style: display(48)),
        const SizedBox(height: 14),
        Text("We'll remind you before your food's expiry date, so you have time to use it.", style: body(18)),
        if (_denied) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(16)),
            child: Text(
              'No problem. Your reminder choice is saved. To get reminders later, open your phone Settings > Apps > Use It Up > Notifications and turn them on.',
              style: body(14),
            ),
          ),
        ],
        const Spacer(flex: 2),
        if (!_denied) ...[
          FilledButton(
            style: limeButton(),
            onPressed: _busy ? null : _ask,
            child: Text(Notifier.supported ? 'Turn on reminders' : 'Continue'),
          ),
          const SizedBox(height: 6),
          Center(child: TextButton(onPressed: _busy ? null : widget.onDone, child: Text('Not now', style: body(15, FontWeight.w700)))),
        ] else
          FilledButton(style: limeButton(), onPressed: widget.onDone, child: const Text('Continue')),
      ]),
    ));
  }
}

/// Fills the screen, so Spacers work, and scrolls when the screen is too short.
class _ScrollFill extends StatelessWidget {
  final Widget child;
  const _ScrollFill({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
