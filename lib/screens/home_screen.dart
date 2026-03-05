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

import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  const HomeScreen({required this.token, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final YandexMusic _client;
  late final PlayerService _playerService;
  late final TabController _tabController;

  List<Track> _tracks = [];
  bool _loading = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();

  int _currentIndex = 0;

  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _client = YandexMusic(token: widget.token);
    _client.init();
    _playerService = PlayerService();
    _tabController = TabController(length: 3, vsync: this);

    _playerStateSubscription = _playerService.player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });
  }

  Future<void> _searchTracks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      final tracks = await _client.search.tracks(query);
      setState(() => _tracks = tracks);
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startMyWave() async {
    setState(() { _loading = true; _error = null; _tracks = []; });

    try {
      final waves = await _client.myVibe.getWaves();
      final wave = await _client.myVibe.createWave(waves);

      setState(() => _tracks = wave.tracks ?? []);

      if (_tracks.length < 30 && _tracks.isNotEmpty) {
        try {
          final similar = await _client.tracks.getSimilar(_tracks.first.id);
          _tracks.addAll(similar);
        } catch (_) {}
      }

      if (_tracks.isNotEmpty) await _playTrack(0);
    } catch (e) {
      final fallback = await _client.search.tracks('мой день');
      setState(() => _tracks = fallback);
      if (_tracks.isNotEmpty) await _playTrack(0);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;

    _currentIndex = index;
    setState(() {});

    try {
      await _playerService.playTrack(_tracks[index], _client);
    } catch (e) {
      print('Ошибка воспроизведения: $e');
    }
  }

  void _playNext() {
    if (_currentIndex + 1 < _tracks.length) {
      _playTrack(_currentIndex + 1);
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      if (_playerService.player.position.inSeconds > 3) {
        _playerService.player.seek(Duration.zero);
      } else {
        _playTrack(_currentIndex - 1);
      }
    } else {
      _playerService.player.seek(Duration.zero);
    }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.clearCache)),
      );
    }
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
                  _themeOption(ref, ThemeMode.light, loc.light, mode),
                  _themeOption(ref, ThemeMode.dark, loc.dark, mode),
                  _themeOption(ref, ThemeMode.system, loc.system, mode),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _themeOption(WidgetRef ref, ThemeMode mode, String title, ThemeMode current) {
    final selected = current == mode;
    return ListTile(
      title: Text(title),
      trailing: selected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
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
      Colors.amberAccent, Colors.tealAccent, Colors.grey,
    ];

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
                  Text(AppLocalizations.of(context)!.mainColor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: colors.map((color) {
                      final isSelected = ref.watch(accentColorProvider) == color;
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
                            color: color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 4,
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
                    title: const Text('English'),
                    trailing: currentLocale.languageCode == 'en' ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                    onTap: () {
                      ref.read(localeProvider.notifier).state = const Locale('en');
                      TokenStorage.saveLanguage('en');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Русский'),
                    trailing: currentLocale.languageCode == 'ru' ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
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

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _tabController.dispose();
    _playerService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _playerService.currentTrack;
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 35, 20, 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: TabBar(
                controller: _tabController,
                dividerHeight: 0,
                indicatorPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(26),
                ),
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                labelColor: isDark ? Colors.black : Colors.white,
                unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                tabs: [
                  Tab(text: loc.home),
                  Tab(text: loc.myWave),
                  Tab(text: loc.settings),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Row(
                  children: [
                    Expanded(flex: 5, child: _buildMainPlayerArea(current)),
                    Expanded(flex: 4, child: _buildSearchPanel()),
                  ],
                ),

                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.waves, size: 140, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 40),
                      Text(loc.myWave, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(loc.personalRecommendations, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 60),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _startMyWave,
                        icon: const Icon(Icons.play_arrow_rounded, size: 36),
                        label: Text(_loading ? loc.loading : loc.startMyWave),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 22),
                          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                      ),
                    ],
                  ),
                ),

                SingleChildScrollView(
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
                                return Text(text, style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500));
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
                        ],
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
                                return Text(locale.languageCode == 'ru' ? 'Русский' : 'English', style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500));
                              },
                            ),
                            onTap: _showLanguagePicker,
                          ),
                        ],
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
                      ),

                      const SizedBox(height: 60),

                      Center(
                        child: Text(
                          'lizaplayer v1.2.6',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: TextStyle(fontSize: 17, color: titleColor, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 13.5)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onTap: onTap,
    );
  }

  Widget _buildMainPlayerArea(Track? current) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
          child: Container(
            key: ValueKey(current?.id ?? 'empty'),
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.65 : 0.25),
                  blurRadius: 70,
                  spreadRadius: isDark ? 12 : 6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: current != null
                  ? CachedNetworkImage(
                      imageUrl: _getCoverUrl(current.coverUri, size: '400x400'),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 140, color: Colors.white24),
                    )
                  : const Icon(Icons.music_note, size: 140, color: Colors.white24),
            ),
          ),
        ),

        const SizedBox(height: 40),

        if (current != null) ...[
          Text(current.title ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(current.artists?.map((a) => a.title).join(', ') ?? '', style: const TextStyle(fontSize: 17, color: Colors.grey), textAlign: TextAlign.center),
        ],

        const SizedBox(height: 30),

        if (current != null)
          Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(32)),
            child: Column(
              children: [
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
                          activeColor: Theme.of(context).colorScheme.primary,
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

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: _playPrevious),
                    IconButton(
                      icon: StreamBuilder<PlayerState>(
                        stream: _playerService.player.playerStateStream,
                        builder: (_, snap) => Icon((snap.data?.playing ?? false) ? Icons.pause : Icons.play_arrow, size: 52),
                      ),
                      onPressed: () => _playerService.player.playing ? _playerService.player.pause() : _playerService.player.play(),
                    ),
                    IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: _playNext),
                  ],
                ),

                Row(
                  children: [
                    const Icon(Icons.volume_down),
                    Expanded(
                      child: StreamBuilder<double>(
                        stream: _playerService.player.volumeStream,
                        builder: (_, snap) => Slider(
                          value: snap.data ?? _playerService.volume,
                          activeColor: Theme.of(context).colorScheme.primary,
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
      ],
    );
  }

  Widget _buildSearchPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(28)),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: loc.searchTracks,
                      hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    onSubmitted: (_) => _searchTracks(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: _searchTracks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    child: Text(loc.find, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _tracks.isEmpty
                ? Center(child: Text(loc.findSomething, style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      final isPlaying = _playerService.currentTrack?.id == track.id;

                      final durationText = _formatDuration(
                        track.durationMs != null 
                            ? Duration(milliseconds: track.durationMs!) 
                            : null
                      );

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: _getCoverUrl(track.coverUri, size: '80x80'),
                            width: 45,
                            height: 45,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                          ),
                        ),
                        title: Text(track.title ?? ''),
                        subtitle: Text(track.artists?.map((a) => a.title).join(', ') ?? ''),
                        trailing: isPlaying 
                            ? const Icon(Icons.play_circle, color: Colors.cyan)
                            : Text(
                                durationText,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                        onTap: () => _playTrack(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
