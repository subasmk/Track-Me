import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quest.dart';
import '../services/home_widget_service.dart';
import '../services/quest_service.dart';

/// Pins a quest widget and tells the user what really happened.
Future<void> pinQuestWidgetWithFeedback(BuildContext context, Quest? quest) async {
  final messenger = ScaffoldMessenger.of(context);
  // Make sure the widget has fresh data the moment it lands.
  await context.read<QuestService>().syncWidget();
  final result = await HomeWidgetService.pinQuestWidget(quest);
  final name = quest == null ? "Today's quests" : '"${quest.title}"';
  final message = switch (result) {
    PinWidgetResult.requested =>
      'Confirm on the next screen to add the $name widget.',
    PinWidgetResult.unsupported =>
      "Your launcher can't add widgets from inside the app. Long-press the home screen, "
          'tap Widgets, and drag "TrackMe Quests" out.',
    PinWidgetResult.failed => "Couldn't request the widget. Try adding it from the home screen.",
  };
  messenger.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
