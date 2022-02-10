// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_example/custom_audio_handler.dart';
import 'package:audio_service_example/pip/pip_interactor.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// You might want to provide this using dependency injection rather than a
// global variable.
late VideoPlayerHandler _audioHandler;
late PipInteractor _pipInteractor;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _pipInteractor = PipInteractor();

  _audioHandler = await AudioService.init(
    builder: () => VideoPlayerHandler(_pipInteractor),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidStopForegroundOnPause: true,
    ),
  );

  AudioSession.instance.then((session) {
    session.configure(const AudioSessionConfiguration.music());
  });

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: const TextTheme(
          button: TextStyle(
            fontSize: 20,
            height: 2,
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Service Demo'),
        ),
        body: BumbleBeeRemoteVideo(),
      ),
    );
  }
}

class BumbleBeeRemoteVideo extends StatefulWidget {
  @override
  State<BumbleBeeRemoteVideo> createState() => _BumbleBeeRemoteVideoState();
}

class _BumbleBeeRemoteVideoState extends State<BumbleBeeRemoteVideo> {
  double _currentRate = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        StreamBuilder<VideoPlayerController?>(
          stream: _audioHandler.controllerStream,
          builder: (context, snapshot) {
            final controller = snapshot.data;
            if (controller == null) return const Text('controller == null');
            return SizedBox(
              height: 100,
              width: 200,
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => _audioHandler.play(),
              child: const Text('play'),
            ),
            TextButton(
              onPressed: () => _audioHandler.pause(),
              child: const Text('pause'),
            ),
          ],
        ),
        Slider(
          min: 0,
          max: 2,
          value: _currentRate,
          onChanged: (rate) => setState(() => _currentRate = rate),
          onChangeEnd: (rate) =>
              _audioHandler.controllerStream.value?.setPlaybackSpeed(rate),
        ),
        StreamBuilder(
          stream: _audioHandler.rateSubject.stream,
          builder: (_, data) {
            return Text("rate from videoPlayer: ${data.data}");
          },
        ),
      ],
    );
  }
}
