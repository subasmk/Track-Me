import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';

import 'services/hive_service.dart';
import 'services/goal_service.dart';
import 'services/quest_service.dart';
import 'services/settings_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/goal_detail/goal_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();

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

class _TrackMeAppState extends State<TrackMeApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final GoalService _goalService;
  late final QuestService _questService;
  late final SettingsService _settingsService;
  late final SupabaseService _supabaseService;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    _goalService = GoalService();
    _questService = QuestService();
    _settingsService = SettingsService();
    _supabaseService = SupabaseService();

    // Initialize Supabase in background
    _supabaseService.initSupabase();

    // Keep the widget username copy in sync with SettingsService.
    _goalService.setUserName(_settingsService.userName);
    _supabaseService.updateUsername(_settingsService.userName);

    _settingsService.addListener(_onSettingsChanged);
    _goalService.addListener(_onDataChanged);
    _questService.addListener(_onDataChanged);

    // Tapping a goal's home-screen widget should open that goal directly.
    _handleInitialWidgetLaunch();
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  void _onSettingsChanged() {
    _goalService.setUserName(_settingsService.userName);
    _supabaseService.updateUsername(_settingsService.userName);
  }

  void _onDataChanged() {
    _supabaseService.syncLocalProfileToCloud(
      goals: _goalService.goals,
      quests: _questService.quests,
    );
  }

  Future<void> _handleInitialWidgetLaunch() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetUri(uri);
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;

    // Goal deep link: trackme://goal?id=<goalId>
    if (uri.host == 'goal') {
      final goalId = uri.queryParameters['id'];
      if (goalId == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final goal = _goalService.goalById(goalId);
        if (goal == null) return;
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goal.id)),
        );
      });
    }
    // Quest deep link could be added here in the future:
    // else if (uri.host == 'quest') { ... }
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    _settingsService.removeListener(_onSettingsChanged);
    _goalService.removeListener(_onDataChanged);
    _questService.removeListener(_onDataChanged);
    _goalService.dispose();
    _questService.dispose();
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
        home: const HomeScreen(),
      ),
    );
  }
}
