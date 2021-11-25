import UIKit
import Flutter
import AVKit
import video_player

// Название канала
let channelName = "the.pip.pip"

// Методы
let isAvailableMethod = "isPipAvailable"
let startPipModeMethod = "startPipMode"
let pipModeStateChangedMethod = "pipModeStateChanged"
let changeAutoPipModeStateMethod = "changeAutoPipModeState"
let closePipMethod = "closePip"
let removePlayerFromLayer = "removePlayerFromLayer"
let isCurrentPlayerPlayingMethod = "isCurrentPlayerPlaying"
let isScreenLockedMethod = "isScreenLocked"

let playPressed = "play";
let pausePressed = "pause";

// Аргументы
let textureIdArg = "textureId"
let isAutoPipEnabledArg = "isAutoPipEnabled"
let isPipModeActiveArg = "isPipModeActiveArgument"

public class SwiftFlutterPipPlugin: NSObject, FlutterPlugin,
    AVPictureInPictureControllerDelegate, UIApplicationDelegate {

    // MARK: - Nested types

    private enum Constants {
        /// - Need for use legacy rate change notification, this trigger after lockscreen event
        static let delayBetweenScreenlockAndRateChange: TimeInterval = 0.2
    }

    private enum ScreenLockState {
        case locked
        case unlocked
    }

    // MARK: - Internal properties

    let channel: FlutterMethodChannel
    static var isAutoPip = false
    
    static var fltPlayer: FLTVideoPlayer?
    static var newPlayer: AVPlayer?
    static var playerLayer: AVPlayerLayer?
    static var pictureInPictureController: AVPictureInPictureController?

    // MARK: - Private properties

    private var playingPiP: Bool = true
    private static let interruptionNotificationService = InterruptionNotificationService()
    private var screenLockState: ScreenLockState = .unlocked
    private static let playerCenter: PlayerCenterProtocol = PlayerCenter()
    private var playingSessionOpen = false

    // MARK: - Public initialization
    
    public init(_ newChannel: FlutterMethodChannel) {
        channel = newChannel
        super.init()
        SwiftFlutterPipPlugin.interruptionNotificationService.delegate = self
    }

    // MARK: - Public methods
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterPipPlugin(channel)
        registrar.addApplicationDelegate(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try audioSession.setMode(AVAudioSessionModeMoviePlayback)
            try audioSession.setActive(true)
        } catch  {
            print("Audio session failed")
        }
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        SwiftFlutterPipPlugin.fltPlayer?.isPipActive = false
        channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: false])
        SwiftFlutterPipPlugin.playerCenter.discardIsEnabledControllsState()
        SwiftFlutterPipPlugin.interruptionNotificationService.unsubscribeOnLegacyRateNotification()
    }
    
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        SwiftFlutterPipPlugin.fltPlayer?.isPipActive = true
        channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: true])
        SwiftFlutterPipPlugin.playerCenter.setupControlOnMediaCenter(isEnable: true)
        configureActions()
        SwiftFlutterPipPlugin
            .interruptionNotificationService
            .subscribeOnLegacyRateNotification(player: SwiftFlutterPipPlugin.playerLayer?.player)
    }
    
    public func picture(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method{
        case isAvailableMethod:
            result(isAvailable())
            break
        case startPipModeMethod:
            SwiftFlutterPipPlugin.startPipMode(call)
            break
        case changeAutoPipModeStateMethod:
            setAutoPipMode(call)
            break
        case closePipMethod:
            closePip()
            break
        case isScreenLockedMethod:
            result(UIScreen.main.brightness == 0.0)
            break
        case removePlayerFromLayer:
            clearPlayer()
        case isCurrentPlayerPlayingMethod:
            result(isCurrentPlayerPlaying())
        default:
            result(FlutterMethodNotImplemented)
            return
        }
    }
    
    func clearPlayer() {
        channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: false])
        pausePlayer()
        NotificationCenter.default.removeObserver(self)
        SwiftFlutterPipPlugin.interruptionNotificationService.unsubscribeFromAllNotifications()
        SwiftFlutterPipPlugin.pictureInPictureController = nil
        SwiftFlutterPipPlugin.playerLayer?.removeFromSuperlayer()
        SwiftFlutterPipPlugin.newPlayer = nil
        SwiftFlutterPipPlugin.playerLayer = nil
        SwiftFlutterPipPlugin.fltPlayer = nil
    }
    
    // Играет ли текущий плеер
    func isCurrentPlayerPlaying() -> Bool {
        let playing = SwiftFlutterPipPlugin.newPlayer?.rate != 0 && SwiftFlutterPipPlugin.newPlayer?.error == nil
        let pipModeIsActive = SwiftFlutterPipPlugin.fltPlayer?.isPipActive ?? false
        return pipModeIsActive ? playingPiP : playing
    }
    
    
    // Доступен ли режим Picture in Picture на устройстве
    func isAvailable() -> Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }
    
    // Прекратить режим картинка в картинке
    func closePip() {
        if(SwiftFlutterPipPlugin.pictureInPictureController?.isPictureInPictureActive ?? false) {

            channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: false])
            SwiftFlutterPipPlugin.pictureInPictureController?.stopPictureInPicture()
        }
    }
    
    // Разрешить/запретить автозапуск режима картинка в картинке
    func setAutoPipMode(_ call : FlutterMethodCall) {
        let textureIDOpt = getTextureID(call)
        if SwiftFlutterPipPlugin.isAutoPip {
            enablePiPMode(textureIDOpt: textureIDOpt)
        } else {
            disablePiPMode()
        }
    }
    
    // Запустить режим Picture in Picture
    static func startPipMode(_ call : FlutterMethodCall) {
        if(pictureInPictureController?.isPictureInPicturePossible ?? false && isAutoPip) {
            pictureInPictureController?.startPictureInPicture()
        }
    }
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
        SwiftFlutterPipPlugin.fltPlayer?.isPipActive = false
        SwiftFlutterPipPlugin.playerLayer?.opacity = 0
        if(SwiftFlutterPipPlugin.pictureInPictureController?.isPictureInPictureActive ?? false) {
            SwiftFlutterPipPlugin.pictureInPictureController?.stopPictureInPicture()
        }
    }
    
    public func applicationWillEnterForeground(_ application: UIApplication) {
        if(SwiftFlutterPipPlugin.pictureInPictureController?.isPictureInPictureActive ?? false) {
            SwiftFlutterPipPlugin.pictureInPictureController?.stopPictureInPicture()
        }
    }

    // MARK: - Private methods
    
    @objc
    private func didChangeScreenRecordingStatus(note : NSNotification) {
        SwiftFlutterPipPlugin.fltPlayer?.isPipActive = false
        channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: false])
        SwiftFlutterPipPlugin.fltPlayer?.isPipActive = false
        SwiftFlutterPipPlugin.fltPlayer?.pause()
        NotificationCenter.default.removeObserver(self)
        SwiftFlutterPipPlugin.interruptionNotificationService.unsubscribeFromAllNotifications()
        SwiftFlutterPipPlugin.playerLayer?.removeFromSuperlayer()
        SwiftFlutterPipPlugin.pictureInPictureController = nil
        SwiftFlutterPipPlugin.playerLayer = nil
        SwiftFlutterPipPlugin.newPlayer = nil
    }

    private func disablePiPMode() {
        SwiftFlutterPipPlugin.playerLayer?.removeFromSuperlayer()
        SwiftFlutterPipPlugin.pictureInPictureController = nil
        SwiftFlutterPipPlugin.playerLayer = nil
        SwiftFlutterPipPlugin.newPlayer = nil
        SwiftFlutterPipPlugin.fltPlayer = nil
        NotificationCenter.default.removeObserver(self)
        SwiftFlutterPipPlugin.interruptionNotificationService.unsubscribeFromAllNotifications()
    }
    private func isPaused() -> Bool {
        let player = SwiftFlutterPipPlugin.playerLayer?.player
        if #available(iOS 10.0, *), player?.timeControlStatus == .paused {
            return true
        }

        if player?.rate == .zero, player?.status == .readyToPlay {
            return true
        }
        return false
    }

    private func getTextureID(_ call : FlutterMethodCall) -> Int? {
        let args = call.arguments as! NSDictionary
        let params = args as! [String: Any]
        let isAutoPipEnable = params[isAutoPipEnabledArg] as! Bool
        SwiftFlutterPipPlugin.isAutoPip = isAutoPipEnable
        return params[textureIdArg] as? Int
    }

    private func getFLTPlayer(textureIDOpt: Int?) -> AVPlayer? {
        guard let textureID = textureIDOpt else { return nil }
        let playerPluginOpt = (UIApplication.shared.delegate as! FlutterAppDelegate).valuePublished(byPlugin: "FLTVideoPlayerPlugin") as? FLTVideoPlayerPlugin
        let fltPlayer = playerPluginOpt?.players[textureID] as? FLTVideoPlayer
        SwiftFlutterPipPlugin.fltPlayer = fltPlayer
        return fltPlayer?.player
    }

    private func enablePiPMode(textureIDOpt: Int?) {
        guard SwiftFlutterPipPlugin.playerLayer == nil else { return }
        SwiftFlutterPipPlugin.interruptionNotificationService.subscribeOnAllnotifications()
        if let player = getFLTPlayer(textureIDOpt: textureIDOpt), AVPictureInPictureController.isPictureInPictureSupported() {
            SwiftFlutterPipPlugin.fltPlayer?.isPipActive = SwiftFlutterPipPlugin.pictureInPictureController?.isPictureInPictureActive ?? false
            
            NotificationCenter.default.removeObserver(self)
            
            SwiftFlutterPipPlugin.newPlayer? = player
            SwiftFlutterPipPlugin.newPlayer?.actionAtItemEnd = .pause
            
            SwiftFlutterPipPlugin.playerLayer = AVPlayerLayer(player: player)
            SwiftFlutterPipPlugin.playerLayer?.contentsGravity = "top"
            SwiftFlutterPipPlugin.playerLayer?.bounds = UIScreen.main.bounds
            SwiftFlutterPipPlugin.playerLayer?.position = CGPoint.init(x: UIScreen.main.bounds.width / 2, y: SwiftFlutterPipPlugin.playerLayer!.videoRect.height / 2 + UIApplication.shared.statusBarFrame.height)
            let appDelegate = (UIApplication.shared.delegate as! FlutterAppDelegate)
            appDelegate.window.rootViewController?.view.layer.insertSublayer(SwiftFlutterPipPlugin.playerLayer!, at: 0)
            appDelegate.window.rootViewController?.view.layer.sublayers?.first?.opacity = 0
            
            SwiftFlutterPipPlugin.pictureInPictureController = AVPictureInPictureController(playerLayer: SwiftFlutterPipPlugin.playerLayer!)
            SwiftFlutterPipPlugin.pictureInPictureController?.delegate = self
            
            if #available(iOS 11.0, *) {
                NotificationCenter.default.addObserver(self, selector: #selector(didChangeScreenRecordingStatus), name: NSNotification.Name.UIScreenCapturedDidChange, object: nil)
            }
        }
    }

}

// MARK: - PauseDetectServiceDelegate

extension SwiftFlutterPipPlugin: InterruptionNotificationServiceDelegate {

    func interruptionEventDidTriggered(_ reason: InterruptionReasons) {
        switch reason {
        case .rateDidChange:
            /// - TODO: - Need check on available content if this ended and not repeatable
            resumePauseIfScreenLocked()
        case .screenDidLocked:
            screenLockState = .locked
        case .screenDidUnlocked:
            screenLockState = .unlocked
        case .system:
            break
        }
    }

    private func resumePauseIfScreenLocked() {
        guard SwiftFlutterPipPlugin.playerLayer?.player?.rate == .zero else {
            configureStates()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Constants.delayBetweenScreenlockAndRateChange) { [weak self] in
            guard let self = self else {
                return
            }
            switch self.screenLockState {
            case .locked where self.playingPiP:
                self.playPlayer()
            case .unlocked:
                break
            default:
                break
            }
            self.configureStates()
        }
    }

    private func configureStates() {
        confugurePausedState()
        configurePlayingState()
    }

    private func confugurePausedState() {
        guard SwiftFlutterPipPlugin.playerLayer?.player?.rate == .zero, isPaused(), !playingSessionOpen else {
            return
        }
        playingPiP = false
        playingSessionOpen = true
        updatePlayingStateFLTVideoPlayer()
    }

    private func configurePlayingState() {
        guard SwiftFlutterPipPlugin.playerLayer?.player?.rate == 1.0, playingSessionOpen else {
            return
        }
        playingPiP = true
        playingSessionOpen = false
        updatePlayingStateFLTVideoPlayer()
    }

    private func configureActions() {
        SwiftFlutterPipPlugin.playerCenter.onTogglePlayPause = { [weak self] in
            (self?.isPaused() ?? true) ? self?.playPlayer() : self?.pausePlayer()
        }
        SwiftFlutterPipPlugin.playerCenter.onPlay = { [weak self] in
            self?.playPlayer()
        }
        SwiftFlutterPipPlugin.playerCenter.onPause = { [weak self] in
            self?.pausePlayer()
        }
    }

    private func updatePlayingStateFLTVideoPlayer() {
        guard let isPipActive = SwiftFlutterPipPlugin.fltPlayer?.isPipActive,
              isPipActive == true else { return }
        if playingPiP {
            channel.invokeMethod(playPressed, arguments: [])
            SwiftFlutterPipPlugin.playerCenter.updateTargets(state: .play)
        } else {
            channel.invokeMethod(pausePressed, arguments: [])
            SwiftFlutterPipPlugin.playerCenter.updateTargets(state: .pause)
        }
    }

    private func playPlayer() {
        SwiftFlutterPipPlugin.playerLayer?.player?.play()
        playingPiP = true
        playingSessionOpen = false
        updatePlayingStateFLTVideoPlayer()
    }

    private func pausePlayer() {
        SwiftFlutterPipPlugin.playerLayer?.player?.pause()
        playingPiP = false
        playingSessionOpen = true
        updatePlayingStateFLTVideoPlayer()
    }

}
