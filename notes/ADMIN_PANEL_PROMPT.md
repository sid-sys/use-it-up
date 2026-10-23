# Admin panel prompt

Copy this file into any app's project folder, then tell the AI:
"Follow ADMIN_PANEL_PROMPT.md."

---

You are working inside my app's project folder. Build an admin panel
for this app. Do not ask me for the app name, colours or steps.
Find them in the code.

## STEP 1: LEARN THE APP (read first, do not write code yet)

Look through the project (README, app config, theme files, assets,
onboarding screens, paywall screens, analytics code, database or
backend setup) and work out:

1. The app name and what it does, in one line.
2. The brand colours: primary, secondary, background, text. Take them
   from the theme or logo files. Note if the app is light or dark.
3. The onboarding steps, in order.
4. The first key action: the first thing a user does that shows they
   understood the app (for example "created a project").
5. The paywall and the plans (monthly, yearly, lifetime, free trial).
6. Which events the app already records, and where user data is
   stored.

Tell me what you found in a short list, then continue.

## STEP 2: BUILD THE ADMIN PANEL

Use the same language, framework and style as the app. Use the app's
brand colours for the whole panel: primary for buttons, active chips,
chart lines and links, secondary for highlights, a slightly different
shade of the background for cards. Keep text readable (contrast at
least 4.5:1). Show the logo small at the top. Real data only, nothing
invented. Phone width first, then a wider two-column layout.

### Screen 1: Dashboard

- Title "Admin panel", a refresh button, who is logged in.
- A switch "Real users only", ON by default. It hides fake accounts,
  my own account and robots from EVERY number, chart, list and funnel
  in the panel, and says how many it hides: "Hiding 10 test, review
  and my own accounts". Tapping that line lists the hidden accounts,
  each with the reason it was hidden, so I can check nothing real is
  hidden. Turning the switch off shows everything.
  Keep the rules in ONE config file (my admin email, the review
  team's email, the test-robot email domains) so I can edit them
  without touching screens. Hide an account when ANY of these is true:
  1. It is my own account (the admin email). Reason: "Your own
     account". My taps must not count as customers.
  2. It is the store review team's login. Reason: "Play review login".
  3. Its email ends with a known test-robot domain, for example
     `@cloudtestlabaccounts.com` (Firebase Test Lab, Google's test
     robots). Reason: "Google test robot".
  4. Its name or email looks like a robot sign-up: the name is the
     review login's email, or the email looks like `testuser12345@...`.
     Reason: "Play review robot" or "Automated test".
  5. Its purchase was made by a store license tester (the store's
     server says "test purchase"). Reason: "Test purchase".
  6. It finished the onboarding tour in under 25 seconds. Nobody can
     read and answer that fast. Reason: "Looks like a robot".
  Never hide a real person. If a rule might hit a real person, show
  the reason on the row instead of hiding silently. The device chart
  also uses this switch: count only phones whose owner is not hidden.
- Number cards, each opens the user list for that group: Total users,
  Subscribed, Active today, Revenue (last 30 days), Profit before store
  cut, Profit after store cut.
- ONE chart card with a TOGGLE (a two-option switch at the top of the
  card): "Active users" | "Installs and uninstalls". It is one card
  in one place. Do not make two separate charts or any extra tabs
  or screens. Pressing the toggle swaps the bars inside the same card.
  Last 30 days, one bar group per day.
  * "Active users" view: one bar per day = how many people opened the
    app that day.
  * "Installs and uninstalls" view: per day one green bar (installed)
    and one red bar (uninstalled), with the number on top of each, and
    under the day the net result in words: "Net gain" (+N), "Net loss"
    (-N) or "No change" (0).
  TAP A BAR, SEE THE PEOPLE (this is the main point): tapping a bar
  opens, directly, the list of the real people behind that bar. No
  extra tabs, buttons or day screens in between. The list title says
  what and when, e.g. "Installed on Tue 14 Oct", "Uninstalled on
  Wed 15 Oct" or "Active on Mon 12 Oct". A bar tapped with zero shows
  "Nobody installed that day" (or uninstalled / active).
  Each row of the list shows who they really are: their real name and
  email, plan badge and the time. Tapping a row opens that person's
  screen (Screen 3). "Installed" people are the people who signed up
  or opened the app for the first time on that day.

  HOW INSTALLS AND UNINSTALLS ARE COUNTED (build it exactly like this,
  and add a small "How is this counted?" note on the chart that says
  the same in plain words):
  1. Each phone that has the app reports itself to the server once a
     day. The server keeps ONE record per phone in a `devices`
     collection: a random install id made by the app the first time
     (so a phone counts once, however many accounts use it), the
     install time that Android itself reports for the app (so a
     phone that only updated the app still counts on its real install
     day, not the update day), the account that last logged in on
     that phone (the "owner"), the phone's push address, and when the
     phone was last seen.
  2. Install on day D = a phone whose recorded install time falls on
     day D. The person shown is the phone's owner.
  3. Uninstall = the server finds the app is gone. When an app is
     removed, Google stops accepting that phone's push address. Once a
     day (for example at 04:00) the server asks Google to check every
     push address as a "dry run" (nothing is delivered, nobody gets a
     message). If Google answers "not registered" or "invalid address",
     the phone is marked uninstalled with that day's date. It never
     marks a phone on a guess: only on Google's own answer.
  4. Honest limits, shown in the "How is this counted?" note: an
     uninstall can show a day or two late, and a phone that was off for
     a long time is only noticed once Google answers. If the phone
     reports in again later, it was not gone after all: remove the
     uninstall mark (a reinstall counts as a new install day).
  5. Net for a day = installs minus uninstalls.
  6. With the switch "Real users only" on, count only phones whose
     owner is a real member (not a test account, my own account, a
     robot or a review account).
  7. The phone's device record may only be written by the server (a
     cloud function), never directly by the app, so nobody can fill
     the chart with made-up installs.
  This works for Android. If the app is on iOS or the web, say what
  can and cannot be measured there, and do not invent numbers.
- Funnel "From joining to subscribing", using THIS app's real steps,
  with the count and percent at each step and where most people drop
  off: Installed, Opened the app, each onboarding step that matters,
  the first key action, Saw the paywall, Tried to pay, Subscribed.
- Block "When paying did not happen": cancelled, failed, store not
  available, with the reasons.
- Block "Where people heard about us": bars per source. Tap a bar to
  see the people. (If the app does not ask this, add that question to
  onboarding and save the answer.)
- Buttons: "See all N users" and "Feedback and bug reports".

### Screen 2: All users

- Search (name or email). Filter chips: All, Subscribed, Free, Active
  today. Sort: Signed up, Last seen, Installed, Uninstalled.
- Row: initials avatar, the person's REAL name, and under it their real
  email, plan badge, joined date, last seen, tags such as "Guest" and
  "Test purchase".

### How to show a person's name (applies to EVERY list, chart popup
### and screen in the panel)

- Use the real name they gave. If they gave none, show their real
  email. If they have neither (a guest who never signed up), show
  "Guest" plus the first 6 characters of their account id, e.g.
  "Guest 3f9a2c".
- NEVER invent names. No fake or mock names (like "Calm Otter" or
  "John Smith"), and no numbered names like "User 1", "User 2",
  "Person 3". If the data is missing, say so ("No name").
- Search must find people by real name or email.

### Screen 3: One user

- Header: avatar, name, email, country, Guest or Signed up, plan.
- "Journey": a vertical timeline of the funnel steps with ticks and
  times.
- "What they told us": the onboarding answers, one per line.
- "Activity": events, newest first.

### Screen 4: Feedback

- List of feedback and bug reports with a "handled" tick.

## RULES

- Security first. Hiding a button is NOT security. Only the owner may
  read this data, and the server must enforce it (database rules or an
  admin check on every API call). Check the caller's verified account
  on the server, never anything the app sends. The panel is read-only.
- Money numbers come from the store's server check (for example Google
  Play's server API), never from what the phone says. Purchases the
  store marks as test are hidden from the counts.
- If an event you need is not recorded yet, add recording for it in
  the app, and say which ones you added.
- Empty states say what is missing, e.g. "No installs yet".
- Plain English labels, no technical words.
- When done, list the files you made, what you could not do, and the
  setup steps I must do myself (keys, permissions, rules).
