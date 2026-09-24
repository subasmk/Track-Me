import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/public_profile.dart';
import '../../services/supabase_service.dart';
import 'public_profile_screen.dart';

const _bg = Color(0xFF000000);
const _field = Color(0xFF262626);
const _muted = Color(0xFFA8A8A8);
const _blue = Color(0xFF0095F6);
const _line = Color(0xFF262626);

/// Instagram-style Friends: search by username, requests, friends list and
/// suggested players, backed by the profiles + friendships tables.
class SearchFriendsScreen extends StatefulWidget {
  /// Skips network loading (screenshot tests).
  final bool load;
  final int initialTab;
  /// Screenshot tests only: suggestions to show without loading.
  final List<PublicProfile> previewSuggested;
  const SearchFriendsScreen(
      {super.key, this.load = true, this.initialTab = 0, this.previewSuggested = const []});

  @override
  State<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends State<SearchFriendsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  late int _tab = widget.initialTab;
  bool _loading = false;
  bool? _cloudOk;
  bool _searching = false;
  List<PublicProfile> _results = [];
  late List<PublicProfile> _suggested = [...widget.previewSuggested];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    if (widget.load) WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = context.read<SupabaseService>();
    setState(() => _loading = true);
    final ok = await s.loadFriendships();
    final sug = ok ? await s.suggestedPlayers() : <PublicProfile>[];
    if (!mounted) return;
    setState(() {
      _cloudOk = ok;
      _suggested = sug;
      _loading = false;
    });
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final r = await context.read<SupabaseService>().searchProfiles(q);
      if (!mounted || _search.text != q) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    });
  }

  Future<void> _run(String key, Future<bool> Function() action, String failText) async {
    setState(() => _busy.add(key));
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy.remove(key));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failText), behavior: SnackBarBehavior.floating));
    } else {
      _suggested.removeWhere((p) => context.read<SupabaseService>().friendshipWith(p.id) != null);
    }
  }

  void _open(PublicProfile p) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: p)));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SupabaseService>();
    final friends = s.friends;
    final incoming = s.incomingRequests;
    final outgoing = s.outgoingRequests;
    final query = _search.text.trim();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(s.currentUsername.toLowerCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
              onPressed: widget.load ? _refresh : null,
              icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                style: const TextStyle(color: Colors.white),
                autocorrect: false,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: _field,
                  hintText: 'Search by username',
                  hintStyle: const TextStyle(color: _muted),
                  prefixIcon: const Icon(Icons.search, color: _muted),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, color: _muted, size: 18),
                          onPressed: () {
                            _search.clear();
                            _onSearch('');
                          }),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_cloudOk == false) const _CloudBanner(),
            if (query.isNotEmpty) ...[
              if (_searching)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_results.isEmpty)
                _Empty(icon: Icons.person_search, title: 'No players found', body: 'No one matches "$query".')
              else
                for (final p in _results) _row(s, p),
            ] else ...[
              _Tabs(
                tab: _tab,
                labels: ['Friends ${friends.length}', 'Requests ${incoming.length}', 'Discover'],
                badge: incoming.isNotEmpty ? 1 : null,
                onTap: (i) => setState(() => _tab = i),
              ),
              if (_loading && s.friendships.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              if (_tab == 0) ...[
                if (friends.isEmpty && !_loading)
                  _Empty(
                      icon: Icons.group_outlined,
                      title: 'No friends yet',
                      body: 'Search a username or check Discover to add people.'),
                for (final f in friends) _row(s, f.other),
                if (_suggested.isNotEmpty) _suggestedStrip(s),
              ],
              if (_tab == 1) ...[
                if (incoming.isEmpty && outgoing.isEmpty && !_loading)
                  _Empty(
                      icon: Icons.mark_email_unread_outlined,
                      title: 'No requests',
                      body: 'Friend requests you get show up here.'),
                if (incoming.isNotEmpty) const _Header('Friend requests'),
                for (final f in incoming) _row(s, f.other),
                if (outgoing.isNotEmpty) const _Header('Sent'),
                for (final f in outgoing) _row(s, f.other),
              ],
              if (_tab == 2) ...[
                const _Header('Suggested for you'),
                if (_suggested.isEmpty && !_loading)
                  _Empty(
                      icon: Icons.explore_outlined,
                      title: 'No suggestions right now',
                      body: 'As more friends join TrackMe, they show up here.'),
                for (final p in _suggested) _row(s, p),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _suggestedStrip(SupabaseService s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header('Suggested for you'),
          SizedBox(
            height: 212,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggested.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = _suggested[i];
                return GestureDetector(
                  onTap: () => _open(p),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                    decoration: BoxDecoration(
                        border: Border.all(color: _line), borderRadius: BorderRadius.circular(8)),
                    child: Column(children: [
                      _Avatar(p, radius: 36),
                      const SizedBox(height: 10),
                      Text(p.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      Text('🔥 ${p.currentStreak} · LV ${p.level}',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                      const Spacer(),
                      SizedBox(width: double.infinity, child: _action(s, p)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      );

  Widget _row(SupabaseService s, PublicProfile p) => InkWell(
        onTap: () => _open(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _Avatar(p, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.username,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  [
                    if (p.fullName.isNotEmpty) p.fullName,
                    '🔥 ${p.currentStreak}',
                    'LV ${p.level}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            _action(s, p),
          ]),
        ),
      );

  Widget _action(SupabaseService s, PublicProfile p) {
    final f = s.friendshipWith(p.id);
    final busy = _busy.contains(p.id);
    if (busy) {
      return const SizedBox(
          height: 32, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (f == null) {
      return _Btn('Add', primary: true,
          onTap: () => _run(p.id, () => s.sendFriendRequest(p), "Couldn't send the request"));
    }
    if (f.accepted) {
      return _Btn('Friends', onTap: () async {
        final ok = await _confirmUnfriend(p);
        if (ok == true) _run(p.id, () => s.removeFriendship(f), "Couldn't remove the friend");
      });
    }
    if (f.incoming) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _Btn('Confirm', primary: true,
            onTap: () => _run(p.id, () => s.acceptFriendRequest(f), "Couldn't accept")),
        const SizedBox(width: 6),
        _Btn('Delete', onTap: () => _run(p.id, () => s.removeFriendship(f), "Couldn't decline")),
      ]);
    }
    return _Btn('Requested', onTap: () => _run(p.id, () => s.removeFriendship(f), "Couldn't cancel"));
  }

  Future<bool?> _confirmUnfriend(PublicProfile p) => showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF262626),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 16),
            _Avatar(p, radius: 32),
            const SizedBox(height: 10),
            Text('Remove @${p.username} from friends?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Remove', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFED4956))),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              title: const Text('Cancel', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ]),
        ),
      );
}

class _Avatar extends StatelessWidget {
  final PublicProfile p;
  final double radius;
  const _Avatar(this.p, {required this.radius});

  @override
  Widget build(BuildContext context) {
    final url = p.avatarUrl;
    final ring = p.currentStreak > 0;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring
            ? const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF)])
            : null,
        color: ring ? null : _line,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(color: _bg, shape: BoxShape.circle),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF363636),
          backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
          child: url != null && url.isNotEmpty
              ? null
              : Text(p.username.isEmpty ? '?' : p.username[0].toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: radius * 0.8, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String text;
  final bool primary;
  final VoidCallback onTap;
  const _Btn(this.text, {this.primary = false, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: primary ? _blue : const Color(0xFF363636),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      );
}

class _Tabs extends StatelessWidget {
  final int tab;
  final List<String> labels;
  final int? badge;
  final ValueChanged<int> onTap;
  const _Tabs({required this.tab, required this.labels, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: i == tab ? Colors.white : Colors.transparent, width: 1.5))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(labels[i],
                        style: TextStyle(
                            color: i == tab ? Colors.white : _muted, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (i == 1 && badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Color(0xFFFF3040), shape: BoxShape.circle)),
                    ],
                  ]),
                ),
              ),
            ),
        ]),
      );
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Empty({required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
        ]),
      );
}

class _CloudBanner extends StatelessWidget {
  const _CloudBanner();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(10)),
        child: const Row(children: [
          Icon(Icons.cloud_off, color: Color(0xFFFFC15E)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Friends need the cloud database. You're offline, not signed in, or supabase/schema.sql "
              "hasn't been run in Supabase yet.",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ]),
      );
}
