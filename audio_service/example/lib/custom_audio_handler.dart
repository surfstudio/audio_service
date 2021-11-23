// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_example/pip/pip_interactor.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';

/// An [AudioHandler] for playing a single item.
class VideoPlayerHandler extends BaseAudioHandler with QueueHandler {
  static final _item = MediaItem(
    id: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    album: "Bee",
    title: "Bee",
    artist: "Bee",
    duration: const Duration(milliseconds: 4000),
    artUri: Uri.parse(
        'https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
  );

  bool _isStopped = false;

  VideoPlayerController? _controller;
  final BehaviorSubject<VideoPlayerController?> _controllerSubject =
      BehaviorSubject.seeded(null);

  ValueStream<VideoPlayerController?> get controllerStream =>
      _controllerSubject.stream;

  final PipInteractor pipInteractor;

  VideoPlayerHandler(this.pipInteractor) {
    _reinitController();

    Timer.periodic(const Duration(seconds: 1), (_) async {
      final isTrylyPlaying = await pipInteractor.isCurrentPlayerActive();

      final newState = playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isTrylyPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
      );

      playbackState.add(newState);
    });
  }

  @override
  Future<void> play() => _controller!.play();

  @override
  Future<void> pause() => _controller!.pause();

  @override
  Future<void> stop() async {
    _isStopped = true;
    _controller?.pause();
    // super.stop();
    addEmptyState();
    _controller?.removeListener(_broadcastState);
  }

  void addEmptyState() {
    final newState = PlaybackState(
      playing: false,
      processingState: AudioProcessingState.idle,
    );

    playbackState.add(newState);
  }

  Future<void> _reinitController() async {
    final previousController = _controller;
    previousController?.removeListener(_broadcastState);
    previousController?.pause();
    mediaItem.add(_item);
    _controller = VideoPlayerController.network(
      _item.id,
      videoPlayerOptions: const VideoPlayerOptions(
        mixWithOthers: true,
        observeAppLifecycle: false,
      ),
    );

    _controllerSubject.add(_controller);
    _controller?.setLooping(true);
    _controller?.initialize();
    _controller?.addListener(_broadcastState);
    _controller?.play();
    playbackState.add(playbackState.value.copyWith(
      updatePosition: Duration.zero,
    ));

    Future<void>.delayed(
      const Duration(milliseconds: 100),
      () => previousController?.dispose(),
    );
  }

  Future<void> _broadcastState() async {
    final videoControllerValue = _controller?.value;

    if (videoControllerValue?.isPlaying ?? false) _isStopped = false;
    if (_isStopped) return;

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

    playbackState.add(newState);
  }
}
