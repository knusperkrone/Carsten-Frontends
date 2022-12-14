import 'package:playback_core/playback_core.dart';

// ignore: avoid_classes_with_only_static_members
class Transformer {
  static List<PlaybackTrack> transfromTracks(List<dynamic> array) => array.map(transformTrack).toList();

  static PlaybackTrack transformTrack(dynamic object) {
    return new PlaybackTrack(
      album: object.album as String,
      artist: object.artist as String,
      coverUrl: object.coverUrl as String,
      durationMs: object.durationMs as int?,
      isPrio: object.isPrio as bool,
      origQueueIndex: object.origQueueIndex as int,
      queueIndex: object.queueIndex as int,
      title: object.title as String,
    );
  }
}
