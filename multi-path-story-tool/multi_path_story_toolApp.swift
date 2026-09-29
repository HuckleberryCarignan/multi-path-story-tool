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
    @State private var vm = StoryViewModel()

    init() {
        Logger().log("DEBUG_APP_LAUNCHED")
        // Reduce the system tooltip appearance delay from ~1 s to 300 ms app-wide.
        UserDefaults.standard.set(300, forKey: "NSInitialToolTipDelay")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
        }
        .commands {
            // Registered here (rather than only as a button inside the toolbar's
            // File Menu) so ⌘O is a real app menu command and reliably fires
            // from the moment the app launches.
            CommandGroup(after: .newItem) {
                Button("Open Story...") {
                    vm.openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
