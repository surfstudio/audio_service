//
//  PlayerCenter.swift
//  Runner
//
//  Created by Илья Князьков on 15.11.2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import MediaPlayer

final class PlayerCenter: PlayerCenterProtocol {

    // MARK: - Private properties

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var playCommandIsEnabledInPreviousState = false
    private var pauseCommandIsEnabledInPreviousState = false
    private var playPauseCommandIsEnabledInPreviousState = false

    // MARK: - Internal properties

    var player: AVPlayer?
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?

    // MARK: - Internal methods

    func setupMetaDataOnPlayer(_ metaData: ContentMetaData) {
        infoCenter.nowPlayingInfo = metaData.rawMetaFields
        if #available(iOS 13.0, *) {
            infoCenter.playbackState = .playing
        }
    }

    func setupControlOnMediaCenter(isEnable: Bool) {
        playCommandIsEnabledInPreviousState = commandCenter.playCommand.isEnabled
        pauseCommandIsEnabledInPreviousState = commandCenter.pauseCommand.isEnabled
        playPauseCommandIsEnabledInPreviousState = commandCenter.togglePlayPauseCommand.isEnabled

        commandCenter.playCommand.isEnabled = isEnable
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.player?.play()
            self?.onPlay?()
            return .success
        }
        commandCenter.pauseCommand.isEnabled = isEnable
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.player?.pause()
            self?.onPause?()
            return .success
        }
        commandCenter.togglePlayPauseCommand.isEnabled = isEnable
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onTogglePlayPause?()
            return .success
        }
    }

    func discardIsEnabledControllsState() {
        commandCenter.playCommand.isEnabled = playCommandIsEnabledInPreviousState
        commandCenter.pauseCommand.isEnabled = pauseCommandIsEnabledInPreviousState
        commandCenter.togglePlayPauseCommand.isEnabled = playPauseCommandIsEnabledInPreviousState
    }

}
