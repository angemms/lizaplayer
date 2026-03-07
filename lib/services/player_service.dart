import 'package:just_audio/just_audio.dart';
import 'package:yandex_music/yandex_music.dart';

class PlayerService {
  final AudioPlayer player = AudioPlayer();
  YandexMusic? _client;
  List<Track> currentPlaylist = [];
  int currentIndex = -1;
  Track? currentTrack;
  Duration? get duration => player.duration;
  double volume = 1.0;

  void setClient(YandexMusic client) {
    _client = client;
  }

  Future<void> playFromPlaylist(List<Track> playlist, int index) async {
    if (_client == null) throw Exception('Client not set');
    currentPlaylist = playlist;
    currentIndex = index;
    await playTrack(playlist[index]);
  }

  Future<void> playTrack(Track track) async {
    if (_client == null) throw Exception('Client not set');
    currentTrack = track;
    try {
      final url = await _client!.tracks.getDownloadLink(track.id.toString());
      await player.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
        preload: true,
      );
      await player.play();
    } catch (e) {
      print('Play error: $e');
    }
  }

  void next() {
    if (currentIndex >= 0 && currentIndex + 1 < currentPlaylist.length) {
      playFromPlaylist(currentPlaylist, currentIndex + 1);
    }
  }

  void previous() {
    if (currentIndex > 0) {
      if (player.position.inSeconds > 3) {
        player.seek(Duration.zero);
      } else {
        playFromPlaylist(currentPlaylist, currentIndex - 1);
      }
    } else {
      player.seek(Duration.zero);
    }
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    await player.setVolume(volume);
  }

  void dispose() {
    player.dispose();
  }
}
