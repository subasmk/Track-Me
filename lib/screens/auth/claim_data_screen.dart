import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/goal_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/system_ui.dart';

/// One-time question on phones where an older build mixed two accounts'
/// data together: whose goals and quests are these?
class ClaimDataScreen extends StatefulWidget {
  const ClaimDataScreen({super.key});

  @override
  State<ClaimDataScreen> createState() => _ClaimDataScreenState();
}

class _ClaimDataScreenState extends State<ClaimDataScreen> {
  bool _busy = false;

  Future<void> _pick(bool keepHere) async {
    setState(() => _busy = true);
    await context.read<SupabaseService>().resolveMixedData(keepHere: keepHere);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<SupabaseService>().email ?? 'this account';
    final goals = context.watch<GoalService>().goals;
    final names = goals.take(3).map((g) => '${g.emoji} ${g.title}').join(', ');
    Widget button(String label, Color color, VoidCallback onTap) => OutlinedButton(
          onPressed: _busy ? null : onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.8)),
            backgroundColor: color.withValues(alpha: 0.06),
            shape: const RoundedRectangleBorder(),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
        );
    return Scaffold(
      backgroundColor: SysColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 40, 18, 24),
          children: [
            SysPanel(
              tag: 'ACCOUNTS',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Whose goals are these?', style: SysText.body.copyWith(fontSize: 20)),
                const SizedBox(height: 10),
                Text(
                  'The last version kept every account\'s goals and quests together on this phone. '
                  'This version keeps each account separate.',
                  style: SysText.body.copyWith(color: SysColors.muted, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text('Goals on this phone: ${goals.length}${names.isEmpty ? '' : '  ($names)'}',
                    style: SysText.body),
                const SizedBox(height: 4),
                Text('Signed in as $email', style: SysText.body.copyWith(color: SysColors.cyanSoft)),
                const SizedBox(height: 20),
                button('KEEP THEM ON THIS ACCOUNT', SysColors.cyan, () => _pick(true)),
                const SizedBox(height: 10),
                button('THEY\'RE MY OTHER ACCOUNT\'S', SysColors.gold, () => _pick(false)),
                const SizedBox(height: 12),
                Text(
                  'Nothing is deleted. If you pick the other account, they move to it the next time '
                  'you sign in there, and this account starts empty. Each account then sets up its '
                  'username and photo once more so they stop mixing.',
                  style: SysText.body.copyWith(color: SysColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
