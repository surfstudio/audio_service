// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:io';

import 'package:audio_service_example/pip/pip.dart';
import 'package:rxdart/subjects.dart';
import 'package:relation/relation.dart';

/// Интерактор для работы с pip Плагином
class PipInteractor {
  final playAction = VoidAction();
  final pauseAction = VoidAction();
  // final forwardAction = VoidAction();
  // final backAction = VoidAction();

  /// Поток с информацией о состоянии Pip режима, чтобы перестраивать экран
  final isPipModeActive = BehaviorSubject.seeded(false);

  /// Выключен ли сейчас экран или нет
  final isScreenOffState = BehaviorSubject.seeded(false);

  late final PipPlugin _pipPlugin;

  /// Включен ли сейчас автоматический переход в пип
  // bool get isAutoPipEnabled => _isAutoPipEnabled;

  /// Последняя информация о возможности режима PIP
  bool get isAvailableLast => _pipPlugin.isAvailableLast;

  /// Последняя информация о тои находится ли приложение в режиме PIP
  bool get isPipModeLast => _pipPlugin.isPipModeLast;

  /// набор кнопок, когда видео на паузе
  List<FlutterPipButton> get pauseButtons => _pipPlugin.pauseButtons;

  /// набор кнопок, когда видео запущено
  List<FlutterPipButton> get playButtons => _pipPlugin.playButtons;

  StreamSubscription? _pipModeSubscription;
  // bool _isAutoPipEnabled = false;

  PipInteractor() {
    _pipPlugin = PipPlugin(
        playAction,
        pauseAction,
        // forwardAction,
        // backAction,
        );
    _pipModeSubscription = _pipPlugin.pipModeState.stream.distinct().listen(
      (isEnabled) {
        if (isPipModeActive.value != isEnabled) {
          isPipModeActive.add(isEnabled);
        }
      },
    );

    Timer.periodic(const Duration(seconds: 1), (_) async {
      final isLocked = await _pipPlugin.isScreenLocked;
      if (isScreenOffState.value != isLocked) {
        isScreenOffState.add(isLocked);
      }
    });
  }

  /// Когда приложение в режиме картинка в картинке,
  /// сворачивает приложение до конца
  Future<void> closePip() => _pipPlugin.closePip();

  void dispose() {
    _pipModeSubscription?.cancel();
  }

  /// Активен ли текущий плеер, только для IOS
  Future<bool> isCurrentPlayerActive() => _pipPlugin.isCurrentPlayerActive();

  /// Закрывает и очищает pip, только для IOS
  Future<void> prepareForClean() => _pipPlugin.prepareForClean();

  /// Отключить/включить автоматический переход в режим картинка в картинке при сворачивании
  /// картинки. Для Включения PIP на IOS нужно передавать [textureId].
  /// Для аналитики нужно посчитать процент просмотра от продолжительности всего видео [totalDuration].
  Future<void> setAutoPipModeEnable({
    required bool isEnabled,
    int? textureId,
  }) {
    if (isEnabled && Platform.isIOS && textureId == null) {
      throw Exception('Define textureId to enable PIP on IOS');
    }

    return _pipPlugin.setAutoPipModeEnable(
      isEnabled,
      textureId: textureId,
    );
  }

  /// Указать какие кнопки необходимо отображать
  Future<void> setPipActions(List<FlutterPipButton> actions) =>
      _pipPlugin.setPipActions(actions);

  Future<void> startPipMode(int textureId) {
    return _pipPlugin.startPipMode(textureId);
  }
}
