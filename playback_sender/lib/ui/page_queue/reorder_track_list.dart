import 'package:cached_network_image/cached_network_image.dart';
import 'package:chrome_tube/playback/playback.dart';
import 'package:chrome_tube/ui/common/state.dart';
import 'package:chrome_tube/utils/forked/reorderable_sliver/reorderable_sliver.dart';
import 'package:flutter/material.dart';
import 'package:playback_interop/playback_interop.dart';

class ReorderTrackList extends StatefulWidget {
  const ReorderTrackList({Key key}) : super(key: key);

  @override
  State createState() => ReorderTrackListState();
}

class ReorderTrackListState extends CachingState<ReorderTrackList>
    with SingleTickerProviderStateMixin {
  // ignore: non_constant_identifier_names
  static final _PLACEHOLDER_TRACK =
      new PlaybackTrack.dummy(artist: '', coverUrl: '', title: '');

  final _manager = new PlaybackManager();
  List<PlaybackTrack> _shadowPrioTracks;
  List<PlaybackTrack> _shadowQueueTracks;
  AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _shadowPrioTracks = List.of(_manager.prioTracks);
    _shadowQueueTracks = List.of(_manager.queueTracks);

    _animController = new AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _animController.value = _shadowPrioTracks.isEmpty ? 0.0 : 1.0;
  }

  void rebuild() {
    setState(() {
      _shadowPrioTracks = List.of(_manager.prioTracks);
      _shadowQueueTracks = List.of(_manager.queueTracks);
      _animateQueueText();
    });
  }

  void _animateQueueText() {
    if (_shadowPrioTracks.isEmpty) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
  }

  /*
   * Ordering
   */

  bool _canReorder(int i) => i != _shadowPrioTracks.length; // Is barrier

  void _onStartReorder() {
    if (_animController.value == 0.0) {}
  }

  void _onReorder(int startIndex, int targetIndex) {
    setState(() {
      final startPrio = startIndex <= _shadowPrioTracks.length;
      bool targetPrio = targetIndex <= _shadowPrioTracks.length;
      // targetPrio might be wrong, as we drag on the barrier
      if ((startPrio && targetPrio) &&
          (_shadowPrioTracks.isNotEmpty &&
              _shadowPrioTracks.length == targetIndex)) {
        targetPrio = false;
      }

      // get lists
      final startList = startPrio ? _shadowPrioTracks : _shadowQueueTracks;
      final targetList = targetPrio ? _shadowPrioTracks : _shadowQueueTracks;
      int localStartIndex;
      int localTargetIndex;

      if (!startPrio && !targetPrio) {
        localStartIndex = startIndex - (_shadowPrioTracks.length - 1);
        localTargetIndex = targetIndex - (_shadowPrioTracks.length - 1);
        startIndex -= _shadowPrioTracks.length - 1;
        targetIndex -= _shadowPrioTracks.length - 1;
      } else if (!startPrio && targetPrio) {
        localStartIndex = startIndex - (_shadowPrioTracks.length - 1);
        localTargetIndex = targetIndex;
        startIndex -= _shadowPrioTracks.length - 1;
        // targetIndex = targetIndex;
      } else if (startPrio && !targetPrio) {
        localStartIndex = startIndex;
        localTargetIndex = targetIndex - (_shadowPrioTracks.length - 2);
        // startIndex = startIndex;
        targetIndex -= _shadowPrioTracks.length - 2;
      } else {
        localStartIndex = startIndex;
        localTargetIndex = targetIndex;
      }
      final row = startList.removeAt(localStartIndex);
      targetList.insert(localTargetIndex, row);
      // send to manager and wait for the broadcast
      _manager.sendMove(startPrio, startIndex, targetPrio, targetIndex);
      _animateQueueText();
    });
  }

  /*
   * build
   */

  int get trackCount {
    if (_shadowQueueTracks.isEmpty) {
      return _shadowPrioTracks.length;
    }
    int count = _shadowPrioTracks.length;
    count += _shadowQueueTracks.length - _manager.trackIndex; // rest list
    return count;
  }

  Widget _buildTile(BuildContext context, int i) {
    PlaybackTrack curr;
    if (i < _shadowPrioTracks.length) {
      curr = _shadowPrioTracks[i];
    } else if (i == _shadowPrioTracks.length) {
      // Barrier
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 7.0),
        child: Text(
          locale.translate('next_queue'),
          style: theme.textTheme.headline6,
        ),
      );
    } else {
      final offset = _manager.trackIndex + i - _shadowPrioTracks.length;
      curr = _shadowQueueTracks[offset];
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        height: 50,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.album,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    curr?.title ?? '',
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                    style: theme.textTheme.subtitle1.copyWith(fontSize: 16.0),
                  ),
                  Text(
                    curr?.artist ?? '',
                    maxLines: 1,
                    style: TextStyle(
                      color: theme.textTheme.caption.color,
                      fontSize: 13.0,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10.0),
              child: Icon(Icons.drag_handle),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 7.0),
            child: Text(
              locale.translate('current_title'),
              style: theme.textTheme.headline6,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ListTile(
            leading: CachedNetworkImage(
              imageUrl: _manager.track.orElse(_PLACEHOLDER_TRACK).coverUrl,
              placeholder: (_, __) => Container(width: 56.0),
            ),
            title: Text(_manager.track.orElse(_PLACEHOLDER_TRACK).title),
            subtitle: Text(_manager.track.orElse(_PLACEHOLDER_TRACK).artist),
          ),
        ),
        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return Container(
                width: double.infinity,
                height: 40 * _animController.value,
                child: _animController.value > 0.7
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 5.0, horizontal: 7.0),
                        child: Opacity(
                          opacity: _animController.value,
                          child: Text(
                            locale.translate('next_prio_queue'),
                            style: theme.textTheme.headline6,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
        ReorderableSliverList(
          onStartReorder: _onStartReorder,
          canReorder: _canReorder,
          onReorder: _onReorder,
          delegate: ReorderableSliverChildBuilderDelegate(
            _buildTile,
            childCount: trackCount,
          ),
        ),
      ],
    );
  }
}
