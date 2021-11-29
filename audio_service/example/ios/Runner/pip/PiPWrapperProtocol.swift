//
//  PiPWrapperProtocol.swift
//  Runner
//
//  Created by porohov on 29.11.2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import AVFoundation

protocol PiPWrapperProtocol {
    func pictureInPictureControllerDidStopPictureInPicture()
    func pictureInPictureControllerWillStartPictureInPicture(player: AVPlayer?)
    func unsubscribeFromAllNotifications()
    func subscribeOnAllnotifications() 
}
