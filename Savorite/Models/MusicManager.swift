//
//  MusicManager.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import Combine
import Foundation
import MusicKit

// Response structures for Apple Music API
struct LibraryAlbumsResponse: Codable {
    let data: [LibraryAlbum]
    let next: String?
    let meta: ResponseMeta?
}

struct ResponseMeta: Codable {
    let total: Int
}

struct LibraryAlbum: Codable {
    let id: String
    let attributes: LibraryAlbumAttributes
    let relationships: LibraryAlbumRelationships?
}

struct LibraryAlbumAttributes: Codable {
    let name: String?
    let artistName: String?
    let artwork: LibraryArtwork?
    let genreNames: [String]?
    let releaseDate: String?
    let inFavorites: Bool?
    let trackCount: Int?
    let dateAdded: String?
    let contentRating: String?
}

struct LibraryArtwork: Codable {
    let url: String?
    let width: Int?
    let height: Int?
}

struct LibraryAlbumRelationships: Codable {
    let tracks: TracksRelationship?
    let catalog: CatalogAlbumRelationship?
}

struct CatalogAlbumRelationship: Codable {
    let data: [CatalogAlbum]?
}

struct CatalogAlbum: Codable {
    let id: String
    let attributes: CatalogAlbumAttributes?
}

struct CatalogAlbumAttributes: Codable {
    let url: String?
}

struct TracksRelationship: Codable {
    let data: [LibraryTrack]?
}

struct LibraryTrack: Codable {
    let id: String
    let attributes: LibraryTrackAttributes?
    let relationships: LibraryTrackRelationships?
}

struct LibraryTrackAttributes: Codable {
    let name: String
    let playParams: TrackPlayParams?
}

struct TrackPlayParams: Codable {
    let catalogId: String?
}

struct LibraryTrackRelationships: Codable {
    let catalog: CatalogSongRelationship?
}

struct CatalogSongRelationship: Codable {
    let data: [CatalogSong]?
}

struct CatalogSong: Codable {
    let id: String
    let attributes: CatalogSongAttributes?
}

struct CatalogSongAttributes: Codable {
    let url: String?
}

// Cache structure
struct AlbumCache: Codable {
    let albums: [Int: [AlbumEntry]]
    let lastUpdated: Date
    let totalAlbums: Int
    let excludedLibraryIds: [String]?
}

// Play count cache structure
struct PlayCountCache: Codable {
    let playCountsByLibraryId: [String: Int]
    let lastUpdated: Date
}

@MainActor
class MusicManager: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var isLoading = false
    @Published var albumsByYear: [Int: [AlbumEntry]] = [:]
    @Published var errorMessage: String?
    @Published var totalAlbumsInLibrary = 0
    @Published var lastUpdated: Date?
    
    // Loading progress tracking
    @Published var loadingCurrentCount = 0
    @Published var loadingTotalCount = 0
    
    // Track excluded albums by library ID (persists across sessions)
    @Published var excludedLibraryIds: Set<String> = []
    
    // Play count tracking
    @Published var playCountsByLibraryId: [String: Int] = [:]
    @Published var isLoadingPlayCounts = false
    @Published var playCountLastUpdated: Date?
    
    // Only favorites are stored/displayed
    var sortedYears: [Int] {
        albumsByYear.keys.sorted(by: >)
    }
    
    var totalFavorites: Int {
        albumsByYear.values.reduce(0) { $0 + $1.count }
    }
    
    func toggleExclusion(for album: AlbumEntry) {
        if excludedLibraryIds.contains(album.libraryId) {
            excludedLibraryIds.remove(album.libraryId)
        } else {
            excludedLibraryIds.insert(album.libraryId)
        }
        saveExclusionsToCache()
    }
    
    func setExclusion(for albums: [AlbumEntry], excluded: Bool) {
        for album in albums {
            if excluded {
                excludedLibraryIds.insert(album.libraryId)
            } else {
                excludedLibraryIds.remove(album.libraryId)
            }
        }
        saveExclusionsToCache()
    }
    
    func isExcluded(_ album: AlbumEntry) -> Bool {
        excludedLibraryIds.contains(album.libraryId)
    }
    
    func excludedCount(forYear year: Int) -> Int {
        guard let albums = albumsByYear[year] else { return 0 }
        return albums.filter { excludedLibraryIds.contains($0.libraryId) }.count
    }
    
    private var cacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("savorite_albums.json")
    }
    
    private var playCountCacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("savorite_play_counts.json")
    }
    
    private func saveExclusionsToCache() {
        // Update just the exclusions in existing cache
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheURL)
            let oldCache = try JSONDecoder().decode(AlbumCache.self, from: data)
            let newCache = AlbumCache(
                albums: oldCache.albums,
                lastUpdated: oldCache.lastUpdated,
                totalAlbums: oldCache.totalAlbums,
                excludedLibraryIds: Array(excludedLibraryIds)
            )
            let newData = try JSONEncoder().encode(newCache)
            try newData.write(to: cacheURL)
        } catch {
            print("Failed to save exclusions: \(error)")
        }
    }
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = MusicAuthorization.currentStatus
    }
    
    // Load from cache if available
    func loadFromCache() -> Bool {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            print("No cache file found")
            return false
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let cache = try JSONDecoder().decode(AlbumCache.self, from: data)
            
            albumsByYear = cache.albums
            totalAlbumsInLibrary = cache.totalAlbums
            lastUpdated = cache.lastUpdated
            
            // Restore excluded albums
            if let excluded = cache.excludedLibraryIds {
                excludedLibraryIds = Set(excluded)
            }
            
            print("Loaded \(cache.totalAlbums) albums from cache (updated: \(cache.lastUpdated))")
            return true
        } catch {
            print("Failed to load cache: \(error)")
            return false
        }
    }
    
    /*
     Load play count cache if available
     */
    func loadPlayCountCache() -> Bool {
        guard FileManager.default.fileExists(atPath: playCountCacheURL.path) else {
            print("No play count cache file found")
            return false
        }
        
        do {
            let data = try Data(contentsOf: playCountCacheURL)
            let cache = try JSONDecoder().decode(PlayCountCache.self, from: data)
            playCountsByLibraryId = cache.playCountsByLibraryId
            playCountLastUpdated = cache.lastUpdated
            print("Loaded \(cache.playCountsByLibraryId.count) play counts from cache (updated: \(cache.lastUpdated))")
            return true
        } catch {
            print("Failed to load play count cache: \(error)")
            return false
        }
    }
    
    // Save to cache (preserves existing albums unless new ones provided)
    private func saveToCache() {
        let cache = AlbumCache(
            albums: albumsByYear,
            lastUpdated: Date(),
            totalAlbums: totalFavorites,
            excludedLibraryIds: Array(excludedLibraryIds)
        )
        
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheURL)
            lastUpdated = cache.lastUpdated
            print("Saved \(totalAlbumsInLibrary) albums to cache")
        } catch {
            print("Failed to save cache: \(error)")
        }
    }
    
    /*
     Save play count cache
     */
    private func savePlayCountCache() {
        let cache = PlayCountCache(
            playCountsByLibraryId: playCountsByLibraryId,
            lastUpdated: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: playCountCacheURL)
            playCountLastUpdated = cache.lastUpdated
            print("Saved \(playCountsByLibraryId.count) play counts to cache")
        } catch {
            print("Failed to save play count cache: \(error)")
        }
    }
    
    // Fetch albums using Apple Music API (cloud library)
    func fetchFavoriteAlbums(incremental: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        // Build set of existing library IDs for incremental update
        var existingLibraryIds: Set<String> = []
        var existingAlbumsByLibraryId: [String: AlbumEntry] = [:]
        if incremental {
            for (_, albums) in albumsByYear {
                for album in albums {
                    existingLibraryIds.insert(album.libraryId)
                    existingAlbumsByLibraryId[album.libraryId] = album
                }
            }
        } else {
            albumsByYear = [:]
        }
        
        let startTime = Date()
        var allAlbums: [LibraryAlbum] = []
        var nextURL: String? = "https://api.music.apple.com/v1/me/library/albums?limit=100&include=catalog,tracks.catalog&extend=inFavorites"
        
        // Fetch all pages
        loadingCurrentCount = 0
        loadingTotalCount = 0
        var totalSet = false
        do {
            while let urlString = nextURL {
                guard let url = URL(string: urlString) else { break }
                
                let request = MusicDataRequest(urlRequest: URLRequest(url: url))
                let response = try await request.response()
                
                let decoder = JSONDecoder()
                let albumsResponse = try decoder.decode(LibraryAlbumsResponse.self, from: response.data)
                
                allAlbums.append(contentsOf: albumsResponse.data)
                
                // Only set total once from the first response to avoid jumpy progress
                if !totalSet, let total = albumsResponse.meta?.total {
                    loadingTotalCount = total
                    totalAlbumsInLibrary = total
                    totalSet = true
                }
                
                // Update progress for UI
                loadingCurrentCount = allAlbums.count
                
                // Get next page URL - always append our custom parameters
                if let next = albumsResponse.next {
                    // The API's next URL doesn't include our custom parameters, so add them
                    if next.contains("?") {
                        nextURL = "https://api.music.apple.com\(next)&include=catalog,tracks.catalog&extend=inFavorites"
                    } else {
                        nextURL = "https://api.music.apple.com\(next)?include=catalog,tracks.catalog&extend=inFavorites"
                    }
                } else {
                    nextURL = nil
                }
            }
            
            print("Fetched \(allAlbums.count) albums from cloud library")
            
            // Process albums - extract catalog IDs from track data
            // Processing albums...
            var grouped: [Int: [AlbumEntry]] = [:]
            var processedCount = 0
            var withCatalogId = 0
            
            for album in allAlbums {
                processedCount += 1
                
                let attrs = album.attributes
                
                // Skip albums without name or artist
                guard let albumName = attrs.name, !albumName.isEmpty,
                      let artistName = attrs.artistName, !artistName.isEmpty else {
                    continue
                }
                
                // Get artwork template URL
                let artworkTemplate = attrs.artwork?.url ?? ""
                
                // Extract catalog album ID
                var catalogAlbumId = 0
                var albumLink = ""
                
                // First try direct catalog relationship on album
                if let catalogAlbum = album.relationships?.catalog?.data?.first {
                    if let albumId = Int(catalogAlbum.id) {
                        catalogAlbumId = albumId
                        albumLink = "https://music.apple.com/us/album/\(albumId)"
                        withCatalogId += 1
                    } else if let albumURL = catalogAlbum.attributes?.url,
                              let urlObj = URL(string: albumURL) {
                        let pathComponents = urlObj.pathComponents
                        if let lastComponent = pathComponents.last,
                           let albumId = Int(lastComponent) {
                            catalogAlbumId = albumId
                            albumLink = "https://music.apple.com/us/album/\(albumId)"
                            withCatalogId += 1
                        }
                    }
                }
                
                // Fallback: try to get catalog ID from first track's playParams
                if catalogAlbumId == 0,
                   let track = album.relationships?.tracks?.data?.first,
                   let playParams = track.attributes?.playParams,
                   let catalogId = playParams.catalogId,
                   Int(catalogId) != nil {
                    // The track's catalogId is for the song, but we can look up the album
                    // For now, we'll note this track has catalog data and try the catalog relationship on track
                    if let catalogSong = track.relationships?.catalog?.data?.first,
                       let songURL = catalogSong.attributes?.url,
                       let urlObj = URL(string: songURL) {
                        // URL format: https://music.apple.com/us/album/album-name/ALBUM_ID?i=SONG_ID
                        let pathComponents = urlObj.pathComponents
                        if pathComponents.count >= 4 {
                            let potentialAlbumId = pathComponents[pathComponents.count - 1]
                            if let albumId = Int(potentialAlbumId) {
                                catalogAlbumId = albumId
                                albumLink = "https://music.apple.com/us/album/\(albumId)"
                                withCatalogId += 1
                            }
                        }
                    }
                }
                
                // Parse release date and year
                let releaseDateString = attrs.releaseDate ?? ""
                var year = Calendar.current.component(.year, from: Date())
                if !releaseDateString.isEmpty {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = dateFormatter.date(from: releaseDateString) {
                        year = Calendar.current.component(.year, from: date)
                    } else if releaseDateString.count >= 4, let y = Int(releaseDateString.prefix(4)) {
                        year = y
                    }
                }
                
                let isFavorite = attrs.inFavorites ?? false
                
                // Only include favorites
                guard isFavorite else { continue }
                
                // In incremental mode, prefer existing cached data
                let entry: AlbumEntry
                if incremental, let existing = existingAlbumsByLibraryId[album.id] {
                    entry = existing
                } else {
                    entry = AlbumEntry(
                        album: albumName,
                        artist: artistName,
                        link: albumLink,
                        genre: attrs.genreNames?.first ?? "",
                        itunesId: catalogAlbumId,
                        artworkTemplate: artworkTemplate,
                        libraryId: album.id,
                        isFavorite: isFavorite,
                        releaseDate: releaseDateString,
                        trackCount: attrs.trackCount ?? 0,
                        dateAdded: attrs.dateAdded ?? "",
                        contentRating: attrs.contentRating ?? ""
                    )
                }
                
                withCatalogId += 1  // Count favorites
                
                grouped[year, default: []].append(entry)
            }
            
            // Sort albums within each year alphabetically by artist
            for year in grouped.keys {
                grouped[year]?.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
            }
            
            albumsByYear = grouped
            totalAlbumsInLibrary = totalFavorites
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("Processed \(processedCount) albums in \(String(format: "%.1f", elapsed))s")
            print("\(withCatalogId) albums are favorites")
            
            // Save to cache
            saveToCache()
            
        } catch {
            errorMessage = "Failed to fetch: \(error.localizedDescription)"
            print("Error: \(error)")
        }
        
        isLoading = false
    }
    
    /*
     Enrich albums with play counts using MusicLibraryRequest
     This runs as a background task after main album cache is loaded
     */
    func enrichWithPlayCounts() async {
        isLoadingPlayCounts = true
        
        // Build a map of "artist|album" to library ID from cached albums
        var albumKeyToLibraryId: [String: String] = [:]
        for (_, albums) in albumsByYear {
            for album in albums {
                if !album.libraryId.isEmpty {
                    let key = "\(album.artist.lowercased())|\(album.album.lowercased())"
                    albumKeyToLibraryId[key] = album.libraryId
                }
            }
        }
        
        guard !albumKeyToLibraryId.isEmpty else {
            print("No albums to enrich with play counts")
            isLoadingPlayCounts = false
            return
        }
        
        print("Enriching \(albumKeyToLibraryId.count) albums with play counts...")
        
        do {
            // Fetch all albums using MusicLibraryRequest
            let request = MusicLibraryRequest<Album>()
            let response = try await request.response()
            
            let albums = response.items
            
            guard !albums.isEmpty else {
                print("No albums returned from MusicLibraryRequest")
                isLoadingPlayCounts = false
                return
            }
            
            print("Fetched \(albums.count) albums from MusicLibraryRequest")
            
            // Calculate play counts for each album
            var newPlayCounts: [String: Int] = playCountsByLibraryId // Start with cached values
            var matchedCount = 0
            var updatedCount = 0
            var skippedCount = 0
            
            for album in albums {
                // Create matching key from this album
                let key = "\(album.artistName.lowercased())|\(album.title.lowercased())"
                
                // Look up the library ID from our map
                guard let libraryId = albumKeyToLibraryId[key] else {
                    continue
                }
                
                matchedCount += 1
                
                // Fetch tracks for this album
                do {
                    let detailedAlbum = try await album.with([.tracks])
                    guard let tracks = detailedAlbum.tracks else {
                        continue
                    }
                    
                    // Collect play counts from all tracks
                    var trackPlayCounts: [Int] = []
                    for track in tracks {
                        if case .song(let song) = track {
                            trackPlayCounts.append(song.playCount ?? 0)
                        }
                    }
                    
                    guard !trackPlayCounts.isEmpty else { continue }
                    
                    // Calculate median play count for the album
                    let sortedCounts = trackPlayCounts.sorted()
                    let medianPlayCount: Int
                    
                    if sortedCounts.count % 2 == 0 {
                        // Even number of tracks: average of middle two
                        let mid1 = sortedCounts[sortedCounts.count / 2 - 1]
                        let mid2 = sortedCounts[sortedCounts.count / 2]
                        medianPlayCount = (mid1 + mid2) / 2
                    } else {
                        // Odd number of tracks: middle value
                        medianPlayCount = sortedCounts[sortedCounts.count / 2]
                    }
                    
                    // Apply threshold: at least 50% of tracks must have been played
                    let nonZeroTracks = trackPlayCounts.filter { $0 > 0 }.count
                    let percentagePlayed = Double(nonZeroTracks) / Double(trackPlayCounts.count)
                    
                    // Check if this differs from cached value
                    let cachedCount = playCountsByLibraryId[libraryId]
                    
                    // Only update if median > 0, threshold met, and value changed
                    if medianPlayCount > 0 && percentagePlayed >= 0.5 {
                        if cachedCount != medianPlayCount {
                            newPlayCounts[libraryId] = medianPlayCount
                            updatedCount += 1
                        } else {
                            skippedCount += 1
                        }
                    } else if medianPlayCount == 0 && cachedCount != nil {
                        // Remove from cache if it no longer meets threshold
                        newPlayCounts.removeValue(forKey: libraryId)
                        updatedCount += 1
                    }
                    
                    if matchedCount % 50 == 0 {
                        print("Processed \(matchedCount) albums (\(updatedCount) updated, \(skippedCount) unchanged)...")
                    }
                } catch {
                    print("Failed to fetch tracks for album '\(album.title)': \(error)")
                }
            }
            
            playCountsByLibraryId = newPlayCounts
            savePlayCountCache()
            print("Successfully enriched \(newPlayCounts.count) albums with play counts")
            print("Updated: \(updatedCount), Unchanged: \(skippedCount)")
            if !newPlayCounts.isEmpty {
                print("Sample play counts: \(Array(newPlayCounts.prefix(3)))")
            }
            
        } catch {
            print("Failed to enrich with play counts: \(error)")
        }
        
        isLoadingPlayCounts = false
    }
    
    // Refresh library - incremental update (preserves cache, adds new favorites)
    func refreshLibrary() async {
        // Check if library was recently refreshed (within last hour)
        if let lastUpdated = lastUpdated {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdated)
            let oneHourInSeconds: TimeInterval = 3600
            
            if timeSinceLastUpdate < oneHourInSeconds {
                print("Skipping library refresh (last updated \(Int(timeSinceLastUpdate / 60)) minutes ago)")
                print("Refreshing play counts only...")
                
                // Only refresh play counts
                await enrichWithPlayCounts()
                return
            }
        }
        
        // Preserve user exclusions
        let savedExclusions = excludedLibraryIds
        
        // Use incremental mode to only add new albums (keeps existing cache)
        await fetchFavoriteAlbums(incremental: true)
        
        // Restore exclusions
        excludedLibraryIds = savedExclusions
        saveExclusionsToCache()
        
        // Trigger play count refresh
        await enrichWithPlayCounts()
    }
    
    // Force refresh - always checks for new favorites regardless of last update time
    func forceRefreshLibrary() async {
        // Preserve user exclusions
        let savedExclusions = excludedLibraryIds
        
        // Use incremental mode to only add new albums (keeps existing cache)
        await fetchFavoriteAlbums(incremental: true)
        
        // Restore exclusions
        excludedLibraryIds = savedExclusions
        saveExclusionsToCache()
        
        // Trigger play count refresh
        await enrichWithPlayCounts()
    }
    
    func exportJSON(albums: [AlbumEntry]) -> Data? {
        // Filter out excluded albums
        let includedAlbums = albums.filter { !isExcluded($0) }
        guard !includedAlbums.isEmpty else { return nil }
        
        struct ExportAlbum: Codable {
            let id: Int?
            let name: String
            let artistName: String
            let artwork: String
            let genre: String
            let releaseDate: String
            let url: String
            let trackCount: Int
            let dateAdded: String
            let contentRating: String?
            let playCount: Int?
        }
        
        let exportAlbums = includedAlbums.map { album in
            let appleURL = album.itunesId > 0
            ? "https://music.apple.com/us/album/\(album.itunesId)"
            : ""
            
            let playCount = playCountsByLibraryId[album.libraryId]
            
            // Debug: Log if we're missing play count for an album
            if playCount == nil && !album.libraryId.isEmpty {
                print("⚠️ No play count for '\(album.album)' by \(album.artist) (libraryId: \(album.libraryId))")
            }
            
            return ExportAlbum(
                id: album.itunesId > 0 ? album.itunesId : nil,
                name: album.album,
                artistName: album.artist,
                artwork: album.cover,
                genre: album.genre,
                releaseDate: album.releaseDate,
                url: appleURL,
                trackCount: album.trackCount,
                dateAdded: album.dateAdded,
                contentRating: album.contentRating.isEmpty ? nil : album.contentRating,
                playCount: playCount
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        
        do {
            let data = try encoder.encode(exportAlbums)
            
            // Fix Swift's default formatting: remove space before colons
            // Swift outputs "key" : "value" but standard JSON is "key": "value"
            guard var jsonString = String(data: data, encoding: .utf8) else {
                return data
            }
            jsonString = jsonString.replacingOccurrences(of: "\" : ", with: "\": ")
            
            return jsonString.data(using: .utf8)
        } catch {
            errorMessage = "Failed to encode JSON: \(error.localizedDescription)"
            return nil
        }
    }
    
    // Debug: Inspect a specific album's full API response
    func inspectAlbum(_ album: AlbumEntry) async {
        print("\n=== INSPECTING ALBUM: \(album.album) by \(album.artist) ===")
        print("iTunes ID: \(album.itunesId)")
        print("Library ID: \(album.libraryId)")
        print("isFavorite (cached): \(album.isFavorite)")
        
        // If we have a library ID, fetch it directly with inFavorites extension
        if !album.libraryId.isEmpty {
            let libraryURL = URL(string: "https://api.music.apple.com/v1/me/library/albums/\(album.libraryId)?extend=inFavorites")!
            print("Fetching library album: \(libraryURL.absoluteString)")
            
            do {
                let request = MusicDataRequest(urlRequest: URLRequest(url: libraryURL))
                let response = try await request.response()
                let json = String(data: response.data, encoding: .utf8) ?? "Could not decode"
                print("\n--- Library Album Response ---")
                print(json)
                print("------------------------------\n")
            } catch {
                print("Library fetch error: \(error)")
            }
        }
        
        // If we have a catalog ID, fetch it too
        if album.itunesId > 0 {
            let catalogURL = URL(string: "https://api.music.apple.com/v1/catalog/us/albums/\(album.itunesId)?extend=inFavorites")!
            print("Fetching catalog album: \(catalogURL.absoluteString)")
            
            do {
                let request = MusicDataRequest(urlRequest: URLRequest(url: catalogURL))
                let response = try await request.response()
                let json = String(data: response.data, encoding: .utf8) ?? "Could not decode"
                print("\n--- Catalog Album Response ---")
                print(json)
                print("------------------------------\n")
            } catch {
                print("Catalog fetch error: \(error)")
            }
        }
        
        print("=== END INSPECTION ===\n")
    }
    
    // Debug: search for a specific album by name to test
    func debugSearchAlbum(name: String) async {
        print("\n=== DEBUG SEARCH: \(name) ===")
        
        // Search library albums
        let searchURL = URL(string: "https://api.music.apple.com/v1/me/library/albums?limit=100&extend=inFavorites")!
        
        do {
            let request = MusicDataRequest(urlRequest: URLRequest(url: searchURL))
            let response = try await request.response()
            
            // Search through the JSON for the album name
            let json = String(data: response.data, encoding: .utf8) ?? ""
            if json.contains(name) {
                print("Found '\(name)' in first 100 albums!")
                // Print a snippet around it
                if let range = json.range(of: name) {
                    let start = json.index(range.lowerBound, offsetBy: -200, limitedBy: json.startIndex) ?? json.startIndex
                    let end = json.index(range.upperBound, offsetBy: 500, limitedBy: json.endIndex) ?? json.endIndex
                    print(json[start..<end])
                }
            } else {
                print("'\(name)' NOT found in first 100 albums")
            }
        } catch {
            print("Search error: \(error)")
        }
        
        print("=== END DEBUG SEARCH ===\n")
    }
}
