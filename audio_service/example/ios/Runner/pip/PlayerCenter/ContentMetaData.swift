//
//  ContentMetaData.swift
//  Runner
//
//  Created by Илья Князьков on 15.11.2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import MediaPlayer

struct ContentMetaData {

    // MARK: - Nested types

    enum MetaKeys {
        case title
        case currentTime
        case duration
        case rate
    }

    // MARK: - Private properties

    private var metaFields: [MetaKeys: Any]

    // MARK: - Internal properties

    var rawMetaFields: [String: Any] {
        Dictionary(uniqueKeysWithValues: metaFields.map(convertMetaToRaw(key:value:)))
    }

    // MARK: - Initializers

    init(metaFields: [MetaKeys: Any]) {
        self.metaFields = metaFields
    }

    // MARK: - Private methods

    private func convertMetaToRaw(key: MetaKeys, value: Any) -> (rawKey: String, rawValue: Any) {
        (rawKey: key.value, rawValue: value)
    }

}

// MARK: - Extensions

fileprivate extension ContentMetaData.MetaKeys {

    var value: String {
        switch self {
        case .title:
            return MPMediaItemPropertyTitle
        case .currentTime:
            return MPNowPlayingInfoPropertyElapsedPlaybackTime
        case .duration:
            return MPMediaItemPropertyPlaybackDuration
        case .rate:
            return MPNowPlayingInfoPropertyPlaybackRate
        }
    }

}



