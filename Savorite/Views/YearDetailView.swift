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
    let year: Int
    let albums: [AlbumEntry]
    @ObservedObject var musicManager: MusicManager
    let searchText: String

    @State private var showingExportSuccess = false
    @State private var showingCopySuccess = false
    @State private var exportedCount = 0
    @State private var copyFormat = ""
    @State private var lastClickedIndex: Int?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20, alignment: .top)
    ]

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

    private var includedAlbums: [AlbumEntry] {
        filteredAlbums.filter { !musicManager.isExcluded($0) }
    }

    private var includedCount: Int {
        includedAlbums.count
    }

    private var excludedCount: Int {
        filteredAlbums.filter { musicManager.isExcluded($0) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(Array(filteredAlbums.enumerated()), id: \.element.id) { index, album in
                        AlbumCard(
                            album: album,
                            isExcluded: musicManager.isExcluded(album)
                        ) { isShiftClick in
                            handleAlbumClick(index: index, album: album, isShiftClick: isShiftClick)
                        }
                    }
                }
                .padding()
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
        .navigationTitle(String(year))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        copyAsJSON()
                    } label: {
                        Label("Copy as JSON", systemImage: "doc.on.doc")
                    }

                    Button {
                        copyAsPlainText()
                    } label: {
                        Label("Copy as Plain Text", systemImage: "text.page")
                    }

                    Button {
                        copyAsMarkdown()
                    } label: {
                        Label("Copy as Markdown List", systemImage: "list.star")
                    }

                    Divider()

                    Button {
                        downloadJSON()
                    } label: {
                        Label("Download JSON", systemImage: "doc.text")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(includedCount == 0)
            }
        }
        .alert("Download Successful", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Saved \(exportedCount) albums to \(String(year)).json")
        }
        .alert("Copied to Clipboard", isPresented: $showingCopySuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Copied \(exportedCount) albums as \(copyFormat)")
        }
        .onChange(of: searchText) { _, _ in
            // Reset selection anchor when search changes to prevent stale indices
            lastClickedIndex = nil
        }
    }

    private func copyAsJSON() {
        guard let data = musicManager.exportJSON(albums: filteredAlbums),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)

        exportedCount = includedCount
        copyFormat = "JSON"
        showingCopySuccess = true
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

        exportedCount = includedAlbums.count
        copyFormat = "List"
        showingCopySuccess = true
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

        exportedCount = includedAlbums.count
        copyFormat = "Markdown"
        showingCopySuccess = true
    }

    private func downloadJSON() {
        guard let data = musicManager.exportJSON(albums: filteredAlbums) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(year).json"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                exportedCount = includedCount
                showingExportSuccess = true
            } catch {
                print("Failed to save file: \(error)")
            }
        }
    }

    private func handleAlbumClick(index: Int, album: AlbumEntry, isShiftClick: Bool) {
        if isShiftClick, let lastIndex = lastClickedIndex {
            // Range selection: select all albums between lastIndex and current index
            let startIndex = min(lastIndex, index)
            let endIndex = max(lastIndex, index)
            let albumsInRange = Array(filteredAlbums[startIndex...endIndex])

            // Determine target state based on the clicked album's current state
            let targetExcluded = !musicManager.isExcluded(album)
            musicManager.setExclusion(for: albumsInRange, excluded: targetExcluded)
        } else {
            // Single click: toggle just this album
            musicManager.toggleExclusion(for: album)
        }

        lastClickedIndex = index
    }
}
