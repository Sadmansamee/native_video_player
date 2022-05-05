import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:native_video_player/src/playback_status.dart';
import 'package:native_video_player/src/video_info.dart';

import 'platform_interface/native_video_player_api.dart';
import 'playback_info.dart';
import 'video_source.dart';

class NativeVideoPlayerController {
  late final NativeVideoPlayerApi _api;
  VideoSource? _videoSource;
  VideoInfo? _videoInfo;

  Timer? _playbackPositionTimer;

  double _volume = 0;

  PlaybackStatus get _playbackStatus => onPlaybackStatusChanged.value;

  int get _playbackPosition => onPlaybackPositionChanged.value;

  double get _playbackPositionFraction => videoInfo != null //
      ? _playbackPosition / videoInfo!.duration
      : 0;

  String? get _error => onError.value;

  /// Emitted when the video loaded successfully and it's ready to play.
  /// /// At this point, [videoInfo] is available.
  final onPlaybackReady = ChangeNotifier();

  final onPlaybackStatusChanged = ValueNotifier<PlaybackStatus>(
    PlaybackStatus.stopped,
  );
  final onPlaybackPositionChanged = ValueNotifier<int>(0);
  final onPlaybackEnded = ChangeNotifier();
  final onError = ValueNotifier<String?>(
    null,
  );

  VideoSource? get videoSource => _videoSource;

  VideoInfo? get videoInfo => _videoInfo;

  PlaybackInfo? get playbackInfo => PlaybackInfo(
        status: _playbackStatus,
        position: _playbackPosition,
        positionFraction: _playbackPositionFraction,
        volume: _volume,
        error: _error,
      );

  /// NOTE: For internal use only.
  /// See [NativeVideoPlayerView.onViewReady] instead.
  @protected
  NativeVideoPlayerController(int viewId) {
    _api = NativeVideoPlayerApi(
      viewId: viewId,
      onPlaybackReady: _onPlaybackReady,
      onPlaybackEnded: _onPlaybackEnded,
      onError: _onError,
    );
  }

  Future<void> _onPlaybackReady() async {
    _videoInfo = await _api.getVideoInfo();
    await setVolume(_volume);
    onPlaybackReady.notifyListeners();
  }

  Future<void> _onPlaybackEnded() async {
    await stop();
    onPlaybackEnded.notifyListeners();
  }

  void _onError(String? message) {
    onError.value = message;
  }

  // NOTE: For internal use only.
  @protected
  void dispose() {
    _stopPlaybackPositionTimer();
    _api.dispose();
  }

  Future<void> loadVideoSource(VideoSource videoSource) async {
    try {
      await stop();
      await _api.loadVideoSource(videoSource);
      _videoSource = videoSource;
    } catch (exception) {
      print(exception);
    }
  }

  /// Starts/resumes the playback of the video.
  Future<void> play() async {
    try {
      await _api.play();
      _startPlaybackPositionTimer();
      onPlaybackStatusChanged.value = PlaybackStatus.playing;
    } catch (exception) {
      print(exception);
    }
  }

  /// Pauses the playback of the video. Use
  /// [play] to resume the playback at any time.
  Future<void> pause() async {
    try {
      await _api.pause();
      _stopPlaybackPositionTimer();
      onPlaybackStatusChanged.value = PlaybackStatus.paused;
    } catch (exception) {
      print(exception);
    }
  }

  /// Stops the playback of the video.
  Future<void> stop() async {
    try {
      await _api.stop();
      _stopPlaybackPositionTimer();
      onPlaybackStatusChanged.value = PlaybackStatus.stopped;
      await _onPlaybackPositionTimerChanged(null);
    } catch (exception) {
      print(exception);
    }
  }

  /// Gets the state of the player.
  /// Returns true if the player is playing or false if is stopped or paused.
  Future<bool> isPlaying() async {
    try {
      return await _api.isPlaying() ?? false;
    } catch (exception) {
      print(exception);
      return false;
    }
  }

  /// Moves the cursor of the playback to an specific time.
  /// Must give the [seconds] of the specific millisecond of playback, if
  /// the [seconds] is bigger than the duration of source the duration
  /// of the video is used as position.
  Future<void> seekTo(int seconds) async {
    var position = seconds;
    if (seconds < 0) position = 0;
    final duration = videoInfo?.duration ?? 0;
    if (seconds > duration) position = duration;
    try {
      await _api.seekTo(position);
    } catch (exception) {
      print(exception);
    }
  }

  Future<void> seekForward(int seconds) async {
    if (seconds < 0) return;
    if (seconds == 0) return;
    final duration = videoInfo?.duration ?? 0;
    final newPlaybackPosition = _playbackPosition + seconds > duration //
        ? duration
        : _playbackPosition + seconds;
    await seekTo(newPlaybackPosition);
  }

  Future<void> seekBackward(int seconds) async {
    if (seconds < 0) return;
    if (seconds == 0) return;
    final newPlaybackPosition = _playbackPosition - seconds < 0 //
        ? 0
        : _playbackPosition - seconds;
    await seekTo(newPlaybackPosition);
  }

  /// Sets the volume of the player.
  Future<void> setVolume(double volume) async {
    try {
      await _api.setVolume(volume);
      _volume = volume;
    } catch (exception) {
      print(exception);
    }
  }

  void _startPlaybackPositionTimer() {
    _stopPlaybackPositionTimer();
    _playbackPositionTimer ??= Timer.periodic(
      const Duration(milliseconds: 100),
      _onPlaybackPositionTimerChanged,
    );
  }

  void _stopPlaybackPositionTimer() {
    if (_playbackPositionTimer == null) return;
    _playbackPositionTimer!.cancel();
    _playbackPositionTimer = null;
  }

  Future<void> _onPlaybackPositionTimerChanged(Timer? timer) async {
    try {
      final position = await _api.getPlaybackPosition() ?? 0;
      onPlaybackPositionChanged.value = position;
    } catch (exception) {
      print(exception);
    }
  }
}