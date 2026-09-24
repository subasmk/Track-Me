import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';

import 'services/hive_service.dart';
import 'services/home_widget_service.dart';
import 'services/goal_service.dart';
import 'services/quest_service.dart';
import 'services/settings_service.dart';
import 'services/progression_service.dart';
import 'services/reminder_service.dart';
import 'services/supabase_service.dart';
import 'screens/auth/claim_data_screen.dart';
import 'screens/auth/setup_profile_screen.dart';
import 'theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/goal_detail/goal_detail_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/quests/quests_screen.dart';
import 'screens/quests/quest_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();
  await ReminderService.init();

  // Force the whole app into dark mode at the system-chrome level so the
  // premium dark theme is consistent regardless of the device's system
  // setting.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF070D1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TrackMeApp());
}

class TrackMeApp extends StatefulWidget {
  const TrackMeApp({super.key});

  @override
  State<TrackMeApp> createState() => _TrackMeAppState();
}

class _TrackMeAppState extends State<TrackMeApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final GoalService _goalService;
  late final QuestService _questService;
  late final ProgressionService _progression;
  late final SettingsService _settingsService;
  late final SupabaseService _supabaseService;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _goalService = GoalService();
    _progression = ProgressionService(HiveService.settingsBox);
    _questService = QuestService(progression: _progression);
    ReminderService.rescheduleAll(_questService.quests);
    _settingsService = SettingsService();
    _supabaseService = SupabaseService();
    _supabaseService.onLocalDataReplaced = _reloadAccountData;

    // Initialize Supabase in background
    _supabaseService.initSupabase();

    // Keep the widget username copy in sync with SettingsService.
    _goalService.setUserName(_settingsService.userName);
    _supabaseService.updateUsername(_settingsService.userName);

    _settingsService.addListener(_onSettingsChanged);
    _goalService.addListener(_onDataChanged);
    _questService.addListener(_onDataChanged);

    _applyWidgetCheckOffs();
    HomeWidgetService.saveWidgetStyle(
        style: _settingsService.widgetStyle, bgPath: _settingsService.widgetBgPath);

    // Tapping a goal's home-screen widget should open that goal directly.
    _handleInitialWidgetLaunch();
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The day may have rolled over while TrackMe sat in the background:
    // reset yesterday's sub-task ticks and refresh the home-screen widget.
    if (state == AppLifecycleState.resumed) {
      _questService.refreshForNewDay();
      _applyWidgetCheckOffs();
    }
  }

  /// Applies check-offs made from the widget's check button.
  Future<void> _applyWidgetCheckOffs() async {
    final items = await HomeWidgetService.takePendingCheckOffs();
    for (final item in items) {
      if (item.kind == 'quest_item') {
        final sep = item.id.indexOf(':');
        if (sep > 0) {
          await _questService.toggleQuestItem(item.id.substring(0, sep), item.id.substring(sep + 1));
        }
      } else if (item.kind == 'quest') {
        await _questService.completeToday(item.id);
      } else {
        final goal = _goalService.goalById(item.id);
        if (goal != null && !goal.isCompletedToday) {
          await _goalService.completeToday(goal, 'Checked off from the home screen widget');
        }
      }
    }
    if (items.isNotEmpty) await _questService.syncWidget();
  }

  /// The live data now belongs to another account: reload every service
  /// and push the new data to the home-screen widgets.
  void _reloadAccountData() {
    _settingsService.reloadFromDisk();
    _progression.reload();
    _goalService.setUserName(_settingsService.userName);
    _goalService.notifyExternalChange();
    _questService.reloadFromDisk();
    ReminderService.rescheduleAll(_questService.quests);
    HomeWidgetService.saveWidgetStyle(
        style: _settingsService.widgetStyle, bgPath: _settingsService.widgetBgPath);
  }

  void _onSettingsChanged() {
    _goalService.setUserName(_settingsService.userName);
    _supabaseService.updateUsername(_settingsService.userName);
    _onDataChanged(); // privacy toggles change what the cloud profile shows
  }

  void _onDataChanged() {
    _supabaseService.syncLocalProfileToCloud(
      goals: _goalService.goals,
      quests: _questService.quests,
      shareQuests: _settingsService.shareQuests,
      discoverable: _settingsService.discoverable,
      fullName: _settingsService.fullName,
      bio: _settingsService.bio,
      photoPath: _settingsService.photoPath,
    );
  }

  Future<void> _handleInitialWidgetLaunch() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetUri(uri);
  }

  void _handleWidgetUri(Uri? uri) {
    final route = widgetRouteFor(uri);
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      switch (route.kind) {
        case WidgetRouteKind.goal:
          if (_goalService.goalById(route.id!) == null) return;
          nav.push(MaterialPageRoute(
              builder: (_) => GoalDetailScreen(goalId: route.id!)));
        case WidgetRouteKind.quests:
          nav.push(MaterialPageRoute(builder: (_) => const QuestsScreen()));
        case WidgetRouteKind.quest:
          if (_questService.questById(route.id!) == null) {
            nav.push(MaterialPageRoute(builder: (_) => const QuestsScreen()));
            return;
          }
          nav.push(MaterialPageRoute(
              builder: (_) => QuestDetailScreen(questId: route.id!)));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    _settingsService.removeListener(_onSettingsChanged);
    _goalService.removeListener(_onDataChanged);
    _questService.removeListener(_onDataChanged);
    _goalService.dispose();
    _questService.dispose();
    _progression.dispose();
    _settingsService.dispose();
    _supabaseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GoalService>.value(value: _goalService),
        ChangeNotifierProvider<QuestService>.value(value: _questService),
        ChangeNotifierProvider<ProgressionService>.value(value: _progression),
        ChangeNotifierProvider<SettingsService>.value(value: _settingsService),
        ChangeNotifierProvider<SupabaseService>.value(value: _supabaseService),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'TrackMe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            final supabase = context.watch<SupabaseService>();
            if (supabase.isLoggedIn) {
              if (supabase.needsOwnerChoice) return const ClaimDataScreen();
              if (!supabase.dataReady) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              // New accounts pick a unique username, name, bio and photo first.
              return supabase.profileComplete
                  ? const HomeScreen()
                  : const SetupProfileScreen();
            }
            return const AuthScreen();
          },
        ),
      ),
    );
  }
}

enum WidgetRouteKind { goal, quests, quest }

class WidgetRoute {
  final WidgetRouteKind kind;
  final String? id;
  const WidgetRoute(this.kind, [this.id]);
}

/// Maps a home-screen widget tap URI to an in-app destination.
/// - trackme://goal?id=<goalId>   -> goal detail
/// - trackme://quest?id=<questId> -> quest detail
/// - trackme://quests             -> quest list
/// Anything else (e.g. trackme://open) just opens the app.
WidgetRoute? widgetRouteFor(Uri? uri) {
  if (uri == null) return null;
  final id = uri.queryParameters['id'];
  switch (uri.host) {
    case 'goal':
      return (id == null || id.isEmpty) ? null : WidgetRoute(WidgetRouteKind.goal, id);
    case 'quest':
      return (id == null || id.isEmpty)
          ? const WidgetRoute(WidgetRouteKind.quests)
          : WidgetRoute(WidgetRouteKind.quest, id);
    case 'quests':
      return const WidgetRoute(WidgetRouteKind.quests);
  }
  return null;
}
