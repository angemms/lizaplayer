import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yandex_music/yandex_music.dart';
import 'package:lizaplayer/services/token_storage.dart';
import 'package:lizaplayer/services/player_service.dart';
import 'package:lizaplayer/screens/auth_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'dart:math';

import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/l10n/app_localizations.dart';

final blurEnabledProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerStatefulWidget {
  final String token;
  const HomeScreen({required this.token, super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late final YandexMusic _client;
  final PlayerService _playerService = PlayerService();
  late final TabController _tabController;

  List<Track> waveTracks = [];
  bool _loading = false;
  bool _isWaveActive = false;

  final TextEditingController _searchController = TextEditingController();

  StreamSubscription? _playerStateSubscription;

  List<Track> _likedTracks = [];
  bool _isLikesOpen = false;

  bool _isInitialized = false;

  String? _customBackgroundUrl;

  late AnimationController _pauseAnimationController;
  late Animation<double> _pauseAnimation;

  late AnimationController _prevAnimationController;
  late Animation<double> _prevAnimation;

  late AnimationController _nextAnimationController;
  late Animation<double> _nextAnimation;

  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  List<Track> _currentPlaylist = [];
  int _currentIndex = -1;
  List<Track> _queueTracks = [];

  bool _showMiniPlayer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_tabListener);
    _pauseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pauseAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _pauseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _prevAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _prevAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _prevAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _nextAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _nextAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _nextAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _initializeApp();
  }

  void _tabListener() {
    if (mounted) {
      setState(() {
        _showMiniPlayer = _tabController.index != 0;
      });
    }
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    try {
      _client = YandexMusic(token: widget.token);
      await _client.init();
      _playerService.setClient(_client);

      _playerStateSubscription = _playerService.player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _nextTrack();
        }
        if (mounted) {
          setState(() {});
        }
      });

      await _loadLikedTracks();

      _customBackgroundUrl = await TokenStorage.getCustomGifUrl();

      final blurEnabled = await TokenStorage.getBlurEnabled();
      ref.read(blurEnabledProvider.notifier).state = blurEnabled;

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      print('Initialization error: $e');
    }

    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < const Duration(seconds: 3)) {
      await Future.delayed(const Duration(seconds: 3) - elapsed);
    }

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _loadLikedTracks() async {
    final ids = await TokenStorage.getLikedTrackIds();
    if (ids.isEmpty) return;

    try {
      final loaded = await _client.tracks.getTracks(ids);
      setState(() {
        _likedTracks = loaded.whereType<Track>().toList();
      });
    } catch (e) {
      print('Error loading liked tracks: $e');
    }
  }

  Future<void> _toggleLike([Track? track]) async {
    final trackToToggle = track ?? _playerService.currentTrack;
    if (trackToToggle == null || trackToToggle.id == null) return;

    final id = trackToToggle.id!;
    final willBeLiked = !_likedTracks.any((t) => t.id == id);

    setState(() {
      if (willBeLiked) {
        _likedTracks.insert(0, trackToToggle);
      } else {
        _likedTracks.removeWhere((t) => t.id == id);
      }
    });

    final currentIds = _likedTracks.map((t) => t.id.toString()).toList();
    await TokenStorage.saveLikedTrackIds(currentIds);
  }

  Widget _buildTrackTile(Track track, int index, List<Track> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isPlaying = _playerService.currentTrack?.id == track.id;
    final durationText = _formatDuration(
      track.durationMs != null ? Duration(milliseconds: track.durationMs!) : null,
    );
    final loc = AppLocalizations.of(context)!;
    final isLiked = _likedTracks.any((t) => t.id == track.id);

    return Container(
      decoration: BoxDecoration(
        color: isPlaying ? effectiveAccent.withOpacity(isDark ? 0.13 : 0.08) : null,
        borderRadius: BorderRadius.circular(22),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _playFromList(list, index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: CachedNetworkImage(
                  imageUrl: _getCoverUrl(track.coverUri, size: '100x100'),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[900],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                    child: const Icon(Icons.music_note_rounded, color: Colors.grey, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title ?? loc.untitledTrack,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
                        color: isPlaying ? effectiveAccent : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artists?.map((a) => a.title).join(', ') ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _toggleLike(track),
                    icon: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? effectiveAccent : Colors.grey,
                      size: 26,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    durationText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({
    required bool glassEnabled,
    required bool isDark,
    required Widget child,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(28.0)),
    double? customOpacity,
    bool enableBlur = true,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    final effectiveTint = accent.opacity == 0 ? Colors.transparent : accent;

    final fillOpacity = customOpacity ?? (isDark ? 0.16 : 0.82);
    final color = glassEnabled
        ? effectiveTint.withOpacity(fillOpacity)
        : (isDark ? const Color(0xFF1C1C1E) : Colors.white);

    final border = glassEnabled
        ? Border.all(
            color: Colors.white.withOpacity(isDark ? 0.18 : 0.25),
            width: 1.5,
          )
        : null;

    final container = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(glassEnabled ? 0.22 : (isDark ? 0.3 : 0.08)),
            blurRadius: glassEnabled ? 35 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (glassEnabled && enableBlur) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: container,
        ),
      );
    }
    return container;
  }

  Widget _buildMyWaveStart(bool isDark, AppLocalizations loc, bool glassEnabled) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: effectiveAccent.withOpacity(0.09),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveAccent.withOpacity(0.65),
                        blurRadius: 140,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.waves_rounded,
                    size: 165,
                    color: effectiveAccent,
                  ),
                ),
                const SizedBox(height: 56),
                Text(
                  loc.myWave,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 340,
                  child: Text(
                    loc.personalRecommendations,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19.5,
                      height: 1.35,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(height: 72),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _startMyWave,
                  icon: _loading
                      ? const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 42),
                  label: Text(
                    _loading ? loc.loading : loc.startMyWave,
                    style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 26),
                    backgroundColor: effectiveAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                    elevation: 16,
                    shadowColor: effectiveAccent.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyWavePlaylist(bool isDark, AppLocalizations loc, bool glassEnabled) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: effectiveAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.waves_rounded, size: 46, color: effectiveAccent),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.myWave,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.8),
                        ),
                        Text(
                          '${waveTracks.length} ${loc.tracks} • ${loc.personalWave}',
                          style: TextStyle(fontSize: 16.5, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _startMyWave,
                    icon: Icon(Icons.refresh_rounded, color: effectiveAccent, size: 32),
                    tooltip: loc.newWave,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: waveTracks.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.6,
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                  indent: 92,
                  endIndent: 24,
                ),
                itemBuilder: (context, index) => _buildTrackTile(waveTracks[index], index, waveTracks),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyWaveTab(bool glassEnabled) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    if (_isWaveActive && waveTracks.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        child: _buildMyWavePlaylist(isDark, loc, glassEnabled),
      );
    }
    return _buildMyWaveStart(isDark, loc, glassEnabled);
  }

  Widget _buildLikesPlaylist(bool glassEnabled) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final loc = AppLocalizations.of(context)!;

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isLikesOpen = false;
                      });
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: effectiveAccent, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.favorite_rounded, size: 46, color: Colors.redAccent),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.myLikes,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.8),
                        ),
                        Text(
                          '${_likedTracks.length} ${loc.tracks}',
                          style: TextStyle(fontSize: 16.5, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _likedTracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 120,
                            color: Colors.redAccent.withOpacity(0.4),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            loc.noLikesYet,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 280,
                            child: Text(
                              loc.likeToFill,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17.5,
                                height: 1.4,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: _likedTracks.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.6,
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                        indent: 92,
                        endIndent: 24,
                      ),
                      itemBuilder: (context, index) => _buildTrackTile(_likedTracks[index], index, _likedTracks),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsTab(bool glassEnabled) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    if (_isLikesOpen) {
      return Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        child: _buildLikesPlaylist(glassEnabled),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.playlists,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.8),
          ),
          const SizedBox(height: 32),
          _buildPlaylistCard(
            title: loc.myLikes,
            subtitle: '${_likedTracks.length} ${loc.tracks}',
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            onTap: () {
              setState(() {
                _isLikesOpen = true;
              });
            },
            glassEnabled: glassEnabled,
            isDark: isDark,
          ),
          _buildPlaylistCard(
            title: loc.myPlaylists,
            subtitle: loc.syncComingSoon,
            icon: Icons.queue_music_rounded,
            iconColor: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary,
            onTap: () {},
            glassEnabled: glassEnabled,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool glassEnabled,
    required bool isDark,
  }) {
    final effectiveIconColor = iconColor.opacity == 0 ? Colors.grey : iconColor;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, size: 34, color: effectiveIconColor),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 15.5, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _searchTracks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<Track> tracks = [];
    try {
      tracks = await _client.search.tracks(query);
    } catch (e) {
      Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return;
    }

    Navigator.of(context).pop();

    if (mounted) {
      if (tracks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No results found')));
      } else {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Consumer(
            builder: (context, ref, child) {
              final glassEnabled = ref.watch(glassEnabledProvider);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.8,
                minChildSize: 0.3,
                maxChildSize: 0.95,
                builder: (context, scrollController) => _buildGlassContainer(
                  glassEnabled: glassEnabled,
                  isDark: isDark,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text(
                          loc.searchResultsFor(query),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          itemCount: tracks.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 0.6,
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                            indent: 92,
                            endIndent: 24,
                          ),
                          itemBuilder: (context, index) => _buildTrackTile(tracks[index], index, tracks),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    }
  }

  Future<void> _startMyWave() async {
    setState(() {
      _loading = true;
      waveTracks = [];
      _isWaveActive = true;
    });

    try {
      final waves = await _client.myVibe.getWaves();
      final wave = await _client.myVibe.createWave(waves);

      setState(() => waveTracks = wave.tracks ?? []);

      if (waveTracks.length < 30 && waveTracks.isNotEmpty) {
        try {
          final randomIndex = Random().nextInt(waveTracks.length);
          final similar = await _client.tracks.getSimilar(waveTracks[randomIndex].id);
          setState(() => waveTracks = [...waveTracks, ...similar]);
        } catch (_) {}
      }

      waveTracks.shuffle();

      if (waveTracks.isNotEmpty) _playFromList(waveTracks, 0);
    } catch (e) {
      final fallback = await _client.search.tracks('my day');
      setState(() => waveTracks = fallback);

      if (waveTracks.length < 30 && waveTracks.isNotEmpty) {
        try {
          final randomIndex = Random().nextInt(waveTracks.length);
          final similar = await _client.tracks.getSimilar(waveTracks[randomIndex].id);
          setState(() => waveTracks = [...waveTracks, ...similar]);
        } catch (_) {}
      }

      waveTracks.shuffle();

      if (waveTracks.isNotEmpty) _playFromList(waveTracks, 0);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _playFromList(List<Track> list, int index) {
    if (index < 0 || index >= list.length) return;

    setState(() {
      _currentPlaylist = list;
      _currentIndex = index;
      _queueTracks = _currentPlaylist.skip(_currentIndex + 1).toList();
    });

    _playCurrentTrack();
  }

  void _playCurrentTrack() {
    if (_currentIndex >= 0 && _currentIndex < _currentPlaylist.length) {
      final track = _currentPlaylist[_currentIndex];
      _playerService.playFromPlaylist([track], 0);
      setState(() {
        _queueTracks = _currentPlaylist.skip(_currentIndex + 1).toList();
      });
    }
  }

  void _nextTrack() {
    if (_currentIndex < _currentPlaylist.length - 1) {
      _currentIndex++;
      _playCurrentTrack();
    }
  }

  void _prevTrack() {
    if (_playerService.player.position > const Duration(seconds: 3)) {
      _playerService.player.seek(Duration.zero);
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
        _playCurrentTrack();
      }
    }
  }

  void _playAtPlaylistIndex(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= _currentPlaylist.length) return;
    _currentIndex = globalIndex;
    _playCurrentTrack();
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '0:00';
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _getCoverUrl(String? coverUri, {String size = '400x400'}) {
    if (coverUri == null || coverUri.isEmpty) return '';
    return 'https://${coverUri.replaceAll('%%', size)}';
  }

  Future<void> _clearCache() async {
    final dir = await getTemporaryDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> _logout() async {
    await TokenStorage.deleteToken();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  void _showThemePicker() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final mode = ref.watch(themeModeProvider);
          final loc = AppLocalizations.of(context)!;
          final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
          return Dialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.theme, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _themeOption(ref, ThemeMode.light, loc.light, mode, effectiveAccent),
                  _themeOption(ref, ThemeMode.dark, loc.dark, mode, effectiveAccent),
                  _themeOption(ref, ThemeMode.system, loc.system, mode, effectiveAccent),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _themeOption(WidgetRef ref, ThemeMode mode, String title, ThemeMode current, Color effectiveAccent) {
    final selected = current == mode;
    return ListTile(
      title: Text(title),
      trailing: selected ? Icon(Icons.check_circle, color: effectiveAccent) : null,
      onTap: () async {
        ref.read(themeModeProvider.notifier).state = mode;
        await TokenStorage.saveThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showColorPicker() {
    final colors = [
      Colors.cyanAccent, Colors.redAccent, Colors.orangeAccent, Colors.purpleAccent,
      Colors.greenAccent, Colors.blueAccent, Colors.pinkAccent, Colors.indigoAccent,
      Colors.amberAccent, Colors.tealAccent, Colors.grey, Colors.transparent,
    ];

    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          return Dialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.mainColor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: colors.map((color) {
                      final isSelected = ref.watch(accentColorProvider) == color;
                      final isTransparent = color == Colors.transparent;
                      return GestureDetector(
                        onTap: () async {
                          ref.read(accentColorProvider.notifier).state = color;
                          await TokenStorage.saveAccentColor(color.value);
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 4,
                            ),
                          ),
                          child: isTransparent
                              ? Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: Center(
                                    child: Text(
                                      loc.noColor,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLanguagePicker() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final currentLocale = ref.watch(localeProvider);
          final loc = AppLocalizations.of(context)!;
          final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
          return Dialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.language, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ListTile(
                    title: Text(loc.english),
                    trailing: currentLocale.languageCode == 'en' ? Icon(Icons.check_circle, color: effectiveAccent) : null,
                    onTap: () {
                      ref.read(localeProvider.notifier).state = const Locale('en');
                      TokenStorage.saveLanguage('en');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: Text(loc.russian),
                    trailing: currentLocale.languageCode == 'ru' ? Icon(Icons.check_circle, color: effectiveAccent) : null,
                    onTap: () {
                      ref.read(localeProvider.notifier).state = const Locale('ru');
                      TokenStorage.saveLanguage('ru');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCustomBackgroundDialog() {
    final controller = TextEditingController(text: _customBackgroundUrl);
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.customBackground,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                loc.directLinkToGifOrImage,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: loc.urlExample,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.grey.withOpacity(0.1),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.cancel),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final url = controller.text.trim();
                        final newUrl = url.isEmpty ? null : url;

                        await TokenStorage.saveCustomGifUrl(newUrl);
                        setState(() => _customBackgroundUrl = newUrl);

                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(
                        loc.save,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (_customBackgroundUrl != null && _customBackgroundUrl!.isNotEmpty)
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          await TokenStorage.saveCustomGifUrl(null);
                          setState(() => _customBackgroundUrl = null);
                          if (mounted) Navigator.pop(context);
                        },
                        child: Text(loc.clear, style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainPlayerArea(Track? current, bool glassEnabled) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isLiked = current != null && _likedTracks.any((t) => t.id == current.id);

    return Center(
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current != null)
              _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Center(
                          child: Container(
                            key: ValueKey(current.id ?? 'empty'),
                            width: 420,
                            height: 420,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: CachedNetworkImage(
                                imageUrl: _getCoverUrl(current.coverUri, size: '400x400'),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 140, color: Colors.white24),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(current.title ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(current.artists?.map((a) => a.title).join(', ') ?? '', style: const TextStyle(fontSize: 17, color: Colors.grey), textAlign: TextAlign.center),

                      const SizedBox(height: 30),

                      StreamBuilder<Duration>(
                        stream: _playerService.player.positionStream,
                        builder: (context, snapshot) {
                          final pos = snapshot.data ?? Duration.zero;
                          final dur = _playerService.duration ?? Duration.zero;

                          return Column(
                            children: [
                              Slider(
                                value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                                max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1,
                                activeColor: effectiveAccent,
                                onChanged: (v) => _playerService.player.seek(Duration(milliseconds: v.toInt())),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(pos),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[400],
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(dur),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[400],
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 50),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: GestureDetector(
                                    onTapDown: (_) => _prevAnimationController.forward(),
                                    onTapUp: (_) => _prevAnimationController.reverse(),
                                    onTapCancel: () => _prevAnimationController.reverse(),
                                    onTap: _prevTrack,
                                    child: Center(
                                      child: ScaleTransition(
                                        scale: _prevAnimation,
                                        child: const Icon(Icons.skip_previous, size: 36),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: GestureDetector(
                                    onTapDown: (_) => _pauseAnimationController.forward(),
                                    onTapUp: (_) => _pauseAnimationController.reverse(),
                                    onTapCancel: () => _pauseAnimationController.reverse(),
                                    onTap: () => _playerService.player.playing
                                        ? _playerService.player.pause()
                                        : _playerService.player.play(),
                                    child: Center(
                                      child: ScaleTransition(
                                        scale: _pauseAnimation,
                                        child: StreamBuilder<PlayerState>(
                                          stream: _playerService.player.playerStateStream,
                                          builder: (_, snap) => Icon(
                                            (snap.data?.playing ?? false) ? Icons.pause : Icons.play_arrow,
                                            size: 54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: GestureDetector(
                                    onTapDown: (_) => _nextAnimationController.forward(),
                                    onTapUp: (_) => _nextAnimationController.reverse(),
                                    onTapCancel: () => _nextAnimationController.reverse(),
                                    onTap: _nextTrack,
                                    child: Center(
                                      child: ScaleTransition(
                                        scale: _nextAnimation,
                                        child: const Icon(Icons.skip_next, size: 36),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: GestureDetector(
                              onTapDown: (_) => _likeAnimationController.forward(),
                              onTapUp: (_) => _likeAnimationController.reverse(),
                              onTapCancel: () => _likeAnimationController.reverse(),
                              onTap: _toggleLike,
                              child: Center(
                                child: ScaleTransition(
                                  scale: _likeAnimation,
                                  child: Icon(
                                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isLiked ? effectiveAccent : null,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.volume_down),
                          Expanded(
                            child: StreamBuilder<double>(
                              stream: _playerService.player.volumeStream,
                              builder: (_, snap) => Slider(
                                value: snap.data ?? _playerService.volume,
                                activeColor: effectiveAccent,
                                onChanged: (v) => _playerService.setVolume(v),
                              ),
                            ),
                          ),
                          const Icon(Icons.volume_up),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: const Icon(Icons.music_note, size: 140, color: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuePanel(bool glassEnabled) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final loc = AppLocalizations.of(context)!;

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      loc.queue,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.8),
                    ),
                    Text(
                      '${_queueTracks.length} ${loc.tracks}',
                      style: TextStyle(fontSize: 16.5, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _queueTracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40),
                          Text(
                            loc.queueEmpty,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: _queueTracks.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.6,
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                        indent: 92,
                        endIndent: 24,
                      ),
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () => _playAtPlaylistIndex(_currentIndex + 1 + index),
                          child: _buildTrackTile(_queueTracks[index], index, _queueTracks),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(Track current, bool glassEnabled) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isLiked = _likedTracks.any((t) => t.id == current.id);

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: _getCoverUrl(current.coverUri, size: '80x80'),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 30, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    current.artists?.map((a) => a.title).join(', ') ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<Duration>(
                    stream: _playerService.player.positionStream,
                    builder: (context, snapshot) {
                      final pos = snapshot.data?.inMilliseconds ?? 0;
                      final dur = _playerService.duration?.inMilliseconds ?? 1;
                      return LinearProgressIndicator(
                        value: pos / dur,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation(effectiveAccent),
                        minHeight: 3,
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: GestureDetector(
                onTapDown: (_) => _prevAnimationController.forward(),
                onTapUp: (_) => _prevAnimationController.reverse(),
                onTapCancel: () => _prevAnimationController.reverse(),
                onTap: _prevTrack,
                child: Center(
                  child: ScaleTransition(
                    scale: _prevAnimation,
                    child: const Icon(Icons.skip_previous, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: GestureDetector(
                onTapDown: (_) => _pauseAnimationController.forward(),
                onTapUp: (_) => _pauseAnimationController.reverse(),
                onTapCancel: () => _pauseAnimationController.reverse(),
                onTap: () => _playerService.player.playing ? _playerService.player.pause() : _playerService.player.play(),
                child: Center(
                  child: ScaleTransition(
                    scale: _pauseAnimation,
                    child: StreamBuilder<PlayerState>(
                      stream: _playerService.player.playerStateStream,
                      builder: (_, snap) => Icon(
                        (snap.data?.playing ?? false) ? Icons.pause : Icons.play_arrow,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: GestureDetector(
                onTapDown: (_) => _nextAnimationController.forward(),
                onTapUp: (_) => _nextAnimationController.reverse(),
                onTapCancel: () => _nextAnimationController.reverse(),
                onTap: _nextTrack,
                child: Center(
                  child: ScaleTransition(
                    scale: _nextAnimation,
                    child: const Icon(Icons.skip_next, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: GestureDetector(
                onTapDown: (_) => _likeAnimationController.forward(),
                onTapUp: (_) => _likeAnimationController.reverse(),
                onTapCancel: () => _likeAnimationController.reverse(),
                onTap: _toggleLike,
                child: Center(
                  child: ScaleTransition(
                    scale: _likeAnimation,
                    child: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? effectiveAccent : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard({
    required String title,
    required List<Widget> children,
    required bool glassEnabled,
    required bool isDark,
  }) {
    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      leading: Icon(icon, color: effectiveAccent),
      title: Text(title, style: TextStyle(fontSize: 17, color: titleColor, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 13.5)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onTap: onTap,
    );
  }

  Widget _buildLoadingAnimation(AppLocalizations loc) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: effectiveAccent),
          const SizedBox(height: 20),
          Text(
            '${loc.loading}...',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AppLocalizations loc, bool isDark) {
    final current = _playerService.currentTrack;
    final hasCustomBg = _customBackgroundUrl != null && _customBackgroundUrl!.isNotEmpty;

    return Consumer(
      builder: (context, ref, child) {
        final glassEnabled = ref.watch(glassEnabledProvider);
        final blurEnabled = ref.watch(blurEnabledProvider);
        final primary = Theme.of(context).colorScheme.primary;
        final effectiveTint = primary.opacity == 0 ? Colors.transparent : primary;
        final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;

        final backgroundColor = hasCustomBg
            ? Colors.transparent
            : (glassEnabled
                ? Color.alphaBlend(
                    effectiveTint.withOpacity(isDark ? 0.06 : 0.04),
                    isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
                  )
                : (isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA)));

        Widget mainContent = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 35, 20, 10),
              child: _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: TabBar(
                    controller: _tabController,
                    dividerHeight: 0,
                    indicatorPadding: EdgeInsets.zero,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: primary.opacity == 0 ? Colors.grey : primary,
                      borderRadius: BorderRadius.circular(46),
                    ),
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                    labelColor: isDark ? Colors.black : Colors.white,
                    unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    tabs: [
                      Tab(text: loc.home),
                      Tab(text: loc.myWave),
                      Tab(text: loc.playlists),
                      Tab(text: loc.settings),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildMainPlayerArea(current, glassEnabled),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: SizedBox(
                                width: 400,
                                child: _buildQueuePanel(glassEnabled),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        child: _buildGlassContainer(
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                          borderRadius: BorderRadius.circular(30),
                          child: Row(
                            children: [
                              const SizedBox(width: 18),
                              Icon(Icons.search_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 24),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 16.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: loc.searchTracks,
                                    hintStyle: TextStyle(
                                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                                      fontSize: 16.5,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
                                  ),
                                  onSubmitted: (_) => _searchTracks(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ElevatedButton(
                                  onPressed: _searchTracks,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: effectiveAccent,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
                                  ),
                                  child: Text(
                                    loc.find,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  _buildMyWaveTab(glassEnabled),

                  _buildPlaylistsTab(glassEnabled),

                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.settings, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),

                        const SizedBox(height: 32),

                        _settingsCard(
                          title: loc.appearance,
                          children: [
                            _settingsTile(
                              icon: Icons.dark_mode_rounded,
                              title: loc.theme,
                              trailing: Consumer(
                                builder: (context, ref, child) {
                                  final mode = ref.watch(themeModeProvider);
                                  String text = mode == ThemeMode.light ? loc.light : mode == ThemeMode.dark ? loc.dark : loc.system;
                                  final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                                  return Text(text, style: TextStyle(fontSize: 17, color: effectiveAccent, fontWeight: FontWeight.w500));
                                },
                              ),
                              onTap: _showThemePicker,
                            ),
                            _settingsTile(
                              icon: Icons.palette_rounded,
                              title: loc.mainColor,
                              trailing: Consumer(
                                builder: (context, ref, child) {
                                  final color = ref.watch(accentColorProvider);
                                  if (color == Colors.transparent) {
                                    return Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Center(
                                        child: Text('N', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ),
                                    );
                                  }
                                  return Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  );
                                },
                              ),
                              onTap: _showColorPicker,
                            ),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              leading: Icon(Icons.blur_on_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary),
                              title: Text(
                                loc.glassInterface,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                              ),
                              trailing: Consumer(
                                builder: (context, ref, child) {
                                  final enabled = ref.watch(glassEnabledProvider);
                                  final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                                  return Switch(
                                    value: enabled,
                                    onChanged: (val) async {
                                      ref.read(glassEnabledProvider.notifier).state = val;
                                      await TokenStorage.saveGlassEnabled(val);
                                    },
                                    activeColor: effectiveAccent,
                                  );
                                },
                              ),
                            ),
                            _settingsTile(
                              icon: Icons.wallpaper_rounded,
                              title: loc.customBackground,
                              subtitle: hasCustomBg ? loc.installed : loc.notInstalled,
                              onTap: _showCustomBackgroundDialog,
                            ),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              leading: Icon(Icons.blur_linear_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary),
                              title: Text(
                                loc.backgroundBlur,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                              ),
                              trailing: Consumer(
                                builder: (context, ref, child) {
                                  final enabled = ref.watch(blurEnabledProvider);
                                  final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                                  return Switch(
                                    value: enabled,
                                    onChanged: (val) async {
                                      ref.read(blurEnabledProvider.notifier).state = val;
                                      await TokenStorage.saveBlurEnabled(val);
                                    },
                                    activeColor: effectiveAccent,
                                  );
                                },
                              ),
                            ),
                          ],
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 8),

                        _settingsCard(
                          title: loc.languageSection,
                          children: [
                            _settingsTile(
                              icon: Icons.language_rounded,
                              title: loc.language,
                              trailing: Consumer(
                                builder: (context, ref, child) {
                                  final locale = ref.watch(localeProvider);
                                  final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                                  return Text(
                                    locale.languageCode == 'ru' ? loc.russian : loc.english,
                                    style: TextStyle(fontSize: 17, color: effectiveAccent, fontWeight: FontWeight.w500),
                                  );
                                },
                              ),
                              onTap: _showLanguagePicker,
                            ),
                          ],
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 8),

                        _settingsCard(
                          title: loc.dataAndAccount,
                          children: [
                            _settingsTile(
                              icon: Icons.delete_outline_rounded,
                              title: loc.clearCache,
                              subtitle: loc.clearCacheSubtitle,
                              onTap: _clearCache,
                            ),
                            _settingsTile(
                              icon: Icons.logout_rounded,
                              title: loc.logout,
                              subtitle: loc.logoutSubtitle,
                              titleColor: Colors.red,
                              onTap: _logout,
                            ),
                          ],
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 60),

                        Center(
                          child: Column(
                            children: [
                              Text(
                                'lizaplayer',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.8,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'v2.0.0',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_showMiniPlayer && current != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: _buildMiniPlayer(current, glassEnabled),
              ),
          ],
        );

        return hasCustomBg
            ? Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      _customBackgroundUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
                      ),
                    ),
                  ),
                  if (blurEnabled)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: const SizedBox(),
                      ),
                    ),
                  mainContent,
                ],
              )
            : mainContent;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _isInitialized
            ? _buildMainContent(loc, isDark)
            : _buildLoadingAnimation(loc),
      ),
    );
  }

  @override
  void dispose() {
    _pauseAnimationController.dispose();
    _prevAnimationController.dispose();
    _nextAnimationController.dispose();
    _likeAnimationController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _playerStateSubscription?.cancel();
    super.dispose();
  }
}
