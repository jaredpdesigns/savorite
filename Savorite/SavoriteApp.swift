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
    init() {
        // Configure a larger disk cache for album artwork
        // 100MB memory, 500MB disk
        let cache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            diskPath: "artwork_cache"
        )
        URLCache.shared = cache
        
        // Remove unwanted menu bar items
        DispatchQueue.main.async {
            NSApplication.shared.mainMenu?.items.removeAll { item in
                let title = item.title
                return title == "File" || title == "Edit" || title == "View" || title == "Window" || title == "Help"
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
