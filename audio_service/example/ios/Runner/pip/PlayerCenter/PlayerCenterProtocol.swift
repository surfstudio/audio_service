//
//  PlayerCenterProtocol.swift
//  Runner
//
//  Created by Илья Князьков on 15.11.2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import class AVKit.AVPlayer

protocol PlayerCenterProtocol: AnyObject {

    var player: AVPlayer? { get set }
    var onPlay: (() -> Void)? { get set }
    var onPause: (() -> Void)? { get set }
    var onTogglePlayPause: (() -> Void)? { get set }

    func setupMetaDataOnPlayer(_ metaData: ContentMetaData)
    func setupControlOnMediaCenter(isEnable: Bool)
    func discardIsEnabledControllsState()

}
