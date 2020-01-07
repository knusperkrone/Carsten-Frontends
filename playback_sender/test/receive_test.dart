import 'dart:convert';

import 'package:chrome_tube/playback/playback.dart';
import 'package:chrome_tube/playback/src/ipc/foreground_dispatcher.dart';
import 'package:chrome_tube/playback/src/ipc/message_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:playback_interop/playback_interop.dart';
import 'package:playback_interop/playback_interop_test.dart';

import 'mocks.dart';

void main() {
  MessageDispatcher dispatcher;
  PlaybackManager manager;

  String _buildCafMsg(String type, Dto dto) =>
      jsonEncode(new CastMessage(type, jsonEncode(dto.toJson())));

  group('CAF Dto recevie tests', () {
    setUp(() {
      manager = new MockedPlaybackManager();
      dispatcher = new ForegroundDispatcher.test(manager);
    });

    test('On Ready', () async {
      // Prepare
      final dto = new ReadyDto.fromJson(jsonDecode(readyDtoJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_READY, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onConnect(dto)).called(1);
    });

    test('On Repeating', () async {
      // Prepare
      final dto = new RepeatingDto.fromJson(jsonDecode(repeatingDtoJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_REPEATING, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onRepeating(dto)).called(1);
    });

    test('On Seek', () async {
      // Prepare
      final dto = new SeekDto.fromJson(jsonDecode(seekDtoJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_SEEK, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onTrackSeek(dto)).called(1);
    });

    test('On PlayerState', () async {
      // Prepare
      final dto =
          new PlayerStateDto.fromJson(jsonDecode(playerStateDtoJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_STATE_CHANGED, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onPlayerState(dto)).called(1);
    });

    test('On TrackState', () async {
      // Prepare
      final dto = new TrackStateDto.fromJson(jsonDecode(trackStateDtoJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_TRACK, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onTrackState(dto)).called(1);
    });

    test('On ErrorStateDto', () async {
      // Prepare
      final dto = new ErrorDto.fromJson(jsonDecode(errorStateDtoJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_ERROR, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onError(dto)).called(1);
    });

    test('On Queue', () async {
      // Prepare
      final dto = new PlaybackQueueDto.fromJson(jsonDecode(queueJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_QUEUE, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onQueue(dto)).called(1);
    });

    test('On Shuffle', () async {
      // Prepare
      final dto = new ShuffleStateDto.fromJson(jsonDecode(shuffledJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_SHUFFLING, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onShuffling(captureAny)).called(1);
    });

    test('On Add to Prio', () async {
      // Prepare
      final dto = new AddPrioDeltaDto.fromJson(jsonDecode(addPrioJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_DELTA_ADD, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onAddPrioDelta(dto)).called(1);
    });

    test('On Mov', () async {
      // Prepare
      final dto = new MovePrioDeltaDto.fromJson(jsonDecode(movDeltaJson) as Map<String, dynamic>);
      final jsonMsg = _buildCafMsg(CafToSenderConstants.PB_DELTA_MOVE, dto);

      // Execute
      await dispatcher.dispatchMessage(jsonMsg);

      // Validate
      verify(manager.onMovePrioDelta(dto)).called(1);
    });
  });
}
