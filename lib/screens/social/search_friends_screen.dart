import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../models/public_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import 'public_profile_screen.dart';

class SearchFriendsScreen extends StatefulWidget {
  const SearchFriendsScreen({super.key});

  @override
  State<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends State<SearchFriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<PublicProfile> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Search & Friends'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.purpleLight,
          labelColor: AppColors.purpleLight,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.person_add_alt_1_rounded), text: 'Add Friends'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'My Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddFriendsTab(),
          _buildMyFriendsTab(),
        ],
      ),
    );
  }

  Widget _buildAddFriendsTab() {
    final supabase = context.watch<SupabaseService>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: _searchController,
            onChanged: _performSearch,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Search player by specific username...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: AppColors.purpleMid),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          )
        else if (_searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'No player found with that username.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final p = _searchResults[index];
                final isFriend = supabase.friendsList.contains(p.username);
                final isSelf = supabase.currentUsername.toLowerCase() ==
                    p.username.toLowerCase();

                return Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.purpleMid,
                      child: Text(
                        p.username.isNotEmpty
                            ? p.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(p.username,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Level ${p.level} • 🔥 ${p.currentStreak}d streak'),
                    trailing: isSelf
                        ? const Chip(label: Text('You'))
                        : IconButton(
                            icon: Icon(
                              isFriend
                                  ? Icons.person_remove_rounded
                                  : Icons.person_add_alt_1_rounded,
                              color: isFriend ? Colors.redAccent : AppColors.purpleLight,
                            ),
                            tooltip: isFriend ? 'Remove Friend' : 'Add Friend',
                            onPressed: () {
                              if (isFriend) {
                                supabase.removeFriend(p.username);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Removed ${p.username} from friends.')),
                                );
                              } else {
                                supabase.addFriend(p.username);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Added ${p.username} as friend! 🎉')),
                                );
                              }
                            },
                          ),
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

  Widget _buildMyFriendsTab() {
    final supabase = context.watch<SupabaseService>();
    final friends = supabase.friendsList;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Friends (${friends.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: const Text('Add Friends'),
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
                'You have not added any friends yet.\nUse the Add Friends tab to search players by username!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
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
                final level = profile?.level ?? 1;

                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.purpleMid,
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : 'U',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(username,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Level $level • 🔥 $streak day streak'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined,
                              color: AppColors.purpleLight),
                          tooltip: 'View Profile',
                          onPressed: () {
                            if (profile != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PublicProfileScreen(profile: profile)),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.redAccent),
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
}
