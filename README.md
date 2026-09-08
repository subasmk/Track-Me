# TrackMe

A Duolingo-inspired learning consistency tracker built with Flutter. Create goals
(AWS, DSA, Maths, Flutter, ...), complete a short check-in each day describing
what you learned, keep a streak alive, and watch it from a home-screen widget —
all fully offline, stored locally with Hive.

Package: `com.trackme.app` · Android only · Material 3 · No backend.

---

## 1. Setup & run

Requirements: Flutter 3.24+ (Dart 3.3+), Android Studio (or just the Android
SDK + a device/emulator), JDK 17.

```bash
flutter pub get
flutter run
```

That's it — no `build_runner` step is required. The generated Hive adapters
(`goal.g.dart`, `learning_note.g.dart`) are checked in already so the project
builds immediately. If you later add or change a `@HiveField` in
`lib/models/`, regenerate them with:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**First build note:** `android/local.properties` is intentionally *not*
included (it's machine-specific and normally git-ignored). Flutter/Android
Studio generates it automatically on first build, pointing at your local
Android SDK and Flutter install. If you ever see `flutter.sdk not set`, run
`flutter run` once from the command line, or open the project in Android
Studio and let it sync.

**Release builds:** `android/app/build.gradle` currently signs release builds
with the debug keystore so `flutter run --release` works out of the box for
testing. Before publishing, add your own `signingConfig`.

### Trying the home-screen widgets
1. Run the app and create a goal.
2. Long-press your home screen → **Widgets** → **TrackMe** — you'll see two
   entries: the single-goal widget (resizable Small ↔ Medium) and the
   overview widget (Large).
3. Dragging the single-goal widget out opens a **pick a goal** screen — each
   widget instance tracks one goal, so you can place several side by side.
4. Complete a goal in-app and the widget(s) update immediately — no manual
   refresh, no polling.

---

## 2. Project structure

```
trackme_modified/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── goal.dart              Hive model: streak/XP/level/notes state
│   │   ├── goal.g.dart            Generated Hive TypeAdapter (checked in)
│   │   ├── learning_note.dart     Hive model: one day's "what I learned" entry
│   │   ├── learning_note.g.dart   Generated Hive TypeAdapter (checked in)
│   │   └── achievement.dart       Static badge catalog + unlock conditions
│   ├── services/
│   │   ├── hive_service.dart      Hive.init, adapter registration, box access
│   │   ├── goal_service.dart      Single source of truth (ChangeNotifier):
│   │   │                          add/update/delete/complete, search, badges
│   │   ├── settings_service.dart  Persisted display name + onboarding flag
│   │   └── home_widget_service.dart  Pushes goal data to the Android widgets
│   ├── utils/
│   │   ├── date_utils_x.dart      Same-day / yesterday / week-strip helpers
│   │   └── streak_logic.dart      All streak/XP/level math, in one place
│   ├── theme/
│   │   ├── app_colors.dart        Full palette (mirrored 1:1 in Android colors.xml)
│   │   ├── app_spacing.dart       Spacing/radius tokens
│   │   └── app_theme.dart         Material 3 ThemeData + text style scale
│   ├── widgets/
│   │   ├── sloth_mascot.dart      CustomPainter sloth (idle/happy/celebrating)
│   │   ├── streak_card.dart       Home screen hero card + week strip
│   │   ├── goal_list_card.dart    Per-goal row on the home screen
│   │   └── goal_heatmap_calendar.dart  Month calendar, purple = day completed
│   └── screens/
│       ├── home/home_screen.dart
│       ├── add_goal/add_goal_screen.dart
│       ├── goal_detail/
│       │   ├── goal_detail_screen.dart   Streak, notes, Complete Today flow
│       │   └── celebration_screen.dart   Post-completion confetti screen
│       ├── notes/notes_screen.dart       Full timeline + search across all goals
│       └── achievements/achievements_screen.dart
└── android/
    ├── settings.gradle, build.gradle, gradle.properties, gradle/…
    └── app/
        ├── build.gradle
        └── src/main/
            ├── AndroidManifest.xml
            ├── kotlin/com/trackme/app/
            │   ├── MainActivity.kt
            │   ├── TrackMeGoalWidgetProvider.kt      Small/Medium single-goal widget
            │   ├── TrackMeOverviewWidgetProvider.kt  Large multi-goal widget
            │   └── WidgetConfigureActivity.kt        "Pick a goal" native picker
            └── res/
                ├── layout/           widget_goal.xml, widget_overview.xml, …
                ├── xml/              AppWidgetProviderInfo for both widgets
                ├── drawable/         gradients, day-pill states, sloth icon
                ├── mipmap-anydpi-v26/ + drawable/ic_launcher_*  adaptive icon
                └── values/           colors.xml, strings.xml, styles.xml
```

---

## 3. How the pieces fit together

**Data model.** Everything lives in one Hive box of `Goal` objects; each
`Goal` embeds its own `List<LearningNote>` directly (no separate box/join),
since notes always belong to exactly one goal and are always read alongside
it. `GoalService` is the *only* place that mutates a `Goal` — every screen
reads through it via `provider`, so streak/XP/badge rules can't drift between
screens.

**Streak logic** (`utils/streak_logic.dart`) is intentionally isolated from
both the UI and Hive: `completeToday()` blocks a second completion the same
day, bumps the streak only if the previous completion was yesterday
(otherwise resets to 1), tracks the longest streak, and awards XP/levels.
`reconcileMissedDay()` runs once at startup so a streak silently broken while
the app was closed shows correctly the next time it's opened, not just after
the next completion attempt.

**Gamification.** XP is `10 + 2×⌊dailyMinutes/10⌋` per completion; levels use
a simple `level × 100` cumulative curve. Badges (`models/achievement.dart`)
are pure functions of `(streak, longestStreak, xp, level)` — nothing extra to
keep in sync, and re-checking them is just re-evaluating the list.

**The Android widgets don't poll.** `HomeWidgetService.syncGoals()` is called
after every add/edit/delete/complete and writes one JSON blob (all goals,
including a Sunday-first `week: [bool×7]` completion array per goal) plus a
couple of summary ints into the SharedPreferences the `home_widget` plugin
manages, then asks Android to redraw both widget types. `updatePeriodMillis`
is `0` in both `AppWidgetProviderInfo` XMLs on purpose — there's nothing for
a timer to refresh.

**Single-goal widget sizing.** Rather than maintaining separate "Small" and
"Medium" layout files, `widget_goal.xml` contains both the compact and
expanded content, and `TrackMeGoalWidgetProvider` toggles the title/week-strip
visibility in `onAppWidgetOptionsChanged` based on the measured width. This
is the same widget instance the user resizes by dragging, matching how
resizable widgets behave elsewhere on Android.

**Per-goal widget binding.** When a single-goal widget is placed,
`android:configure` launches `WidgetConfigureActivity` — a small native
(non-Flutter) screen that reads the same shared goals JSON, shows a plain
list, and on selection stores `appWidgetId → goalId` in its own dedicated
SharedPreferences file (`WidgetConfig` in `TrackMeGoalWidgetProvider.kt`).
That mapping is what lets two widget instances track two different goals.

**Tapping a widget** opens the app via `HomeWidgetLaunchIntent` carrying a
`trackme://goal?id=<id>` URI; `main.dart` listens for it via
`HomeWidget.widgetClicked` (already-running case) and
`HomeWidget.initiallyLaunchedFromHomeWidget()` (cold-start case) and pushes
straight to that goal's detail screen.

**Zero image assets.** The sloth mascot is a `CustomPainter` in Flutter
(`widgets/sloth_mascot.dart`) and a hand-written vector drawable on the
Android side (`res/drawable/ic_sloth_face.xml`) — same palette and
proportions in both places, but no PNG/SVG asset files to go missing. The
adaptive launcher icon is built the same way (`ic_launcher_background.xml` +
`ic_launcher_foreground.xml`), so there's nothing to regenerate at different
densities.

---

## 4. Notes on going further

- **Not yet wired up:** local daily reminder notifications. The spec didn't
  ask for these, but `dailyMinutes` per goal would make a natural trigger if
  you want to add `flutter_local_notifications` later.
- **Widget click → specific goal** is implemented for both widget types
  (see above) rather than just opening the app generically, since it's a
  small addition that makes multi-goal widget setups meaningfully nicer.
- **Testing:** this was built and statically verified (every `R.id`/
  `R.layout`/`R.drawable`/`R.string` reference cross-checked against actual
  resources, every Dart import resolved, all XML validated as well-formed)
  in an environment without a Flutter/Android toolchain to compile against.
  Run `flutter analyze` after `pub get` as a first check on a real machine.
