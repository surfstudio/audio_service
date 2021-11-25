//
//  InterruptionNotificationService.swift
//  Runner
//
//  Created by Илья Князьков on 26.10.2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import class UIKit.UIApplication
import AVKit
import Foundation

final class InterruptionNotificationService: NSObject {

    // MARK: - Nested types

    private enum Constants {
        static let rateKey = "rate"
    }

    enum SubscriptionType {
        case rateDidChange
        case screenLock
        case screenUnlock
        case system
    }

    // MARK: - Internal properties

    weak var delegate: InterruptionNotificationServiceDelegate?

    // MARK: - Private properties

    private let eventCenter = NotificationCenter.default
    private var lastPauseReasonState: InterruptionReasons = .rateDidChange
    private var player: AVPlayer?
    private var isUseLegacyMethodRateDetection: Bool {
        switch DeviceModel.detect() {
        case .iPhone6S, .iPhone6SPlus, .iPhone7, .iPhone7_2, .iPhone7Plus, .iPhone7Plus_2, .iPhoneSE:
            return true
        default:
            return false
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        subscribeOnAllnotifications()
    }

    // MARK: - Internal methods

    func subscribeOnAllnotifications() {
        subscribeOnSystemNotifications()
        subscribeOnLegacyRateNotification(player: player)
    }

    func unsubscribeFromAllNotifications() {
        SubscriptionType.allCases.forEach(unsubscribe(from:))
        unsubscribeOnLegacyRateNotification()
    }

    /// - Need for iPhone 7 and above models
    func subscribeOnLegacyRateNotification(player: AVPlayer?) {
        self.player = player
        player?.addObserver(self, forKeyPath: Constants.rateKey, options: [], context: nil)
    }

    func unsubscribeOnLegacyRateNotification() {
        if (player?.observationInfo != nil) {
            player?.removeObserver(self, forKeyPath: Constants.rateKey)
        }
    }

    // MARK: - NSObject

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == Constants.rateKey, isUseLegacyMethodRateDetection {
            setInterruptionReasonState(state: .rateDidChange)
        }
    }

    // MARK: - Private methods

    private func subscribeOnSystemNotifications() {
        unsubscribeFromAllNotifications()
        let subscription: [SubscriptionType: Selector] = [
            .rateDidChange: #selector(rateDidChange),
            .screenLock: #selector(didEnterToLockscreen),
            .screenUnlock: #selector(didExitFromLockscreen),
            .system: #selector(systemInterrupt)
        ]
        subscription.forEach { subscription, method in
            self.subscribe(to: subscription, selector: method, object: nil)
        }
    }

    private func subscribe(to subscriptionType: SubscriptionType,
                           selector: Selector,
                           object: Any?) {
        eventCenter.addObserver(
            self,
            selector: selector,
            name: subscriptionType.notificationName,
            object: object
        )
    }

    private func unsubscribe(from subscription: SubscriptionType) {
        if (eventCenter.observationInfo != nil) {
            eventCenter.removeObserver(self, name: subscription.notificationName, object: nil)
        }
    }

}

// MARK: - Event handlers

private extension InterruptionNotificationService {

    @objc
    func rateDidChange() {
        guard !isUseLegacyMethodRateDetection else {
            return
        }
        setInterruptionReasonState(state: .rateDidChange)
    }

    @objc
    func didEnterToLockscreen() {
        setInterruptionReasonState(state: .screenDidLocked)
    }

    @objc
    func didExitFromLockscreen() {
        setInterruptionReasonState(state: .screenDidUnlocked)
    }

    @objc
    func systemInterrupt() {
        setInterruptionReasonState(state: .system)
    }

    func setInterruptionReasonState(state: InterruptionReasons) {
        lastPauseReasonState = state
        delegate?.interruptionEventDidTriggered(state)
    }

}

// MARK: - Extensions

extension InterruptionNotificationService.SubscriptionType: CaseIterable {

    var notificationName: Notification.Name {
        switch self {
        case .rateDidChange:
            let rateDidChangeNotificationKeyPath = "AVPlayerRateDidChangeNotification"
            return NSNotification.Name(rateDidChangeNotificationKeyPath)
        case .screenLock:
            return NSNotification.Name.UIApplicationProtectedDataWillBecomeUnavailable
        case .screenUnlock:
            return NSNotification.Name.UIApplicationProtectedDataDidBecomeAvailable
        case .system:
            return NSNotification.Name.AVAudioSessionInterruption
        }
    }

}
