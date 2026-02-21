//
//  MusicManager.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import Foundation
import MusicKit
import Network
import Observation

/* MARK: - Error Types */

enum MusicManagerError: LocalizedError {
    case fetchFailed(underlying: Error)
    case unauthorized
    case cacheCorrupted
    case noAlbumsFound
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to load your music library: \(error.localizedDescription)"
        case .unauthorized:
            return "Please authorize Savorite to access your Apple Music library"
        case .cacheCorrupted:
            return "Cached data is corrupted. Please refresh your library."
        case .noAlbumsFound:
            return "No albums found in your library"
        }
    }
}

/* MARK: - Response Structures */

/* Response structures for Apple Music API */
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

@Observable
@MainActor
class MusicManager {
    var authorizationStatus: MusicAuthorization.Status = .notDetermined
    var isLoading = false
    var albumsByYear: [Int: [AlbumEntry]] = [:]
    var errorMessage: String?
    var totalAlbumsInLibrary = 0
    var lastUpdated: Date?
    var isConnected = true
    
    /* Loading progress tracking */
    var loadingCurrentCount = 0
    var loadingTotalCount = 0
    
    /* Track excluded albums by library ID (persists across sessions) */
    var excludedLibraryIds: Set<String> = []
    
    /* Play count tracking */
    var playCountsByLibraryId: [String: Int] = [:]
    var isLoadingPlayCounts = false
    var playCountLastUpdated: Date?
    
    private let monitor = NWPathMonitor()
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
    
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
            // Silently fail - exclusions can be re-saved later
        }
    }
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = MusicAuthorization.currentStatus
    }
    
    func loadFromCache() -> Bool {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let cache = try JSONDecoder().decode(AlbumCache.self, from: data)
            
            albumsByYear = cache.albums
            totalAlbumsInLibrary = cache.totalAlbums
            lastUpdated = cache.lastUpdated
            
            /* Restore excluded albums */
            if let excluded = cache.excludedLibraryIds {
                excludedLibraryIds = Set(excluded)
            }
            
            return true
        } catch {
            return false
        }
    }
    
    /*
     Load play count cache if available
     */
    func loadPlayCountCache() -> Bool {
        guard FileManager.default.fileExists(atPath: playCountCacheURL.path) else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: playCountCacheURL)
            let cache = try JSONDecoder().decode(PlayCountCache.self, from: data)
            playCountsByLibraryId = cache.playCountsByLibraryId
            playCountLastUpdated = cache.lastUpdated
            return true
        } catch {
            return false
        }
    }
    
    /* Save to cache (preserves existing albums unless new ones provided) */
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
        } catch {
            // Silently fail - cache will be regenerated on next launch
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
        } catch {
            // Silently fail - cache will be regenerated on next refresh
        }
    }
    
    // Fetch albums using Apple Music API (cloud library)
    func fetchFavoriteAlbums(incremental: Bool = false) async {
        guard isConnected else {
            errorMessage = "No internet connection. Connect to the internet and try again."
            return
        }
        
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
        
        var allAlbums: [LibraryAlbum] = []
        var nextURL: String? = "https://api.music.apple.com/v1/me/library/albums?limit=100&include=catalog,tracks.catalog&extend=inFavorites"
        
        /* Fetch all pages */
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
            
            /* Process albums - extract catalog IDs from track data */
            var grouped: [Int: [AlbumEntry]] = [:]
            
            for album in allAlbums {
                
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
                    } else if let albumURL = catalogAlbum.attributes?.url,
                              let urlObj = URL(string: albumURL) {
                        let pathComponents = urlObj.pathComponents
                        if let lastComponent = pathComponents.last,
                           let albumId = Int(lastComponent) {
                            catalogAlbumId = albumId
                            albumLink = "https://music.apple.com/us/album/\(albumId)"
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
                
                grouped[year, default: []].append(entry)
            }
            
            // Sort albums within each year alphabetically by artist
            for year in grouped.keys {
                grouped[year]?.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
            }
            
            albumsByYear = grouped
            totalAlbumsInLibrary = totalFavorites
            
            /* Save to cache */
            saveToCache()
            
        } catch {
            errorMessage = MusicManagerError.fetchFailed(underlying: error).errorDescription
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
            isLoadingPlayCounts = false
            return
        }
        
        do {
            /* Fetch all albums using MusicLibraryRequest */
            let request = MusicLibraryRequest<Album>()
            let response = try await request.response()
            
            let albums = response.items
            
            guard !albums.isEmpty else {
                isLoadingPlayCounts = false
                return
            }
            
            /* Calculate play counts for each album */
            var newPlayCounts: [String: Int] = playCountsByLibraryId
            
            for album in albums {
                let key = "\(album.artistName.lowercased())|\(album.title.lowercased())"
                
                /* Look up the library ID from our map */
                guard let libraryId = albumKeyToLibraryId[key] else {
                    continue
                }
                
                /* Fetch tracks for this album */
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
                    
                    /* Calculate play count using 75th percentile of played tracks
                     This better represents actual album listens than median,
                     accounting for skipped tracks (intros, interludes) while
                     avoiding inflation from a few heavily replayed songs */
                    let playedTracks = trackPlayCounts.filter { $0 > 0 }.sorted()
                    let albumPlayCount: Int
                    
                    if playedTracks.isEmpty {
                        /* No tracks have been played */
                        albumPlayCount = 0
                    } else if playedTracks.count == 1 {
                        /* Only one track played */
                        albumPlayCount = playedTracks[0]
                    } else {
                        /* Use 75th percentile of played tracks */
                        let percentileIndex = Int(Double(playedTracks.count - 1) * 0.75)
                        albumPlayCount = playedTracks[percentileIndex]
                    }
                    
                    /* Apply threshold: at least 50% of tracks must have been played */
                    let nonZeroTracks = trackPlayCounts.filter { $0 > 0 }.count
                    let percentagePlayed = Double(nonZeroTracks) / Double(trackPlayCounts.count)
                    
                    /* Check if this differs from cached value */
                    let cachedCount = playCountsByLibraryId[libraryId]
                    
                    /* Only update if play count > 0, threshold met, and value changed */
                    if albumPlayCount > 0 && percentagePlayed >= 0.5 {
                        if cachedCount != albumPlayCount {
                            newPlayCounts[libraryId] = albumPlayCount
                        }
                    } else if albumPlayCount == 0 && cachedCount != nil {
                        /* Remove from cache if it no longer meets threshold */
                        newPlayCounts.removeValue(forKey: libraryId)
                    }
                } catch {
                    /* Skip this album if tracks can't be fetched */
                }
            }
            
            playCountsByLibraryId = newPlayCounts
            savePlayCountCache()
            
        } catch {
            // Silently fail - play counts will be missing but app continues
        }
        
        isLoadingPlayCounts = false
    }
    
    /* Refresh library - incremental update (preserves cache, adds new favorites and updates play counts) */
    func refreshLibrary() async {
        /* Preserve user exclusions */
        let savedExclusions = excludedLibraryIds
        
        /* Use incremental mode to only add new albums (keeps existing cache) */
        await fetchFavoriteAlbums(incremental: true)
        
        /* Restore exclusions */
        excludedLibraryIds = savedExclusions
        saveExclusionsToCache()
        
        /* Trigger play count refresh */
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
}
