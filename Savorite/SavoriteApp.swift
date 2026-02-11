//
//  SavoriteApp.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import AppKit
import SwiftUI

@main
struct SavoriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        /* Configure a larger disk cache for album artwork
         100MB memory, 500MB disk */
        let cache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            diskPath: "artwork_cache"
        )
        URLCache.shared = cache
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        /* Remove unwanted menu bar items */
        NSApplication.shared.mainMenu?.items.removeAll { item in
            let title = item.title
            return title == "File" || title == "Edit" || title == "View" || title == "Window" || title == "Help"
        }
    }
}
