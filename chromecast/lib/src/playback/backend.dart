import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:playback_core/playback_core.dart';

class BackendAdapter {
  Future<String> getVideoId(PlaybackTrack track) async {
    final key = '${track.title} ${track.artist}';
    String? id;
    try {
      final uri = Uri.https(
        'integration.if-lab.de',
        '/arme-spotitube-backend/api/youtube/search',
        <String, String>{'q': key},
      );

      final resp = await http.get(uri);
      final respBody = resp.body;

      if (resp.statusCode != 200) {
        throw new StateError('Invalid status code: ${resp.statusCode}\n$respBody');
      }
      id = jsonDecode(respBody)['id'] as String?;
      if (id == null) {
        throw new StateError('Invalid id with request ${resp.statusCode}\n$respBody');
      }
    } catch (e) {
      print('[ERROR] couldn\'t get Video id: $id\n$e');
    }

    return id ?? 'DH0BQtwEAsM'; // 2 secs of static tv noise
  }
}
