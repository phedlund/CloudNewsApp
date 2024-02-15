//
//  FeedModelEnvironment.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/25/23.
//

import SwiftUI

extension EnvironmentValues {

    var feedModel: FeedModel {
        get { self[FeedModelKey.self] }
        set { self[FeedModelKey.self] = newValue }
    }

}

private struct FeedModelKey: EnvironmentKey {
    static var defaultValue: FeedModel = FeedModel()
}
