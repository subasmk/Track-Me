import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../models/public_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'public_profile_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<PublicProfile> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _performSearch('');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final service = context.read<SupabaseService>();
    final res = await service.searchProfiles(query);
    if (mounted) {
      setState(() {
        _searchResults = res;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community & Teams'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.purpleMid,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Find Profiles'),
            Tab(icon: Icon(Icons.people), text: 'Friends'),
            Tab(icon: Icon(Icons.local_fire_department), text: 'Team Streaks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildFriendsTab(),
          _buildTeamStreaksTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: _searchController,
            onChanged: _performSearch,
            decoration: InputDecoration(
              hintText: 'Search user by username...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
          ),
        ),
        if (_isSearching)
          const Center(child: CircularProgressIndicator())
        else if (_searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('No users found with that username.', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final p = _searchResults[index];
                return Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.purpleMid,
                      child: Text(p.username.isNotEmpty ? p.username[0].toUpperCase() : 'U'),
                    ),
                    title: Text(p.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Lvl ${p.level} • 🔥 ${p.currentStreak} day streak'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(profile: p),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    final supabase = context.watch<SupabaseService>();
    final friends = supabase.friendsList;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Friends (${friends.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Find More'),
              onPressed: () => _tabController.animateTo(0),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (friends.isEmpty)
          const Card(
            color: AppColors.surface,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'You have not added any friends yet. Search usernames in the Find Profiles tab to connect!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...friends.map((username) {
            return FutureBuilder<PublicProfile?>(
              future: supabase.getProfileByUsername(username),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final streak = profile?.currentStreak ?? 0;
                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.purpleMid,
                      child: Text(username[0].toUpperCase()),
                    ),
                    title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('🔥 $streak day streak'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, color: AppColors.purpleMid),
                          tooltip: 'View Profile',
                          onPressed: () {
                            if (profile != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: profile)),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          tooltip: 'Remove Friend',
                          onPressed: () => supabase.removeFriend(username),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
      ],
    );
  }

  Widget _buildTeamStreaksTab() {
    final supabase = context.watch<SupabaseService>();
    final teams = supabase.teamQuests;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Team Tasks & Streaks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purpleMid,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.group_add, size: 18),
              label: const Text('Create Team'),
              onPressed: () => _showCreateTeamDialog(context, supabase),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (teams.isEmpty)
          const Card(
            color: AppColors.surface,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'No active team tasks. Create a team quest with your friends to maintain team streaks together!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...teams.map((team) {
            final isDoneToday = team.completedTodayUsernames.contains(supabase.currentUsername);
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(team.emoji, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(team.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(team.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orangeAccent),
                          ),
                          child: Row(
                            children: [
                              const Text('🔥 ', style: TextStyle(fontSize: 14)),
                              Text('${team.teamStreak}d Team Streak', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('Members (${team.completedTodayUsernames.length}/${team.memberUsernames.length} completed today):', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: team.memberUsernames.map((m) {
                        final completed = team.completedTodayUsernames.contains(m);
                        return Chip(
                          avatar: Icon(completed ? Icons.check_circle : Icons.circle_outlined, size: 16, color: completed ? Colors.greenAccent : AppColors.textSecondary),
                          label: Text(m),
                          backgroundColor: completed ? Colors.green.withAlpha(30) : AppColors.surface,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDoneToday ? Colors.grey : AppColors.purpleMid,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(isDoneToday ? Icons.check : Icons.local_fire_department),
                        label: Text(isDoneToday ? 'Team Task Done Today!' : 'Complete Today\'s Team Task'),
                        onPressed: isDoneToday
                            ? null
                            : () {
                                supabase.completeTeamTaskToday(team.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Great job! Marked team task complete for today! 🔥')),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showCreateTeamDialog(BuildContext context, SupabaseService supabase) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🔥');
    final selectedFriends = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Team Quest'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Team Quest Title'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description / Goal'),
                ),
                TextField(
                  controller: emojiCtrl,
                  decoration: const InputDecoration(labelText: 'Emoji (e.g. 🔥, 🚀, 💪)'),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Invite Friends:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (supabase.friendsList.isEmpty)
                  const Text('No friends added yet. You can add team members later.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
                else
                  ...supabase.friendsList.map((f) => CheckboxListTile(
                        title: Text(f),
                        value: selectedFriends.contains(f),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedFriends.add(f);
                            } else {
                              selectedFriends.remove(f);
                            }
                          });
                        },
                      )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  supabase.createTeamQuest(
                    title: titleCtrl.text.trim(),
                    emoji: emojiCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    invitedFriends: selectedFriends.toList(),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create Team'),
            ),
          ],
        ),
      ),
    );
  }
}
