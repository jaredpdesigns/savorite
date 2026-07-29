//
//  DebugCommands.swift
//  Savorite
//

import SwiftUI

struct DebugCommands: Commands {
    @FocusedValue(\.musicManager) private var musicManager
    
    var body: some Commands {
        CommandMenu("Debug") {
            Button("Clear Cache") {
                musicManager?.debugClearCache()
            }
            .disabled(musicManager == nil)
            .keyboardShortcut("k", modifiers: [.command, .option])
            
            Button("Reset Authorization") {
                musicManager?.debugResetAuthorization()
            }
            .disabled(musicManager == nil)
            .keyboardShortcut("r", modifiers: [.command, .option])
            
            Divider()
            
            Button(musicManager?.isArtworkHidden == true ? "Show Artwork" : "Hide Artwork") {
                musicManager?.debugToggleArtworkVisibility()
            }
            .disabled(musicManager == nil)
        }
    }
}
