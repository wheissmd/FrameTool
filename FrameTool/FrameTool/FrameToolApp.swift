//
//  FrameToolApp.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.
//

import SwiftUI

@main
struct FrameToolApp: App {
    init() {
            _ = QueueStore.purgeIfFirstLaunch()
        }
    var body: some Scene {
        Window("Frame Tool", id: "main") {
            ContentView()
                .frame(width: 900, height: 780)
        }
        .windowResizability(.contentSize)
    }
}
