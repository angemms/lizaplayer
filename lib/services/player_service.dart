import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yandex_music/yandex_music.dart';

class PlayerService {
  final AudioPlayer _player = AudioPlayer();
  Track? currentTrack;

  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Duration? get duration => _player.duration;
  double get volume => _player.volume;

  Future<void> setVolume(double vol) => _player.setVolume(vol.clamp(0.0, 1.0));

  Future<void> playTrack(Track track, YandexMusic client) async {
    currentTrack = track;

    try {
      final bytes = await client.tracks.download(track.id.toString());

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/current_${track.id}.mp3');

      await file.writeAsBytes(bytes);

      await _player.setFilePath(file.path);
      await _player.play();

      print('Запущен: ${track.title}');
    } catch (e) {
      print('Ошибка: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
