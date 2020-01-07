import 'package:chrome_tube/playback/playback.dart';
import 'package:chrome_tube/ui/pages.dart';
import 'package:flutter/material.dart';
import 'package:playback_interop/playback_interop.dart';

class ControlBar extends StatefulWidget {
  @override
  State createState() => ControlBarState();
}

class ControlBarState extends State<ControlBar> implements PlaybackUIListener {
  // ignore: non_constant_identifier_names
  static final _PLACEHOLDER_TRACK = PlaybackTrack.dummy(title: 'No Track', artist: '');

  final _manager = new PlaybackManager();

  @override
  void initState() {
    super.initState();
    _manager.registerListener(this);
  }

  @override
  void dispose() {
    _manager.unregisterListener(this);
    super.dispose();
  }

  /*
   * PlaybackTrackUIListener contract
   */

  @override
  void notifyPlaybackReady() => setState(() => {});

  @override
  void notifyPlayingState() => setState(() {});

  @override
  void notifyQueue() => setState(() => {});

  @override
  void notifyTrack() => setState(() => {});

  @override
  void notifyRepeating() {}

  @override
  void notifyTrackSeek() {}

  /*
   * UI callbacks
   */

  Future<void> _onOpen() async {
    return await ControlPage.navigate(context);
  }

  void _onPlayerState() {
    if (_manager.currPlayerState == SimplePlaybackState.PLAYING) {
      _manager.sendPause();
    } else if (_manager.currPlayerState == SimplePlaybackState.PAUSED) {
      _manager.sendPlay();
    }
  }

  /*
   * Build
   */

  @override
  Widget build(BuildContext context) {
    return new Column(
      children: <Widget>[
        InkWell(
          onTap: _onOpen,
          child: Container(
            width: double.infinity,
            height: kToolbarHeight,
            color: Theme.of(context).primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(icon: Icon(Icons.arrow_drop_up), onPressed: _onOpen),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      _manager.track.orElse(_PLACEHOLDER_TRACK).title,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      _manager.track.orElse(_PLACEHOLDER_TRACK).artist,
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
                IconButton(
                  icon: Icon(_manager.currPlayerState == SimplePlaybackState.PAUSED ||
                          _manager.currPlayerState == SimplePlaybackState.ENDED
                      ? Icons.play_arrow
                      : Icons.pause),
                  onPressed: _manager.isConnected ? _onPlayerState : null,
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
