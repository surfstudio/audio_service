//
//  File.swift
//  Runner
//
//  Created by porohov on 28.11.2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import Foundation
import AVFoundation

typealias EmptyBlock = () -> Void

final class PiPWrapper: InterruptionNotificationServiceDelegate {

    // MARK: - ScreenLockState

    private enum ScreenLockState {
        case locked
        case unlocked
    }

    // MARK: - Nested types

    private enum Constants {
        /// - Need for use legacy rate change notification, this trigger after lockscreen event
        static let delayBetweenScreenlockAndRateChange: TimeInterval = 0.2
    }

    // MARK: - Initialization

    init() {
        interruptionNotificationService.delegate = self
    }

    // MARK: - Public Properties

    public var sendMessagePlay: EmptyBlock?
    public var sendMessagePause: EmptyBlock?

    // MARK: - Private Properties

    private var playingPiP: Bool = true
    private let interruptionNotificationService = InterruptionNotificationService()
    private var screenLockState: ScreenLockState = .unlocked
    private let playerCenter: PlayerCenterProtocol = PlayerCenter()
    private var playingSessionOpen = false

    // MARK: - Public Methods

    func pictureInPictureControllerDidStopPictureInPicture() {
        playerCenter.discardIsEnabledControllsState()
        updatePlayingStateFLTVideoPlayer()
    }

    func pictureInPictureControllerWillStartPictureInPicture(player: AVPlayer?) {
        playerCenter.setupControlOnMediaCenter(isEnable: true)
        configureActions()
        interruptionNotificationService.subscribeOnLegacyRateNotification(player: player)
        updatePlayingStateFLTVideoPlayer()
    }

    func unsubscribeFromAllNotifications() {
        interruptionNotificationService.unsubscribeFromAllNotifications()
    }

    func subscribeOnAllnotifications() {
        interruptionNotificationService.subscribeOnAllnotifications()
    }

    // MARK: - InterruptionNotificationServiceDelegate

    func interruptionEventDidTriggered(_ reason: InterruptionReasons) {
        switch UIApplication.shared.applicationState {
        case .active:
            print("App is active")
        case .inactive:
            print("App inactive")
        case .background:
            print("App background")
        }
        switch reason {
        case .rateDidChange:
            /// - TODO: - Need check on available content if this ended and not repeatable
            resumePauseIfScreenLocked()
        case .screenDidLocked:
            screenLockState = .locked
            if let isPiPActive = SwiftFlutterPipPlugin.fltPlayer?.isPipActive,
               !isPiPActive {
                configureStates()
            }
        case .screenDidUnlocked:
            screenLockState = .unlocked
        case .system:
            break
        }
    }

    // MARK: - Private Methods

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

    private func isPlaying() -> Bool {
        return SwiftFlutterPipPlugin.playerLayer?.player?.rate == 1.0
    }

    private func resumePauseIfScreenLocked() {
        guard isPaused() else {
            configureStates()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
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
        if isPaused(), !playingSessionOpen {
            setPauseState()
        }
        if isPlaying(), playingSessionOpen {
            setPlayingState()
        }
    }

    private func configureActions() {
        playerCenter.onTogglePlayPause = { [weak self] in
            (self?.isPaused() ?? true) ? self?.playPlayer() : self?.pausePlayer()
        }
        playerCenter.onPlay = { [weak self] in
            self?.playPlayer()
        }
        playerCenter.onPause = { [weak self] in
            self?.pausePlayer()
        }
    }

    private func updatePlayingStateFLTVideoPlayer() {
        if playingPiP {
            sendMessagePlay?()
            playerCenter.updateTargets(state: .play)
        } else {
            sendMessagePause?()
            playerCenter.updateTargets(state: .pause)
        }
    }

    /// Работают при нажатии на контролы в режиме PiP и при закрытии его
    private func playPlayer() {
        SwiftFlutterPipPlugin.playerLayer?.player?.play()
        setPlayingState()
    }

    private func pausePlayer() {
        SwiftFlutterPipPlugin.playerLayer?.player?.pause()
        setPauseState()
    }

    func setPlayingState() {
        playingPiP = true
        playingSessionOpen = false
        updatePlayingStateFLTVideoPlayer()
    }

    func setPauseState() {
        playingPiP = false
        playingSessionOpen = true
        updatePlayingStateFLTVideoPlayer()
    }

}
