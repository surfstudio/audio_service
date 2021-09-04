// ignore_for_file: public_member_api_docs

// FOR MORE EXAMPLES, VISIT THE GITHUB REPOSITORY AT:
//
//  https://github.com/ryanheise/audio_service
//
// This example implements a minimal audio handler that renders the current
// media item and playback state to the system notification and responds to 4
// media actions:
//
// - play
// - pause
// - seek
// - stop
//
// To run this example, use:
//
// flutter run

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';

// You might want to provide this using dependency injection rather than a
// global variable.
late VideoPlayerHandler _audioHandler;

Future<void> main() async {
  _audioHandler = await AudioService.init(
    builder: () => VideoPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Service Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Service Demo'),
      ),
      body: Center(
        child: _BumbleBeeRemoteVideo(),
      ),
    );
  }

  /// A stream reporting the combined state of the current media item and its
  /// current position.
  Stream<MediaState> get _mediaStateStream =>
      Rx.combineLatest2<MediaItem?, Duration, MediaState>(
          _audioHandler.mediaItem,
          AudioService.position,
          (mediaItem, position) => MediaState(mediaItem, position));

  IconButton _button(IconData iconData, VoidCallback onPressed) => IconButton(
        icon: Icon(iconData),
        iconSize: 64.0,
        onPressed: onPressed,
      );
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

/// An [AudioHandler] for playing a single item.
class VideoPlayerHandler extends BaseAudioHandler {
  static final _items = [
    MediaItem(
      id: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      album: "Science Friday",
      title: "A Salute To Head-Scratching Science",
      artist: "Science Friday and WNYC Studios",
      duration: const Duration(milliseconds: 5739820),
      artUri: Uri.parse(
          'https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
    ),
    MediaItem(
      id: 'https://s3.amazonaws.com/scifri-segments/scifri201711241.mp3',
      album: "Science Friday",
      title: "From Cat Rheology To Operatic Incompetence",
      artist: "Science Friday and WNYC Studios",
      duration: const Duration(milliseconds: 2856950),
      artUri: Uri.parse(
          'https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
    ),
  ];

  VideoPlayerController? _controller;
  int _currentItemIndex = 0;
  final BehaviorSubject<VideoPlayerController?> _controllerSubject =
      BehaviorSubject.seeded(null);

  Stream<VideoPlayerController?> get controllerStream =>
      _controllerSubject.stream;

  /// Initialise our video handler.
  VideoPlayerHandler() {
    mediaItem.add(_items[_currentItemIndex]);
    _reinitController();
  }

  // In this simple example, we handle only 4 actions: play, pause, seek and
  // stop. Any button press from the Flutter UI, notification, lock screen or
  // headset will be routed through to these 4 methods so that you can handle
  // your audio playback logic in one place.

  @override
  Future<void> play() => _controller!.play();

  @override
  Future<void> pause() => _controller!.pause();

  @override
  Future<void> seek(Duration position) => _controller!.seekTo(position);

  @override
  Future<void> skipToNext() async {
    if (_currentItemIndex == _items.length) return;
    _currentItemIndex = _currentItemIndex + 1;
    mediaItem.add(_items[_currentItemIndex]);
    _reinitController();
  }

  @override
  Future<void> skipToPrevious() async {
    // TODO: add seekToHead
    if (_currentItemIndex == 0) return;

    _currentItemIndex = _currentItemIndex - 1;
    mediaItem.add(_items[_currentItemIndex]);
    _reinitController();
  }

  @override
  Future<void> stop() async {
    _controller?.removeListener(_broadcastState);
    await _controller?.dispose();
    _controller = null;
    _broadcastState();
  }

  void _reinitController() {
    if (_controller != null) stop();
    _controller = VideoPlayerController.network(
      _items[_currentItemIndex].id,
      videoPlayerOptions: const VideoPlayerOptions(
        mixWithOthers: true,
        observeAppLifecycle: false,
      ),
    );

    _controllerSubject.add(_controller);
    _controller?.setLooping(true);
    _controller?.initialize();
    _controller?.addListener(_broadcastState);
  }

  /// Broadcasts the current state to all clients.
  Future<void> _broadcastState() async {
    final videoControllerValue = _controller?.value;

    final AudioProcessingState processingState;
    if (videoControllerValue == null) {
      processingState = AudioProcessingState.idle;
    } else if (videoControllerValue.isBuffering) {
      processingState = AudioProcessingState.buffering;
    } else if (!videoControllerValue.isInitialized) {
      processingState = AudioProcessingState.loading;
    } else if (videoControllerValue.isInitialized) {
      processingState = AudioProcessingState.ready;
    } else if (videoControllerValue.position == videoControllerValue.duration) {
      processingState = AudioProcessingState.completed;
    } else {
      if (!videoControllerValue.hasError) {
        throw Exception('Unknown processing state');
      }
      processingState = AudioProcessingState.error;
    }
    final newState = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (videoControllerValue?.isPlaying ?? false)
          MediaControl.pause
        else
          MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      bufferedPosition: Duration.zero,
      updatePosition: videoControllerValue?.position ?? Duration.zero,
      playing: videoControllerValue?.isPlaying ?? false,
      processingState: processingState,
    );
    //TODO: возможно надо добавить проверку на равенство
    playbackState.add(newState);
  }
}

class _BumbleBeeRemoteVideo extends StatefulWidget {
  @override
  _BumbleBeeRemoteVideoState createState() => _BumbleBeeRemoteVideoState();
}

class _BumbleBeeRemoteVideoState extends State<_BumbleBeeRemoteVideo> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Text('With remote mp4'),
        StreamBuilder<VideoPlayerController?>(
          stream: _audioHandler.controllerStream,
          builder: (context, snapshot) {
            final controller = snapshot.data;
            if (controller == null) return const Text('With remote mp4');
            return AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            );
          },
        ),
        SizedBox(
          height: 100.0,
          child: StreamBuilder<bool>(
            stream: _audioHandler.playbackState
                .map((state) => state.playing)
                .distinct(),
            builder: (context, snapshot) {
              final playing = snapshot.data ?? false;

              return GestureDetector(
                onTap: (playing) ? _audioHandler.pause : _audioHandler.play,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 50),
                  reverseDuration: Duration(milliseconds: 200),
                  child: Container(
                    color: Colors.black26,
                    child: Center(
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 100.0,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
