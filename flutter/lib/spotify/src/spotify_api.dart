import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';

import '../spotify.dart';
import 'spotify_auth_client.dart';
import 'spotify_login_page.dart';

typedef _TransformFunc<T> = T Function(Map<String, dynamic>);

class SpotifyApi {
  /*
   * Singleton logic
   */

  static SpotifyApi? _instance;

  factory SpotifyApi() {
    _instance ??= new SpotifyApi._internal();
    return _instance!;
  }

  SpotifyApi._internal();

  /*
   * Members
   */

  static const String _AUTH_CODE_KEY = 'SPOTIFY_AUTH_CODE_KEY_V1';

  bool _init = false;
  late String _path;
  late SharedPreferences _prefs;
  late AuthorizedSpotifyClient _client;

  /*
   * Business methods
   */

  Future<String?> init(BuildContext context) async {
    if (_init) {
      return null;
    }

    _init = true;
    _prefs = await SharedPreferences.getInstance();
    _path = p.join((await getTemporaryDirectory()).path, 'spotify_cache');
    final dir = new Directory(_path);
    if (!dir.existsSync()) {
      dir.createSync();
    }

    String? authCode = _prefs.getString(_AUTH_CODE_KEY);
    if (authCode == null) {
      // Await user authorization
      final credentials = (await Navigator.push<SpotifyLoginPageResult>(
        context,
        MaterialPageRoute(builder: (context) => new SpotifyLoginPage()),
      ))!;

      // Save token and return possible error
      if (credentials.code != null) {
        authCode = credentials.code!;
        _prefs.setString(_AUTH_CODE_KEY, authCode);
      } else {
        return credentials.error!;
      }
    }

    _client = new AuthorizedSpotifyClient(_prefs, authCode);
    return null;
  }

  Future<void> resetAuth(BuildContext context) async {
    // Await user authorization
    _prefs.remove(_AUTH_CODE_KEY);
    final credentials = (await Navigator.push<SpotifyLoginPageResult>(
      context,
      MaterialPageRoute(builder: (context) => new SpotifyLoginPage()),
    ))!;

    // Save token and return possible error
    if (credentials.code != null) {
      final authCode = credentials.code!;
      _prefs.setString(_AUTH_CODE_KEY, authCode);
    }
  }

  Future<List<SpotifyPlaylist>> getUserPlaylists() {
    const endpoint = '/v1/me/playlists';
    SpotifyPlaylist transform(Map<String, dynamic> json) =>
        SpotifyPlaylist.fromJson(json);
    // No caching key here - blocking event!
    return _paginateEager(endpoint, transform);
  }

  Stream<List<SpotifyTrack>?> getUserTracks() async* {
    const endpoint = '/v1/me/tracks';
    SpotifyTrack transform(Map<String, dynamic> json) {
      if (json.containsKey('track')) {
        return SpotifyTrack.fromJson(json['track'] as Map<String, dynamic>);
      }
      return SpotifyTrack.fromJson(json);
    }

    // No caching key here - but usually a lot of data
    const fileName = 'songs.json';
    final cacheFile = new File(p.join(_path, fileName));
    if (!cacheFile.existsSync()) {
      // Fetch and Persist
      final buffer = <SpotifyTrack>[];
      yield* _paginateLazy(endpoint, transform).asBroadcastStream()
        ..listen((page) => buffer.addAll(page)).onDone(() {
          _persist(cacheFile, buffer);
        });
    } else {
      final cached =
          await _transformFromPersisted(cacheFile, endpoint, transform);
      final controller = new StreamController<List<SpotifyTrack>?>();
      controller.add(cached);

      // Fetch all and update on delta
      _paginateEager(endpoint, transform).then((fetched) {
        if (!const ListEquality<SpotifyTrack>().equals(fetched, cached)) {
          controller.add(null); // Clear sentinel
          controller.add(fetched);
          _persist(cacheFile, fetched);
        }
        controller.close();
      });
      yield* controller.stream;
    }
  }

  Stream<List<SpotifyTrack>> getPlaylistTracks(SpotifyPlaylist playlist) {
    final endpoint = '/v1/playlists/${playlist.id}/tracks';
    final path = p.join(_path, 'playlist_${playlist.snapshotId}.json');
    SpotifyTrack transform(Map<String, dynamic> json) {
      if (json.containsKey('track')) {
        json = json['track'] as Map<String, dynamic>;
      }
      return SpotifyTrack.fromJson(json);
    }

    // playlist.snapShotId cache key,
    return _getCached(endpoint, path, transform);
  }

  Stream<List<SpotifyTrack>> getAlbumTracks(SpotifyAlbum album) {
    final endpoint = '/v1/albums/${album.id}/tracks';
    final path = p.join(_path, 'album_${album.id}.json');
    SpotifyTrack transform(Map<String, dynamic> json) =>
        SpotifyTrack.fromJson(json);
    // album.id cache key,
    return _getCached(endpoint, path, transform);
  }

  Future<Tuple3<List<SpotifyPlaylist>, List<SpotifyAlbum>, List<SpotifyTrack>>>
      searchAll(String q) async {
    final encodedQ = Uri.encodeComponent(q);
    final endpoint =
        '/v1/search?q=$encodedQ&type=track,playlist,album&limit=10';
    final source = await _client.authorizedGet(endpoint);

    final json = jsonDecode(source) as Map<String, dynamic>;
    final playlistsJson = json['playlists']['items'] as Iterable<dynamic>;
    final albumJson = json['albums']['items'] as Iterable<dynamic>;
    final tracksJson = json['tracks']['items'] as Iterable<dynamic>;
    final playlists = playlistsJson
        .map((dynamic json) =>
            SpotifyPlaylist.fromJson(json as Map<String, dynamic>))
        .toList();
    final albums = albumJson
        .map((dynamic json) =>
            SpotifyAlbum.fromJson(json as Map<String, dynamic>))
        .toList();
    final tracks = tracksJson
        .map((dynamic json) =>
            SpotifyTrack.fromJson(json as Map<String, dynamic>))
        .toList();

    return new Tuple3(playlists, albums, tracks);
  }

  Future<List<SpotifyTrack>> searchTracks(String q) async {
    final encodedQ = Uri.encodeComponent(q);
    final endpoint = '/v1/search?q=$encodedQ&type=track&limit=10';
    final source = await _client.authorizedGet(endpoint);

    final json = jsonDecode(source) as Map<String, dynamic>;
    final tracksJson = json['tracks']['items'] as Iterable<dynamic>;

    return tracksJson
        .map((dynamic json) =>
            SpotifyTrack.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<SpotifyPlaylist>> searchPlaylists(String q) async {
    final encodedQ = Uri.encodeComponent(q);
    final endpoint = '/v1/search?q=$encodedQ&type=playlist&limit=10';
    final source = await _client.authorizedGet(endpoint);

    final json = jsonDecode(source) as Map<String, dynamic>;
    final playlistsJson = json['playlists']['items'] as Iterable<dynamic>;

    return playlistsJson
        .map((dynamic json) =>
            SpotifyPlaylist.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<SpotifyAlbum>> searchAlbums(String q) async {
    final encodedQ = Uri.encodeComponent(q);
    final endpoint = '/v1/search?q=$encodedQ&type=album&limit=10';
    final source = await _client.authorizedGet(endpoint);

    final json = jsonDecode(source) as Map<String, dynamic>;
    final albumJson = json['albums']['items'] as Iterable<dynamic>;

    return albumJson
        .map((dynamic json) =>
            SpotifyAlbum.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void _persist<T extends Dto>(File cacheFile, List<T> toPersist) {
    final fetchedJson = toPersist.map((t) => t.toJson()).toList();
    cacheFile.writeAsString(jsonEncode(fetchedJson));
  }

  Stream<List<T>> _fetchAndPersist<T extends Dto>(
      File cacheFile, String endpoint, _TransformFunc<T> transformFun) {
    // Fetch and filter
    final fetched = <T>[];
    final stream = _paginateLazy(endpoint, transformFun).asBroadcastStream();
    // Persist
    bool hasError = false;
    stream.listen((part) => fetched.addAll(part),
        onError: (dynamic _) => hasError = true,
        onDone: () {
          if (!hasError) {
            _persist(cacheFile, fetched);
          } else {
            Sentry.captureMessage('Failed to fetch and persist $endpoint',
                level: SentryLevel.error);
          }
        });
    return stream;
  }

  Future<List<T>> _transformFromPersisted<T extends Dto>(
      File cacheFile, String endpoint, _TransformFunc<T> transformFun) async {
    final cachedJson = cacheFile.readAsStringSync();
    final jsonUntyped = jsonDecode(cachedJson) as List<dynamic>;
    final List<Map<String, dynamic>> jsonList = jsonUntyped.cast();
    return jsonList.map((json) => transformFun(json)).toList();
  }

  Stream<List<T>> _getCached<T extends Dto>(
      String endpoint, String fileName, _TransformFunc<T> transformFun) async* {
    final cacheFile = new File(p.join(_path, fileName));
    if (cacheFile.existsSync()) {
      yield await _transformFromPersisted(cacheFile, endpoint, transformFun);
    } else {
      yield* _fetchAndPersist(cacheFile, endpoint, transformFun);
    }
  }

  T? _tryTransform<T>(dynamic map, _TransformFunc<T> transformFun) {
    try {
      return transformFun(map as Map<String, dynamic>);
    } catch (e, trace) {
      print("Couldn't transform json: $map");
      Sentry.captureException(e, stackTrace: trace);
      return null;
    }
  }

  Future<List<T>> _paginateEager<T>(
      String endpoint, _TransformFunc<T> transformFun,
      [int max = 0xffff]) async {
    final fetchedResult = <T>[];

    // Fetch, convert and transform
    String source = await _tryGet(endpoint);
    SpotifyPager pager =
        SpotifyPager.fromJson(jsonDecode(source) as Map<String, dynamic>);
    fetchedResult.addAll(pager.items
        .map((dynamic item) => _tryTransform(item, transformFun))
        .where((opt) => opt != null)
        .map((e) => e!));

    // Repeat
    while (pager.next != null && fetchedResult.length <= max) {
      source = await _tryGet(pager.next!, '');
      pager = SpotifyPager.fromJson(jsonDecode(source) as Map<String, dynamic>);

      fetchedResult.addAll(pager.items
          .map((dynamic item) => _tryTransform(item, transformFun))
          .where((opt) => opt != null)
          .map((e) => e!));
    }

    return fetchedResult;
  }

  Stream<List<T>> _paginateLazy<T>(
      String endpoint, _TransformFunc<T> transformFun,
      [int max = 0xffff]) async* {
    // Fetch, convert and transform
    List<T> items;
    String source;
    int count = 0;

    source = await _tryGet(endpoint);
    SpotifyPager pager =
        SpotifyPager.fromJson(jsonDecode(source) as Map<String, dynamic>);
    items = pager.items
        .map((dynamic item) =>
            _tryTransform(item as Map<String, dynamic>, transformFun))
        .where((opt) => opt != null)
        .map((e) => e!)
        .toList();
    count += items.length;
    yield items;

    // Repeat
    while (pager.next != null && count <= max) {
      source = await _tryGet(pager.next!, '');
      pager = SpotifyPager.fromJson(jsonDecode(source) as Map<String, dynamic>);

      items = pager.items
          .map((dynamic item) =>
              _tryTransform(item as Map<String, dynamic>, transformFun))
          .where((opt) => opt != null)
          .map((e) => e!)
          .toList();
      count += items.length;
      yield items;
    }
  }

  Future<String> _tryGet(String endpoint, [String? baseUrl]) async {
    String? source;
    int tries = 5;
    do {
      try {
        source = await _client.authorizedGet(endpoint, baseUrl: baseUrl);
      } catch (err) {
        if (tries-- == 0) {
          rethrow;
        }
        // Check for API limit
        if (err is StateError) {
          try {
            final int errorCode =
                jsonDecode(err.message)['error']['status'] as int;
            if (errorCode == 429) {
              await new Future<void>.delayed(const Duration(milliseconds: 500));
            }
          } catch (_) {}
        }
      }
    } while (source == null);
    return source;
  }
}
