//
//  multi_path_story_toolApp.swift
//  multi-path-story-tool
//
//  Created by Christopher Carignan on 8/22/26.
//

import SwiftUI
import os

@main
struct multi_path_story_toolApp: App {
    init() {
        Logger().log("DEBUG_APP_LAUNCHED")
        // Reduce the system tooltip appearance delay from ~1 s to 300 ms app-wide.
        UserDefaults.standard.set(300, forKey: "NSInitialToolTipDelay")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
