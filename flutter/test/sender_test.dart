import 'dart:convert';

import 'package:chrome_tube/playback/playback.dart';
import 'package:chrome_tube/playback/src/ipc/cast_playback_context.dart';
import 'package:chrome_tube/playback/src/playback_sender.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:playback_core/playback_core.dart';
import 'package:playback_core/playback_core_test.dart';

import 'sender_test.mocks.dart';

@GenerateMocks([CastPlaybackContext])
void main() {
  late MockCastPlaybackContext context;
  late PlaybackSender sender;

  setUp(() {
    context = new MockCastPlaybackContext();
    sender = new PlaybackManager.test(context);
  });

  test('Play', () {
    // Prepare
    final expectedMessage =
        new CastMessage<String>(SenderToCafConstants.PB_PLAY, '');

    // Execute
    sender.sendPlay();

    // Verify
    verify(context.send(argThat(equals(expectedMessage)))).called(1);
  });

  test('Pause', () {
    // Prepare
    final expectedMessage =
        new CastMessage<String>(SenderToCafConstants.PB_PAUSE, '');

    // Execute
    sender.sendPause();

    // Verify
    verify(context.send(argThat(equals(expectedMessage)))).called(1);
  });

  test('Send tracks with pagination', () async {
    // Prepare
    final expectedTracks =
        new List.generate(8192, (_) => new PlaybackTrack.fromJson(jsonDecode(trackJson) as Map<String, dynamic>));

    // Execute
    await sender.sendTracks(expectedTracks, 0, '');

    // Validate
    int trackIndex = 0;
    final captured = new List<dynamic>.from(verify(context.send(captureAny)).captured);

    // Clear queue at first
    final first = captured.removeAt(0) as CastMessage;
    expect(first.type, SenderToCafConstants.PB_CLEAR_QUEUE);

    final castedCaptured = captured.cast<CastMessage<dynamic>>();
    for (CastMessage<dynamic> resultMsg in castedCaptured) {
      // Assert valid message
      expect(resultMsg.type, SenderToCafConstants.PB_APPEND_TO_QUEUE);
      expect(jsonEncode(resultMsg.toJson()).length, lessThan(512000));

      // Notify on last msg
      if (resultMsg == captured.last) {
        expect(trackIndex, expectedTracks.length);
        expect(resultMsg.data, <PlaybackTrack>[]);
        break;
      }

      // Populate queue
      for (PlaybackTrack resultTrack in resultMsg.data as List<PlaybackTrack>) {
        final expectedTrack = expectedTracks[trackIndex++];
        expect(resultTrack, expectedTrack);
      }
    }
  });

  test('Stop', () {
    // Prepare
    final expectedMessage =
        new CastMessage<String>(SenderToCafConstants.PB_STOP, '');

    // Execute
    sender.sendStop();

    // Verify
    verify(context.send(argThat(equals(expectedMessage)))).called(1);
  });

  test('Next song', () async {
    // Prepare
    final expectedMessage =
        new CastMessage<String>(SenderToCafConstants.PB_NEXT_TRACK, '');

    // Execute
    await Future<void>.delayed(const Duration(milliseconds: 5));
    sender.sendNext();

    // Verify
    verify(context.send(argThat(equals(expectedMessage)))).called(1);
  });

  test('Previous song', () async {
    // Prepare
    final expectedMessage =
        new CastMessage<String>(SenderToCafConstants.PB_PREV_TRACK, '');

    // Execute
    await Future<void>.delayed(const Duration(milliseconds: 5));
    sender.sendPrevious();

    // Verify
    verify(context.send(argThat(equals(expectedMessage)))).called(1);
  });

  test('Set shuffling', () {
    // Prepare
    final expectedShuffleMessage =
        new CastMessage<bool>(SenderToCafConstants.PB_SHUFFLING, true);
    final expectedNoShuffleMessage =
        new CastMessage<bool>(SenderToCafConstants.PB_SHUFFLING, false);

    // Execute
    sender.sendShuffling(true);
    sender.sendShuffling(false);

    // Verify
    verifyInOrder([
      context.send(argThat(equals(expectedShuffleMessage))),
      context.send(argThat(equals(expectedNoShuffleMessage)))
    ]);
  });

  test('Set repeating', () {
    // Prepare
    final expectedRepeatMessage =
        new CastMessage<bool>(SenderToCafConstants.PB_REPEATING, true);
    final expectedNoRepeatMessage =
        new CastMessage<bool>(SenderToCafConstants.PB_REPEATING, false);

    // Execute
    sender.sendRepeating(true);
    sender.sendRepeating(false);

    // Verify
    verifyInOrder([
      context.send(argThat(equals(expectedRepeatMessage))),
      context.send(argThat(equals(expectedNoRepeatMessage)))
    ]);
  });

  test('Set seek', () {
    // Prepare
    const seekMs = 0x42;
    final expectedMessage =
        new CastMessage<int>(SenderToCafConstants.PB_SEEK_TO, seekMs);

    // Execute
    sender.sendSeek(seekMs);

    // Verify
    verify(context.send(argThat(equals(expectedMessage)))).called(1);
  });

  test('Add to prio', () {
    // Prepare
    final track = new PlaybackTrack.fromJson(
        jsonDecode(trackJson) as Map<String, dynamic>);
    final expectedMessage = new CastMessage<PlaybackTrack>(
        SenderToCafConstants.PB_APPEND_TO_PRIO, track);

    // Execute
    sender.sendAddToPrio(track);

    // Verify
    verify(context.send(argThat(equals(expectedMessage)))).called(1);
  });

  test('Send move', () {
    // Prepare
    const startPrio = false;
    const startIndex = 0;
    const targetPrio = true;
    const targetIndex = 0;
    final expectedMessage = new CastMessage<List<dynamic>>(
        SenderToCafConstants.PB_MOVE,
        <dynamic>[startPrio, startIndex, targetPrio, targetIndex]);

    // Execute
    sender.sendMove(startPrio, startIndex, targetPrio, targetIndex);

    // Verify

    verify(context.send(argThat(_MessageListMatcher(expectedMessage))))
        .called(1);
  });
}

// List matcher helper
class _MessageListMatcher extends Matcher {
  final ListEquality listTester = const ListEquality<dynamic>();
  final CastMessage<List<dynamic>> _expected;

  _MessageListMatcher(this._expected);

  @override
  Description describe(Description description) {
    return description.addDescriptionOf(_expected);
  }

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is CastMessage<dynamic>) {
      final CastMessage<dynamic> typedItem = item;
      return typedItem.type == _expected.type &&
          listTester.equals(_expected.data, typedItem.data as List<dynamic>);
    }
    return false;
  }
}
