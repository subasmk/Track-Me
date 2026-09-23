import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/quest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/quest_ui.dart';
import '../../widgets/sloth_sticker.dart';

/// Pomodoro-style focus timer for a quest. Minutes spent are added to the
/// quest's focus total when the session ends or is stopped early.
class FocusTimerScreen extends StatefulWidget {
  final String questId;
  const FocusTimerScreen({super.key, required this.questId});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  static const _presets = [15, 25, 45];
  int _minutes = 25;
  int _remaining = 25 * 60;
  Timer? _timer;
  bool _finished = false;

  bool get _running => _timer != null;
  int get _elapsedMinutes => ((_minutes * 60 - _remaining) / 60).floor();

  void _start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _complete();
      } else {
        setState(() => _remaining--);
      }
    });
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _timer = null);
  }

  Future<void> _complete() async {
    _timer?.cancel();
    _timer = null;
    await context.read<QuestService>().logFocusMinutes(widget.questId, _minutes);
    if (mounted) setState(() {
      _remaining = 0;
      _finished = true;
    });
  }

  Future<void> _stopEarly() async {
    final minutes = _elapsedMinutes;
    _pause();
    if (minutes > 0) {
      await context.read<QuestService>().logFocusMinutes(widget.questId, minutes);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quest = context.watch<QuestService>().questById(widget.questId);
    final total = _minutes * 60;
    final progress = total == 0 ? 0.0 : 1 - _remaining / total;
    final mm = (_remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (_remaining % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(quest == null ? 'Focus' : '${quest.emoji} ${quest.title}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(children: [
            const Spacer(),
            SlothStickerView(
              sticker: _finished ? SlothSticker.cheering : SlothSticker.focused,
              size: 140,
            ),
            const SizedBox(height: AppSpacing.lg),
            ProgressRing(
              progress: progress,
              size: 220,
              stroke: 14,
              color: AppColors.purpleLight,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_finished ? 'Done!' : '$mm:$ss',
                    style: AppTextStyles.display.copyWith(fontSize: 48)),
                Text(_finished ? '+$_minutes focus min' : 'focus session',
                    style: AppTextStyles.bodyMuted),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_running && !_finished && _remaining == total)
              Wrap(spacing: 8, children: [
                for (final m in _presets)
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() {
                      _minutes = m;
                      _remaining = m * 60;
                    }),
                  ),
              ]),
            const Spacer(),
            if (_finished)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Back to quest'),
                ),
              )
            else
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _remaining == total ? () => Navigator.pop(context) : _stopEarly,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(_remaining == total ? 'Cancel' : 'Stop & log'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _running ? _pause : _start,
                    icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                    label: Text(_running ? 'Pause' : (_remaining == total ? 'Start' : 'Resume')),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.purpleMid,
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ]),
          ]),
        ),
      ),
    );
  }
}
