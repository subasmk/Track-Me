import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_service.dart';
import '../../models/public_profile.dart';
import 'public_profile_screen.dart';

class SearchFriendsScreen extends StatefulWidget {
  const SearchFriendsScreen({super.key});

  @override
  State<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends State<SearchFriendsScreen> {
  int selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  List<PublicProfile> _searchResults = [];
  bool _isSearching = false;

  static const Color bgDark = Color(0xFF070D18);
  static const Color cardBg = Color(0xFF101B2E);
  static const Color borderColor = Color(0xFF1E3154);
  static const Color cyan = Color(0xFF38B6FF);
  static const Color muted = Color(0xFF8B9CB3);
  static const Color orange = Color(0xFFFF6A00);
  static const Color gold = Color(0xFFFFB703);

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
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
    final supabase = context.watch<SupabaseService>();
    final friendsList = supabase.friendsList;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Friends',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
            Text(
              'Better together. Grow together.',
              style: TextStyle(
                color: Color(0xFF8DB8E8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => selectedTab = 1);
            },
            icon: const Icon(
              Icons.group_add_outlined,
              color: cyan,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            // SEARCH BAR
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: cyan.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cyan.withValues(alpha: 0.08),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _performSearch,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.search,
                    color: cyan,
                    size: 23,
                  ),
                  hintText: 'Search friends or username...',
                  hintStyle: TextStyle(
                    color: muted,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // TABS
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  _buildTab('Friends', Icons.people_alt_outlined, 0),
                  _buildTab('Discover', Icons.explore_outlined, 1),
                  _buildTab('Requests', Icons.notifications_none, 2),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FRIENDS TAB (Tab 0)
            if (selectedTab == 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'YOUR FRIENDS',
                    style: TextStyle(
                      color: Color(0xFF9B8CFF),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${friendsList.length} Friends',
                    style: const TextStyle(
                      color: cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),

              if (friendsList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Center(
                    child: Text(
                      'No friends added yet. Use the Discover tab to find players by username!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ),
                )
              else
                ...friendsList.map((username) => FutureBuilder<PublicProfile?>(
                      future: supabase.getProfileByUsername(username),
                      builder: (context, snapshot) {
                        final p = snapshot.data;
                        return _buildFriendCard(
                          username: username,
                          profile: p,
                          supabase: supabase,
                        );
                      },
                    )),

              const SizedBox(height: 16),
              _buildCommunityQuest(),
            ],

            // DISCOVER TAB (Tab 1)
            if (selectedTab == 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DISCOVER PLAYERS',
                    style: TextStyle(
                      color: Color(0xFF9B8CFF),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${_searchResults.length} Players',
                    style: const TextStyle(
                      color: cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),

              if (_isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: cyan),
                  ),
                )
              else if (_searchResults.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Center(
                    child: Text(
                      'No players found matching that username.',
                      style: TextStyle(color: muted),
                    ),
                  ),
                )
              else
                ..._searchResults.map(
                  (player) => _buildDiscoverCard(player, supabase),
                ),
            ],

            // REQUESTS TAB (Tab 2)
            if (selectedTab == 2) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FRIEND REQUESTS',
                    style: TextStyle(
                      color: Color(0xFF9B8CFF),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '0 Pending',
                    style: TextStyle(
                      color: cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: const Center(
                  child: Text(
                    'No pending friend requests.',
                    style: TextStyle(color: muted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, IconData icon, int index) {
    final bool selected = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? cyan.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: selected ? Border.all(color: cyan.withValues(alpha: 0.55)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? cyan : muted,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: selected ? cyan : muted,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendCard({
    required String username,
    required PublicProfile? profile,
    required SupabaseService supabase,
  }) {
    const Color accent = cyan;
    final streak = profile?.currentStreak ?? 0;
    final level = profile?.level ?? 1;
    final xp = profile?.xp ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.035),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF1B2A42),
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: cardBg, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '@${username.toLowerCase().replaceAll(' ', '')}',
                  style: const TextStyle(
                    color: Color(0xFF6C7D93),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: orange,
                      size: 15,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${streak}d',
                      style: const TextStyle(
                        color: Color(0xFFFF9A52),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'streak',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      height: 16,
                      width: 1,
                      color: borderColor,
                    ),
                    const SizedBox(width: 9),
                    const Icon(
                      Icons.star_rounded,
                      color: accent,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Lv.$level',
                      style: const TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      height: 16,
                      width: 1,
                      color: borderColor,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '$xp XP',
                      style: const TextStyle(
                        color: Color(0xFF9AB9E8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              if (profile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicProfileScreen(profile: profile),
                  ),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: cyan,
              side: BorderSide(color: cyan.withValues(alpha: 0.7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline, size: 16),
                SizedBox(width: 4),
                Text(
                  'Profile',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverCard(PublicProfile player, SupabaseService supabase) {
    final isFriend = supabase.friendsList.contains(player.username);
    final isSelf = supabase.currentUsername.toLowerCase() == player.username.toLowerCase();
    const Color accent = cyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: accent.withValues(alpha: 0.12),
            child: Text(
              player.username.isNotEmpty ? player.username[0].toUpperCase() : 'U',
              style: const TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@${player.username.toLowerCase().replaceAll(' ', '')}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  isFriend ? 'Already friends' : 'Tap + to become friends',
                  style: const TextStyle(color: Color(0xFF657994), fontSize: 10),
                ),
              ],
            ),
          ),
          if (isSelf)
            const Chip(label: Text('You'))
          else
            OutlinedButton.icon(
              onPressed: () {
                if (isFriend) {
                  supabase.removeFriend(player.username);
                } else {
                  supabase.addFriend(player.username);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${player.username} as friend! 🎉')),
                  );
                }
              },
              icon: Icon(
                isFriend ? Icons.person_remove : Icons.person_add_alt_1,
                size: 16,
              ),
              label: Text(
                isFriend ? 'Remove' : 'Add',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isFriend ? Colors.redAccent : cyan,
                side: BorderSide(
                  color: (isFriend ? Colors.redAccent : cyan).withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityQuest() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.07),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.workspace_premium, color: gold, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared Quest: Community Streak',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Work together with your friends',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: muted, size: 15),
            ],
          ),
          const SizedBox(height: 17),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '25 / 30 completed',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                '83%',
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 0.83,
              minHeight: 7,
              backgroundColor: Color(0xFF0A111E),
              valueColor: AlwaysStoppedAnimation<Color>(gold),
            ),
          ),
        ],
      ),
    );
  }
}
