import 'package:flutter/material.dart';
import '../auth.dart';
import '../config.dart';
import '../main.dart';
import '../notifications.dart';
import '../theme.dart';
import 'paywall.dart';
import 'profile.dart' show openUrl;

/// Welcome > sign up > 3 questions > notification setup > soft paywall > Home.
/// The step is saved after every screen, so closing the app midway resumes here.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { welcome, signup, q1, q2, q3, notify, paywall }

class _OnboardingFlowState extends State<OnboardingFlow> {
  late _Step _step = _Step.values[store.onbStep.clamp(0, _Step.values.length - 1)];

  void _go(_Step s) {
    setState(() => _step = s);
    store.saveOnboarding(step: s.index);
  }

  void _back() {
    if (_step.index > 0) _go(_Step.values[_step.index - 1]);
  }

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
        return _Welcome(onStart: () => _go(_Step.signup));
      case _Step.signup:
        return _SignUp(onBack: _back, onDone: () => _go(_Step.q1));
      case _Step.q1:
        return _Question(
          kicker: 'PERSONALIZE YOUR EXPERIENCE',
          index: 1,
          title: 'WHAT USUALLY\nGETS FORGOTTEN?',
          subtitle: 'Choose the one that sounds most like you.',
          options: const [
            _Opt('forget_fridge', "I forget what's in my fridge"),
            _Opt('expires_first', 'Food expires before I use it'),
            _Opt('buy_more', 'I buy more than I need'),
            _Opt('leftovers', 'Leftovers get forgotten'),
            _Opt('everything', 'A bit of everything'),
          ],
          initial: store.problem,
          button: 'Continue',
          footer: 'You can change your preferences later.',
          onBack: _back,
          onNext: (v) {
            store.saveOnboarding(problem: v);
            _go(_Step.q2);
          },
          onSkip: () => _go(_Step.q2),
        );
      case _Step.q2:
        return _Question(
          kicker: 'YOUR HOUSEHOLD',
          index: 2,
          title: 'HOW MANY PEOPLE\nARE YOU SHOPPING FOR?',
          subtitle: "We'll use this to tailor your food-saving suggestions.",
          options: const [
            _Opt('just_me', 'Just me'),
            _Opt('two', '2 people'),
            _Opt('three_four', '3–4 people'),
            _Opt('five_plus', '5+ people'),
          ],
          initial: store.household,
          button: 'Continue',
          footer: 'Optional. You can skip this.',
          onBack: _back,
          onNext: (v) {
            store.saveOnboarding(household: v);
            _go(_Step.q3);
          },
          onSkip: () => _go(_Step.q3),
        );
      case _Step.q3:
        return _Question(
          kicker: 'YOUR REMINDERS',
          index: 3,
          title: 'WHEN SHOULD WE\nGIVE YOU A HEADS-UP?',
          subtitle: "Choose how early you'd like to know about food expiring soon.",
          options: const [
            _Opt('three', '3 days before', 'More time to plan meals'),
            _Opt('one', '1 day before', 'A helpful reminder, without too much noise'),
            _Opt('both', 'Both', 'An early heads-up and a final reminder'),
          ],
          initial: store.remindWhen,
          button: 'Finish setup',
          footer: 'You can change this any time in Profile.',
          onBack: _back,
          onNext: (v) async {
            await store.saveOnboarding(remindWhen: v);
            await store.applyRemindChoice();
            _go(_Step.notify);
          },
          onSkip: () async {
            await store.applyRemindChoice();
            _go(_Step.notify);
          },
        );
      case _Step.notify:
        return _NotifySetup(onDone: () => _go(_Step.paywall));
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

// ---------------------------------------------------------- 3-5. Questions

class _Opt {
  final String id;
  final String label;
  final String? sub;
  const _Opt(this.id, this.label, [this.sub]);
}

class _Question extends StatefulWidget {
  final String kicker;
  final int index; // 1..3
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
    required this.kicker,
    required this.index,
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
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back), padding: EdgeInsets.zero),
          const Spacer(),
          TextButton(onPressed: widget.onSkip, child: Text('Skip', style: body(15, FontWeight.w700))),
        ]),
        Text(widget.kicker, style: body(12, FontWeight.w800, Colors.black54).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i <= widget.index ? charcoal : const Color(0xFFD9D8CC),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Text('${widget.index} of 3', style: body(12.5, FontWeight.w700)),
        ]),
        const SizedBox(height: 22),
        Text(widget.title, style: display(34)),
        const SizedBox(height: 8),
        Text(widget.subtitle, style: body(15, FontWeight.w400, Colors.black54)),
        const SizedBox(height: 18),
        Expanded(
          child: ListView(children: [
            for (final o in widget.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OptionCard(opt: o, selected: _sel == o.id, onTap: () => setState(() => _sel = o.id)),
              ),
          ]),
        ),
        const SizedBox(height: 8),
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

class _OptionCard extends StatelessWidget {
  final _Opt opt;
  final bool selected;
  final VoidCallback onTap;
  const _OptionCard({required this.opt, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: opt.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? lime.withValues(alpha: 0.5) : cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? charcoal : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(opt.label, style: body(16.5, FontWeight.w700)),
                if (opt.sub != null) Text(opt.sub!, style: body(13, FontWeight.w400, Colors.black54)),
              ]),
            ),
            const SizedBox(width: 10),
            Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? charcoal : Colors.black38),
          ]),
        ),
      ),
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
