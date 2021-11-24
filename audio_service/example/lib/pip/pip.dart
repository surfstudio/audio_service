// ignore_for_file: public_member_api_docs, unused_element

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Signature of callbacks that have no arguments and return no data.
// typedef VoidCallback = void Function();

/// Название канала
const _channelName = 'the.pip.pip';

/// Методы
const _isAvailable = 'isPipAvailable';
const _startPipMode = 'startPipMode';
const _changeAutoPipModeState = 'changeAutoPipModeState';
const _pipModeStateChangedMethod = 'pipModeStateChanged';
const _setActions = 'setActions';
const _closePip = 'closePip';
const _isScreenLockedMethod = 'isScreenLocked';

// только IOS
const _prepareForCleanPlayerLayer = 'removePlayerFromLayer';
const _isCurrentPlayerPlaying = 'isCurrentPlayerPlaying';

const _play = 'play';
const _pause = 'pause';
const _forward = 'forward';
const _back = 'back';

/// Аргументы
const _textureId = 'textureId';
const _isAutoPipEnabled = 'isAutoPipEnabled';
const _isPipModeActiveArgument = 'isPipModeActiveArgument';
const _actions = 'actions';

/// Кнопки для отображения
enum FlutterPipButton {
  /// Воспроизвести
  play,

  /// Пауза
  pause,

  /// Перемотка вперед
  forward,

  /// Перемотка назад
  back,
}

typedef VoidCallback = void Function();

///  Проектный плагин для реализации режима Picture in Picture
class PipPlugin {
  final VoidCallback play;
  final VoidCallback pause;
  // final VoidCallback forward;
  // final VoidCallback back;

  /// Поток с данными об изменении состояния картинка в картинке
  final pipModeState = StreamController<bool>.broadcast();

  /// Канал для общения с нативной частью
  final MethodChannel _channel = const MethodChannel(_channelName);

  bool isAvailableLast = false;

  bool isPipModeLast = false;

  /// набор кнопок, когда видео на паузе
  List<FlutterPipButton> get pauseButtons => const [
        FlutterPipButton.back,
        FlutterPipButton.play,
        FlutterPipButton.forward,
      ];

  /// набор кнопок, когда видео запущено
  List<FlutterPipButton> get playButtons => const [
        FlutterPipButton.back,
        FlutterPipButton.pause,
        FlutterPipButton.forward,
      ];

  Future<bool> get isScreenLocked async =>
      await _channel.invokeMethod<bool>(_isScreenLockedMethod) ?? false;

  PipPlugin(
    this.play,
    this.pause,
    // this.forward,
    // this.back,
  ) {
    isPipAvailable();

    _channel.setMethodCallHandler((call) {
      switch (call.method) {
        case _pipModeStateChangedMethod:
          _pipModeStateChanged(((call.arguments as Map<Object?, Object?>)
              .cast<String, bool>())[_isPipModeActiveArgument]!);
          break;
        case _play:
          play();
          break;
        // case _forward:
        //   forward();
        //   break;
        // case _back:
        //   back();
        //   break;
        case _pause:
          pause();
          break;
      }
      return Future<bool>.value(true);
    });
  }

  /// Когда приложение в режиме картинка в картинке,
  /// сворачивает приложение до конца
  Future<void> closePip() {
    return _channel.invokeMethod(_closePip);
  }

  void dispose() {
    pipModeState.close();
  }

  /// Активен ли текущий плеер, только для IOS
  Future<bool> isCurrentPlayerActive() async {
    if (!Platform.isIOS) throw Exception('Данный метод доступен только на IOS');
    return await _channel.invokeMethod<bool>(_isCurrentPlayerPlaying) ?? false;
  }

  /// Доступен ли режим Picture in Picture на устройстве
  Future<bool> isPipAvailable() async {
    final isAvailable =
        await _channel.invokeMethod<bool>(_isAvailable) ?? false;
    isAvailableLast = isAvailable;
    return isAvailable;
  }

  /// Закрывает и очищает pip, только для IOS
  Future<void> prepareForClean() {
    if (!Platform.isIOS) throw Exception('Данный метод доступен только на IOS');
    return _channel.invokeMethod<void>(_prepareForCleanPlayerLayer);
  }

  /// Отключить/включить автоматический переход
  /// в режим картинка в картинке при сворачивании картинки
  Future<void> setAutoPipModeEnable(
    // ignore: avoid_positional_boolean_parameters
    bool isEnable, {
    int? textureId,
  }) {
    return _channel.invokeMethod(
      _changeAutoPipModeState,
      {
        _isAutoPipEnabled: isEnable,
        _textureId: textureId,
      },
    );
  }

  /// Указать какие кнопки необходимо отображать
  Future<void> setPipActions(List<FlutterPipButton> actions) {
    ///IOS не предоставляет возможности менять UI
    if (!Platform.isAndroid) return Future<void>.value();
    return _channel.invokeMethod(
      _setActions,
      {
        _actions: actions.toIntList(),
      },
    );
  }

  /// Перейти в режим картинка в картинке
  Future<void> startPipMode(int textureId) {
    return _channel.invokeMethod(
      _startPipMode,
      {
        _textureId: textureId,
      },
    );
  }

  /// Состояние режима картинка в картинке изменилось
  void _pipModeStateChanged(bool isActive) {
    isPipModeLast = isActive;
    pipModeState.add(isActive);
  }
}

extension _FlutterPipButtonListExt on List<FlutterPipButton> {
  List<int> toIntList() {
    return map((e) {
      switch (e) {
        case FlutterPipButton.play:
          return 2;
        case FlutterPipButton.pause:
          return 4;
        case FlutterPipButton.forward:
          return 3;
        case FlutterPipButton.back:
          return 1;
        default:
          return 0;
      }
    }).toList();
  }
}
