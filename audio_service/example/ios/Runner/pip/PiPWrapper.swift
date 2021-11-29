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

final class PiPWrapper: PiPWrapperProtocol {

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

    // MARK: - PiPWrapperProtocol

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

}

// MARK: - InterruptionNotificationServiceDelegate

extension PiPWrapper: InterruptionNotificationServiceDelegate {

    func interruptionEventDidTriggered(_ reason: InterruptionReasons) {
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

}

// MARK: - Private Methods

private extension PiPWrapper {

    func isPaused() -> Bool {
        let player = SwiftFlutterPipPlugin.playerLayer?.player
        if #available(iOS 10.0, *), player?.timeControlStatus == .paused {
            return true
        }
        if player?.rate == .zero, player?.status == .readyToPlay {
            return true
        }
        return false
    }

    func isPlaying() -> Bool {
        return SwiftFlutterPipPlugin.playerLayer?.player?.rate == 1.0
    }

    func resumePauseIfScreenLocked() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            if self.screenLockState == .locked, self.isPaused(), self.playingPiP {
                self.playPlayer()
            }
            self.configureStates()
        }
    }

    func configureStates() {
        if isPaused(), !playingSessionOpen {
            setPauseState()
        }
        if isPlaying(), playingSessionOpen {
            setPlayingState()
        }
    }

    func configureActions() {
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

    func updatePlayingStateFLTVideoPlayer() {
        if playingPiP {
            sendMessagePlay?()
            playerCenter.updateTargets(state: .play)
        } else {
            sendMessagePause?()
            playerCenter.updateTargets(state: .pause)
        }
    }

    /// Работают при нажатии на контролы в режиме PiP и при закрытии его
    func playPlayer() {
        SwiftFlutterPipPlugin.playerLayer?.player?.play()
        setPlayingState()
    }

    func pausePlayer() {
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
