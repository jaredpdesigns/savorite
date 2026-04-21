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
        /*
         Memory-only cache for album artwork loaded via AsyncImage.
         Artwork URLs always point to Apple's CDN so local copies
         are purely a scrolling convenience -- no reason to persist
         them to disk across sessions.
         */
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 0,
            diskPath: nil
        )
        URLCache.shared = cache
        
        CacheCleanup.removeOrphanedTempFiles()
        CacheCleanup.removeStaleDiskCaches()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum CacheCleanup {
    /*
     AsyncImage / CFNetwork writes response bodies to temp files before
     committing them to URLCache. In sandboxed apps these files are
     frequently orphaned and never cleaned up, growing unbounded.
     */
    static func removeOrphanedTempFiles() {
        let fm = FileManager.default
        guard let tmpURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .deletingLastPathComponent()
            .appendingPathComponent("tmp") as URL? else { return }
        
        guard let contents = try? fm.contentsOfDirectory(
            at: tmpURL,
            includingPropertiesForKeys: nil
        ) else { return }
        
        for file in contents where file.lastPathComponent.hasPrefix("CFNetworkDownload_") {
            try? fm.removeItem(at: file)
        }
    }
    
    /*
     Previous versions wrote disk-backed URLCaches to two locations.
     Now that the cache is memory-only, remove both on launch so
     existing installs reclaim the space.
     */
    static func removeStaleDiskCaches() {
        let fm = FileManager.default
        guard let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        
        let bundleId = Bundle.main.bundleIdentifier ?? "com.jaredpdesigns.Savorite"
        let stalePaths = [
            cachesDir.appendingPathComponent(bundleId),
            cachesDir.deletingLastPathComponent().appendingPathComponent("artwork_cache")
        ]
        
        for path in stalePaths where fm.fileExists(atPath: path.path) {
            try? fm.removeItem(at: path)
        }
    }
    
    /* Clear the artwork URLCache and temp files after a sync completes. */
    static func clearAfterSync() {
        URLCache.shared.removeAllCachedResponses()
        removeOrphanedTempFiles()
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
