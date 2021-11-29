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

    // MARK: - Internal properties

    let channel: FlutterMethodChannel
    static var isAutoPip = false
    
    static var fltPlayer: FLTVideoPlayer?
    static var newPlayer: AVPlayer?
    static var playerLayer: AVPlayerLayer?
    static var pictureInPictureController: AVPictureInPictureController?

    // MARK: - Private properties

    private var playingPiP: Bool = true
    private let pipWrapper = PiPWrapper()
    private var textureIDOpt: Int?

    // MARK: - Public initialization
    
    public init(_ newChannel: FlutterMethodChannel) {
        channel = newChannel
        super.init()
        configureActionsPiPWrapper()
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
            clearPlayerNotify()
        case isCurrentPlayerPlayingMethod:
            result(isCurrentPlayerPlaying())
        default:
            result(FlutterMethodNotImplemented)
            return
        }
    }
    
    func clearPlayerNotify() {
        channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: false])
//        pausePlayer()
        SwiftFlutterPipPlugin.fltPlayer = nil
        removePiPPlayer()
    }
    
    // Играет ли текущий плеер
    func isCurrentPlayerPlaying() -> Bool {
        let isPlaying = SwiftFlutterPipPlugin.playerLayer?.player?.rate == 1.0
        && SwiftFlutterPipPlugin.playerLayer?.player?.error == nil
        return isPlaying
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
        let args = call.arguments as! NSDictionary
        let params = args as! [String: Any]
        let isAutoPipEnable = params[isAutoPipEnabledArg] as! Bool
        SwiftFlutterPipPlugin.isAutoPip = isAutoPipEnable
        textureIDOpt = params[textureIdArg] as? Int
        if SwiftFlutterPipPlugin.isAutoPip {
            enablePiPMode(textureIDOpt: textureIDOpt)
            pipWrapper.pictureInPictureControllerWillStartPictureInPicture(player: SwiftFlutterPipPlugin.playerLayer?.player)
        } else {
            SwiftFlutterPipPlugin.fltPlayer = nil
            removePiPPlayer()
        }
    }
    
    // Запустить режим Picture in Picture
    static func startPipMode(_ call : FlutterMethodCall) {
        if(pictureInPictureController?.isPictureInPicturePossible ?? false && isAutoPip) {
            pictureInPictureController?.startPictureInPicture()
        }
    }

    // MARK: - AVPictureInPictureControllerDelegate

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        SwiftFlutterPipPlugin.fltPlayer?.isPipActive = false
        channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: false])
        pipWrapper.pictureInPictureControllerDidStopPictureInPicture()
    }
    
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        SwiftFlutterPipPlugin.fltPlayer?.isPipActive = true
        channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: true])
    }
    
    public func picture(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    // MARK: - UIApplicationDelegate

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
        channel.invokeMethod(pipModeStateChangedMethod, arguments: [isPipModeActiveArg: false])
        SwiftFlutterPipPlugin.fltPlayer?.isPipActive = false
        SwiftFlutterPipPlugin.fltPlayer?.pause()
        removePiPPlayer()
    }

    private func removePiPPlayer() {
        SwiftFlutterPipPlugin.playerLayer?.removeFromSuperlayer()
        SwiftFlutterPipPlugin.pictureInPictureController = nil
        SwiftFlutterPipPlugin.playerLayer = nil
        SwiftFlutterPipPlugin.newPlayer = nil
        NotificationCenter.default.removeObserver(self)
        pipWrapper.unsubscribeFromAllNotifications()
    }

    private func getFLTPlayer(textureIDOpt: Int?) -> AVPlayer? {
        guard let textureID = textureIDOpt else { return nil }
        let playerPluginOpt = (UIApplication.shared.delegate as! FlutterAppDelegate).valuePublished(byPlugin: "FLTVideoPlayerPlugin") as? FLTVideoPlayerPlugin
        let fltPlayer = playerPluginOpt?.players[textureID] as? FLTVideoPlayer
        SwiftFlutterPipPlugin.fltPlayer = fltPlayer
        return fltPlayer?.player
    }

    private func enablePiPMode(textureIDOpt: Int?) {
        guard SwiftFlutterPipPlugin.playerLayer == nil else {
            return
        }
        pipWrapper.subscribeOnAllnotifications()
        if let player = getFLTPlayer(textureIDOpt: textureIDOpt), isAvailable() {
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

    // Отправка сообщения play/pause из PiP 
    func configureActionsPiPWrapper() {
        pipWrapper.sendMessagePlay = { [weak self] in
            self?.channel.invokeMethod(playPressed, arguments: [])
        }
        pipWrapper.sendMessagePause = { [weak self] in
            self?.channel.invokeMethod(pausePressed, arguments: [])
        }
    }

}
