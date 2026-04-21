//
//  YearDetailView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct YearDetailView: View {
    let title: String
    let albums: [AlbumEntry]
    let musicManager: MusicManager
    let searchText: String
    
    @State private var toastMessage: String?
    @State private var selectedView: AlbumView = .all
    
    enum AlbumView: String, CaseIterable {
        case all = "All Albums"
        case top = "Top Albums"
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20, alignment: .top)
    ]
    
    // Minimum play count threshold for "Top Albums"
    private let topAlbumsThreshold = 3
    
    // Filter albums based on search text
    private var filteredAlbums: [AlbumEntry] {
        if searchText.isEmpty {
            return albums
        }
        let lowercasedSearch = searchText.lowercased()
        return albums.filter { album in
            album.album.lowercased().contains(lowercasedSearch) ||
            album.artist.lowercased().contains(lowercasedSearch)
        }
    }
    
    // Filter for top albums (play count >= threshold)
    private var topAlbums: [AlbumEntry] {
        albums.filter { album in
            if let playCount = musicManager.playCountsByLibraryId[album.libraryId] {
                return playCount >= topAlbumsThreshold
            }
            return false
        }
    }
    
    // Determine which albums to display based on current view and search state
    private var displayedAlbums: [AlbumEntry] {
        // When searching, always show all matching albums
        if !searchText.isEmpty {
            return filteredAlbums
        }
        
        // Otherwise, respect the selected view
        switch selectedView {
        case .all:
            return albums
        case .top:
            return topAlbums
        }
    }
    
    private var includedAlbums: [AlbumEntry] {
        displayedAlbums.filter { !musicManager.isExcluded($0) }
    }
    
    private var includedCount: Int {
        includedAlbums.count
    }
    
    private var excludedCount: Int {
        displayedAlbums.filter { musicManager.isExcluded($0) }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented control (hidden when searching)
            if searchText.isEmpty {
                Picker("", selection: $selectedView) {
                    ForEach(AlbumView.allCases, id: \.self) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            
            // Show empty state if Top Albums view has no albums
            if selectedView == .top && topAlbums.isEmpty && searchText.isEmpty {
                topAlbumsEmptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                        ForEach(displayedAlbums) { album in
                            AlbumCard(
                                album: album,
                                isExcluded: musicManager.isExcluded(album),
                                playCount: musicManager.playCountsByLibraryId[album.libraryId]
                            ) {
                                musicManager.toggleExclusion(for: album)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Footer with counts
            HStack {
                if excludedCount > 0 {
                    Text("\(includedCount) favorites (\(excludedCount) hidden)")
                } else {
                    Text("\(includedCount) favorites")
                }
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityLabel(
                excludedCount > 0
                ? "\(includedCount) albums included in export, \(excludedCount) albums hidden from export"
                : "\(includedCount) favorite albums"
            )
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        copyAsJSON()
                    } label: {
                        Label("Copy as JSON", systemImage: "document.on.document.fill").font(.body)
                    }
                    
                    Button {
                        copyAsPlainText()
                    } label: {
                        Label("Copy as Plain Text", systemImage: "text.page.fill").font(.body)
                    }
                    
                    Button {
                        copyAsMarkdown()
                    } label: {
                        Label("Copy as Markdown List", systemImage: "list.star").font(.body)
                    }
                    
                    Divider()
                    
                    Button {
                        downloadJSON()
                    } label: {
                        Label("Download JSON", systemImage: "text.document.fill").font(.body)
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(includedCount == 0)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let message = toastMessage {
                Text(message)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityLabel(message)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toastMessage)
        .onChange(of: searchText) { _, _ in
            selectedView = .all
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            toastMessage = nil
        }
    }
    
    private func copyAsJSON() {
        guard let data = musicManager.exportJSON(albums: displayedAlbums),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)
        
        showToast("Copied \(includedCount) albums as JSON")
    }
    
    private func copyAsPlainText() {
        guard !includedAlbums.isEmpty else { return }
        
        let lines = includedAlbums.map { album in
            let url = album.itunesId > 0
            ? "https://music.apple.com/us/album/\(album.itunesId)"
            : ""
            return "“\(album.album)” by \(album.artist): \(url)"
        }
        
        let list = lines.joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(list, forType: .string)
        
        showToast("Copied \(includedAlbums.count) albums as plain text")
    }
    
    private func copyAsMarkdown() {
        guard !includedAlbums.isEmpty else { return }
        
        let lines = includedAlbums.map { album in
            let url = album.itunesId > 0
            ? "https://music.apple.com/us/album/\(album.itunesId)"
            : ""
            return "- “[\(album.album)](\(url))” by \(album.artist)"
        }
        
        let markdown = lines.joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
        
        showToast("Copied \(includedAlbums.count) albums as Markdown")
    }
    
    private func downloadJSON() {
        guard let data = musicManager.exportJSON(albums: displayedAlbums) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(title).json"
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                showToast("Saved \(includedCount) albums to \(title).json")
            } catch {
                // Silently fail - user will see file wasn't created
            }
        }
    }
    
    // Empty state for Top Albums view
    private var topAlbumsEmptyState: some View {
        VStack(spacing: 24) {
            Label("No Top Albums Yet", systemImage: "heart.slash.fill")
                .font(.largeTitle.bold())
            
            VStack(spacing: 12) {
                Text("Top Albums appear here when you've listened to them at least \(topAlbumsThreshold) times")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Keep listening to discover your favorites!")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
