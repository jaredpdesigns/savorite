//
//  ContentView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import MusicKit
import SwiftUI

struct ContentView: View {
    @State private var musicManager = MusicManager()
    @State private var selectedYear: Int?
    @State private var searchText: String = ""
    @State private var hasCheckedAuthorization: Bool = false
    
    // Determines if we should show the split view (sidebar + detail)
    private var shouldShowSplitView: Bool {
        // Must have checked authorization first
        guard hasCheckedAuthorization else {
            return false
        }
        
        // Must be authorized
        guard musicManager.authorizationStatus == .authorized else {
            return false
        }
        
        // Must not be loading
        guard !musicManager.isLoading else {
            return false
        }
        
        // Must have favorites
        guard !musicManager.albumsByYear.isEmpty else {
            return false
        }
        
        return true
    }
    
    // Filter years based on search text
    private var filteredYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        
        let yearsWithEnoughAlbums = musicManager.sortedYears.filter { year in
            // Always show current year regardless of count
            if year == currentYear {
                return true
            }
            
            // Only show other years with 10+ favorite albums
            guard let albums = musicManager.albumsByYear[year] else { return false }
            return albums.count >= 10
        }
        
        if searchText.isEmpty {
            return yearsWithEnoughAlbums
        }
        
        let lowercasedSearch = searchText.lowercased()
        return yearsWithEnoughAlbums.filter { year in
            guard let albums = musicManager.albumsByYear[year] else { return false }
            return albums.contains { album in
                album.album.lowercased().contains(lowercasedSearch) ||
                album.artist.lowercased().contains(lowercasedSearch)
            }
        }
    }
    
    // Count matching albums for a year
    private func matchingAlbumsCount(forYear year: Int) -> Int {
        guard !searchText.isEmpty, let albums = musicManager.albumsByYear[year] else {
            return musicManager.albumsByYear[year]?.count ?? 0
        }
        let lowercasedSearch = searchText.lowercased()
        return albums.filter { album in
            album.album.lowercased().contains(lowercasedSearch) ||
            album.artist.lowercased().contains(lowercasedSearch)
        }.count
    }
    
    var body: some View {
        Group {
            if shouldShowSplitView {
                splitView
            } else {
                singlePaneView
            }
        }
        .task {
            musicManager.checkAuthorizationStatus()
            hasCheckedAuthorization = true
            
            if musicManager.authorizationStatus == .authorized {
                await loadMusicData()
            }
        }
        .onChange(of: musicManager.authorizationStatus) { oldValue, newValue in
            if newValue == .authorized {
                Task {
                    await loadMusicData()
                }
            }
        }
        .onChange(of: searchText) { oldValue, newValue in
            // If current selection is not in filtered results, switch to first matching year
            if let selected = selectedYear, !filteredYears.contains(selected) {
                selectedYear = filteredYears.first
            }
        }
        .onChange(of: musicManager.sortedYears) { oldValue, newValue in
            // Auto-select the first year when albums are loaded
            if selectedYear == nil, let firstYear = newValue.first {
                selectedYear = firstYear
            }
        }
    }
    
    // MARK: - Split View (authorized with favorites)
    
    private var splitView: some View {
        NavigationSplitView {
            YearListView(
                selectedYear: $selectedYear,
                filteredYears: filteredYears,
                albumsByYear: musicManager.albumsByYear,
                totalFavorites: musicManager.totalFavorites,
                lastUpdated: musicManager.lastUpdated,
                searchText: searchText,
                matchingAlbumsCount: matchingAlbumsCount
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .navigationTitle("Savorite")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    refreshButton
                }
            }
        } detail: {
            if let year = selectedYear, let albums = musicManager.albumsByYear[year] {
                YearDetailView(year: year, albums: albums, musicManager: musicManager, searchText: searchText)
            } else {
                EmptyStateView()
            }
        }
        .searchable(text: $searchText, prompt: "Search albums or artists")
        .frame(minWidth: 800, minHeight: 500)
    }
    
    // MARK: - Single Pane View (authorization, loading, empty states)
    
    private var singlePaneView: some View {
        singlePaneContent
            .frame(minWidth: 500, minHeight: 400)
    }
    
    @ViewBuilder
    private var singlePaneContent: some View {
        // Show nothing until we've checked authorization
        if !hasCheckedAuthorization {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Check actual states
        else if musicManager.authorizationStatus == .notDetermined {
            AuthorizationPromptView {
                await musicManager.requestAuthorization()
            }
        } else if musicManager.authorizationStatus == .denied || musicManager.authorizationStatus == .restricted {
            AccessDeniedView()
        } else if musicManager.isLoading {
            LoadingView(
                currentCount: musicManager.loadingCurrentCount,
                totalCount: musicManager.loadingTotalCount
            )
        } else if musicManager.albumsByYear.isEmpty {
            NoFavoritesView {
                await musicManager.refreshLibrary()
            }
        } else {
            // Fallback (shouldn't normally reach here)
            NoFavoritesView {
                await musicManager.refreshLibrary()
            }
        }
    }
    
    /* MARK: - Shared Toolbar Button */
    
    private var refreshButton: some View {
        Button {
            Task {
                await musicManager.refreshLibrary()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .help("Refresh favorites and play counts")
    }
    
    /* MARK: - Helper Methods */
    
    private func loadMusicData() async {
        /* Try loading from cache first */
        if musicManager.loadFromCache() {
            /* Load play count cache (don't refresh automatically) */
            _ = musicManager.loadPlayCountCache()
        } else {
            /* No cache, fetch from cloud */
            await musicManager.fetchFavoriteAlbums()
        }
    }
}

#Preview {
    ContentView()
}
