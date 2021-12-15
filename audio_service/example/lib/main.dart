// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
          title: const Text('Video Service Demo'),
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
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();

    _reinitController();
  }

  Future<void> _reinitController() async {
    final previousController = _controller;

    previousController?.pause();

    _controller = VideoPlayerController.network(
      'https://0c6d038a-3309-416c-8331-7a5a3be3ce8b.selcdn.net/media/videos/57d64ee9-fe94-403c-b688-8c7841b392a3/master.m3u8',
      videoPlayerOptions: const VideoPlayerOptions(
        mixWithOthers: true,
        observeAppLifecycle: false,
      ),
    );

    _controller?.setLooping(true);
    _controller?.initialize();
    _controller?.play();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Column(
      children: <Widget>[
        if (controller == null)
          const Text('controller == null')
        else
          SizedBox(
            height: 100,
            width: 200,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () {
                _controller?.play();
              },
              child: const Text('play'),
            ),
            TextButton(
              onPressed: () {
                _controller?.pause();
              },
              child: const Text('pause'),
            ),
          ],
        ),
        TextButton(
          onPressed: () => setState(() {
            _reinitController();
          }),
          child: const Text('reinitController'),
        )
      ],
    );
  }
}
