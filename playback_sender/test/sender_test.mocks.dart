// Mocks generated by Mockito 5.0.16 from annotations
// in chrome_tube/test/sender_test.dart.
// Do not manually edit this file.

// ignore_for_file: unnecessary_overrides

import 'dart:async' as _i3;

import 'package:chrome_tube/playback/src/ipc/cast_playback_context.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;
import 'package:playback_interop/playback_interop.dart' as _i4;

// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types

/// A class which mocks [CastPlaybackContext].
///
/// See the documentation for Mockito's code generation for more information.
class MockCastPlaybackContext extends _i1.Mock
    implements _i2.CastPlaybackContext {
  MockCastPlaybackContext() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Future<void> send(_i4.CastMessage<dynamic>? message) =>
      (super.noSuchMethod(Invocation.method(#send, [message]),
          returnValue: Future<void>.value(),
          returnValueForMissingStub: Future<void>.value()) as _i3.Future<void>);
  @override
  _i3.Future<void> end() => (super.noSuchMethod(Invocation.method(#end, []),
      returnValue: Future<void>.value(),
      returnValueForMissingStub: Future<void>.value()) as _i3.Future<void>);
  @override
  String toString() => super.toString();
}