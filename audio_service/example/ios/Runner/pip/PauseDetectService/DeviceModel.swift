//
//  DeviceModel.swift
//  Runner
//
//  Created by Илья Князьков on 18.11.2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import class UIKit.UIDevice

enum DeviceModel {

    // MARK: - Nested types

    enum Model: String {
        case simulator = "simulator/sandbox"
        case iPhone6S = "iPhone8,1"
        case iPhone6SPlus = "iPhone8,2"
        case iPhoneSE = "iPhone8,4"
        case iPhone7 = "iPhone9,1"
        case iPhone7_2 = "iPhone9,3"
        case iPhone7Plus = "iPhone9,2"
        case iPhone7Plus_2 = "iPhone9,4"
        case iPhone8 = "iPhone10,1"
        case iPhone8_2 = "iPhone10,4"
        case iPhone8Plus = "iPhone10,2"
        case iPhone8Plus_2 = "iPhone10,5"
        case iPhoneX = "iPhone10,3"
        case iPhoneX_2 = "iPhone10,6"
        case iPhoneXS = "iPhone11,2"
        case iPhoneXSMax = "iPhone11,4"
        case iPhoneXSMax_2 = "iPhone11,6"
        case iPhoneXR = "iPhone11,8"
        case iPhone11 = "iPhone12,1"
        case iPhone11Pro = "iPhone12,3"
        case iPhone11ProMax = "iPhone12,5"
        case iPhoneSE2 = "iPhone12,8"
        case iPhone12Mini = "iPhone13,1"
        case iPhone12 = "iPhone13,2"
        case iPhone12Pro = "iPhone13,3"
        case iPhone12ProMax = "iPhone13,4"
        case iPhone13Mini = "iPhone14,4"
        case iPhone13 = "iPhone14,5"
        case iPhone13Pro = "iPhone14,2"
        case iPhone13ProMax = "iPhone14,3"
        case unknown
    }

    // MARK: - Internal methods

    static func detect() -> Model {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        guard let mcode = modelCode,
              let mapCode = String(validatingUTF8: mcode) else {
            return .unknown
        }
        return Model(rawValue: mapCode) ?? .unknown
    }

}
