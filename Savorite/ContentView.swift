//
//  ContentView.swift
//  Savorite
//

import MusicKit
import SwiftUI

enum SidebarGrouping: String {
    case byYear
    case none
}

struct ContentView: View {
    @State private var musicManager = MusicManager()
    @State private var selectedYear: Int?
    @State private var searchText: String = ""
    @State private var hasCheckedAuthorization: Bool = false
    @State private var shouldRefreshAfterAuthorization: Bool = false
    @AppStorage("sidebarGrouping") private var sidebarGrouping: SidebarGrouping = .byYear
    @State private var showNoConnection = false

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
        let years = musicManager.sortedYears

        if searchText.isEmpty {
            return years
        }

        let lowercasedSearch = searchText.lowercased()
        return years.filter { year in
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

    private var allAlbums: [AlbumEntry] {
        musicManager.albumsByYear.values
            .flatMap { $0 }
            .sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
    }

    private var allMatchingCount: Int {
        if searchText.isEmpty { return musicManager.totalFavorites }
        let lowercasedSearch = searchText.lowercased()
        return allAlbums.filter { album in
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
        .focusedSceneValue(\.musicManager, musicManager)
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

                    if shouldRefreshAfterAuthorization {
                        shouldRefreshAfterAuthorization = false
                        await musicManager.refreshLibrary()
                    }
                }
            }
        }
        .onChange(of: searchText) { oldValue, newValue in
            if sidebarGrouping == .byYear {
                if let selected = selectedYear, !filteredYears.contains(selected) {
                    selectedYear = filteredYears.first
                }
            }
        }
        .onChange(of: musicManager.sortedYears) { oldValue, newValue in
            if selectedYear == nil {
                if sidebarGrouping == .none {
                    selectedYear = 0
                } else if let firstYear = filteredYears.first {
                    selectedYear = firstYear
                }
            }
        }
        .onChange(of: sidebarGrouping) { _, newValue in
            if newValue == .none {
                selectedYear = 0
            } else {
                selectedYear = filteredYears.first
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
                matchingAlbumsCount: matchingAlbumsCount,
                sidebarGrouping: $sidebarGrouping,
                allMatchingCount: allMatchingCount
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .navigationTitle("Savorite")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if musicManager.isConnected {
                            showNoConnection = false
                            Task {
                                await musicManager.refreshLibrary()
                            }
                        } else {
                            showNoConnection = true
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh favorites and play counts")
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityLabel("Refresh library")
                    .accessibilityHint("Fetches latest favorite albums from Apple Music")
                }
            }
        } detail: {
            if showNoConnection {
                NoConnectionView {
                    if musicManager.isConnected {
                        showNoConnection = false
                        await musicManager.refreshLibrary()
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No internet connection")
                .accessibilityHint("Connect to the internet to refresh your music library")
            } else if sidebarGrouping == .none {
                YearDetailView(
                    title: "All Favorites",
                    albums: allAlbums,
                    musicManager: musicManager,
                    searchText: searchText
                )
            } else if let year = selectedYear, let albums = musicManager.albumsByYear[year] {
                YearDetailView(
                    title: String(year),
                    albums: albums,
                    musicManager: musicManager,
                    searchText: searchText
                )
            } else {
                EmptyStateView()
            }
        }
        .searchable(text: $searchText, prompt: "Search albums or artists")
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: musicManager.isConnected) { _, connected in
            if connected && showNoConnection {
                showNoConnection = false
            }
        }
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
                .accessibilityLabel("Checking library authorization status")
        }
        // Check actual states
        else if musicManager.authorizationStatus == .notDetermined {
            AuthorizationPromptView {
                shouldRefreshAfterAuthorization = true
                await musicManager.requestAuthorization()
            }
        } else if musicManager.authorizationStatus == .denied || musicManager.authorizationStatus == .restricted {
            AccessDeniedView()
        } else if musicManager.isLoading {
            LoadingView(
                currentCount: musicManager.loadingCurrentCount,
                totalCount: musicManager.loadingTotalCount
            )
        } else if musicManager.albumsByYear.isEmpty && !musicManager.isConnected {
            NoConnectionView {
                await musicManager.refreshLibrary()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No internet connection and no cached favorites found")
        } else if musicManager.albumsByYear.isEmpty {
            NoFavoritesView {
                await musicManager.refreshLibrary()
            }
        }
    }

    /* MARK: - Helper Methods */

    private func loadMusicData() async {
        /* Try loading from cache first */
        if musicManager.loadFromCache() {
            /* Load play count cache (don't refresh automatically) */
            _ = musicManager.loadPlayCountCache()
        } else {
            /*
             No cache found. Do not automatically scan from the cloud.
             Leaving `albumsByYear` empty causes `ContentView` to show `NoFavoritesView`,
             requiring the user to manually click "Refresh Library".
             */
        }
    }
}

#Preview {
    ContentView()
}
