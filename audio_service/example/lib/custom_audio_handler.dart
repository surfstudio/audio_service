// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_example/pip/pip_interactor.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';

/// An [AudioHandler] for playing a single item.
class VideoPlayerHandler extends BaseAudioHandler with QueueHandler {
  static final _item = MediaItem(
    id: 'https://webref.ru/example/video/snowman.mp4',
    album: "Bee",
    title: "Bee",
    artist: "Bee",
    duration: const Duration(milliseconds: 63000),
    artUri: Uri.parse(
        'https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
  );

  VideoPlayerController? _controller;
  final BehaviorSubject<VideoPlayerController?> _controllerSubject =
      BehaviorSubject.seeded(null);

  final BehaviorSubject<double> rateSubject = BehaviorSubject.seeded(0.0);

  ValueStream<VideoPlayerController?> get controllerStream =>
      _controllerSubject.stream;

  final PipInteractor pipInteractor;

  VideoPlayerHandler(this.pipInteractor) {
    pipInteractor.playAction.stream.listen((_) {
      if (_controller != null) {
        _controller!.play();
      }
    });

    pipInteractor.pauseAction.stream.listen((_) {
      if (_controller != null) {
        _controller!.pause();
      }
    });

    reinitController(
        'https://0c6d038a-3309-416c-8331-7a5a3be3ce8b.selcdn.net/media/videos/57d64ee9-fe94-403c-b688-8c7841b392a3/master.m3u8');
  }

  @override
  Future<void> play() async {
    final controller = _controller;
    if (controller != null) {
      await controller.play();
    }
  }

  @override
  Future<void> pause() async {
    final controller = _controller;
    if (controller != null) {
      await controller.pause();
    }
  }

  @override
  Future<void> stop() async {
    _controller?.pause();
    addEmptyState();
    _controller?.removeListener(_broadcastState);
  }

  Future<void> _activatePipMode() async {
    final currentTextureId = _controller?.textureId;

    if (pipInteractor.isAvailableLast) {
      pipInteractor.setAutoPipModeEnable(
        isEnabled: true,
        isBackgroundActive: true,
        textureId: currentTextureId,
      );
    }
  }

  void addEmptyState() {
    final newState = PlaybackState(
      playing: false,
      processingState: AudioProcessingState.idle,
    );

    playbackState.add(newState);
  }

  Future<void> reinitController(String id) async {
    final previousController = _controller;
    previousController?.removeListener(_broadcastState);
    previousController?.pause();
    mediaItem.add(_item);
    _controller = VideoPlayerController.network(
      id,
      videoPlayerOptions: const VideoPlayerOptions(
        mixWithOthers: true,
        observeAppLifecycle: false,
      ),
    );

    _controllerSubject.add(_controller);
    await _controller?.initialize();
    _controller?.addListener(_broadcastState);
    await _controller?.play();

    playbackState.add(playbackState.value.copyWith(
      updatePosition: Duration.zero,
    ));

    await _activatePipMode();

    // диспоуз закрывает пип
    Future<void>.delayed(
      const Duration(milliseconds: 10000),
      () => previousController?.dispose(),
    );
  }

  Future<void> _broadcastState() async {
    final videoControllerValue = _controller?.value;

    final isPlaying = await _playIsActive(videoControllerValue);
    if (!isPlaying) return;

    if (videoControllerValue != null) {
      rateSubject.add(videoControllerValue.playbackSpeed);
    }

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
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      bufferedPosition: Duration.zero,
      updatePosition: videoControllerValue?.position ?? Duration.zero,
      playing: isPlaying,
      processingState: processingState,
    );

    playbackState.add(newState);
  }

  /// Активен ли стэйт воспроизведения, возвращает bool
  /// Условие снижает нагрузку на async запросы
  Future<bool> _playIsActive(VideoPlayerValue? videoControllerValue) async {
    if (pipInteractor.isPipModeLast) {
      return await pipInteractor.isCurrentPlayerActive();
    } else {
      return videoControllerValue?.isPlaying ?? false;
    }
  }
}
