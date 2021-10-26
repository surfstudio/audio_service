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

final class InterruptionNotificationService {

    // MARK: - Nested types

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

    // MARK: - Initialization

    init() {
        subscribeOnAllnotifications()
    }

    // MARK: - Internal methods

    func subscribeOnAllnotifications() {
        subscribeOnSystemNotifications()
    }

    func unsubscribeFromAllNotifications() {
        SubscriptionType.allCases.forEach(unsubscribe(from:))
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
        eventCenter.removeObserver(self, name: subscription.notificationName, object: nil)
    }

}

// MARK: - Event handlers

private extension InterruptionNotificationService {

    @objc
    func rateDidChange() {
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
