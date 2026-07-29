//
//  MusicManager.swift
//  Savorite
//

import Foundation
import MusicKit
import Network
import Observation
import SwiftUI

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
    let artwork: ArtworkAttributes?
    let genreNames: [String]?
    let releaseDate: String?
    let inFavorites: Bool?
    let trackCount: Int?
    let dateAdded: String?
    let contentRating: String?
}

struct ArtworkAttributes: Codable {
    let url: String?
    let width: Int?
    let height: Int?
    let bgColor: String?
    let textColor1: String?
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
    let releaseDate: String?
    let artwork: ArtworkAttributes?
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
    
    /* Session-only debug presentation state */
    var isArtworkHidden = false
    
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
    
    // Filter out invalid year keys (e.g. 0)
    var sortedYears: [Int] {
        albumsByYear.keys.filter { $0 > 0 }.sorted(by: >)
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
            // Silently fail
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
            
            if let excluded = cache.excludedLibraryIds {
                excludedLibraryIds = Set(excluded)
            }
            
            return true
        } catch {
            return false
        }
    }
    
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
            // Silently fail
        }
    }
    
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
            // Silently fail
        }
    }
    
    func fetchFavoriteAlbums() async {
        guard isConnected else {
            errorMessage = "No internet connection. Connect to the internet and try again."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Reset counts so LoadingView renders "Connecting to Apple Music..."
        loadingCurrentCount = 0
        loadingTotalCount = 0
        
        // Delay handshake to give Apple Music's cloud CDN time to process recent favoriting actions
        try? await Task.sleep(for: .seconds(5))
        
        albumsByYear = [:]
        
        var allAlbums: [LibraryAlbum] = []
        var nextURL: String? = "https://api.music.apple.com/v1/me/library/albums?limit=100&include=catalog,tracks.catalog&extend=inFavorites"
        
        var totalSet = false
        do {
            while let urlString = nextURL {
                guard let url = URL(string: urlString) else { break }
                
                // Bypass local HTTP caches to guarantee fresh response
                var urlRequest = URLRequest(url: url)
                urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
                
                let request = MusicDataRequest(urlRequest: urlRequest)
                let response = try await request.response()
                
                let decoder = JSONDecoder()
                let albumsResponse = try decoder.decode(LibraryAlbumsResponse.self, from: response.data)
                
                // 1. Set total FIRST on the very first batch so LoadingView transitions to 0 / Total
                if !totalSet, let total = albumsResponse.meta?.total {
                    loadingTotalCount = total
                    totalAlbumsInLibrary = total
                    totalSet = true
                    
                    // Brief frame pause to allow SwiftUI to animate the transition to 0% progress
                    try? await Task.sleep(for: .milliseconds(50))
                }
                
                // 2. Now append data and increment current count
                allAlbums.append(contentsOf: albumsResponse.data)
                loadingCurrentCount = allAlbums.count
                
                if let next = albumsResponse.next {
                    if next.contains("?") {
                        nextURL = "https://api.music.apple.com\(next)&include=catalog,tracks.catalog&extend=inFavorites"
                    } else {
                        nextURL = "https://api.music.apple.com\(next)?include=catalog,tracks.catalog&extend=inFavorites"
                    }
                } else {
                    nextURL = nil
                }
            }
            
            var grouped: [Int: [AlbumEntry]] = [:]
            
            for album in allAlbums {
                let attrs = album.attributes
                
                guard let albumName = attrs.name, !albumName.isEmpty,
                      let artistName = attrs.artistName, !artistName.isEmpty else {
                    continue
                }
                
                let libraryArtwork = attrs.artwork
                let catalogArtwork = album.relationships?.catalog?.data?.first?.attributes?.artwork
                let artworkTemplate = libraryArtwork?.url ?? catalogArtwork?.url ?? ""
                let artworkBackgroundHex = libraryArtwork?.bgColor ?? catalogArtwork?.bgColor
                let artworkPrimaryTextHex = libraryArtwork?.textColor1 ?? catalogArtwork?.textColor1
                var catalogAlbumId = 0
                var albumLink = ""
                
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
                
                if catalogAlbumId == 0,
                   let track = album.relationships?.tracks?.data?.first,
                   let playParams = track.attributes?.playParams,
                   let catalogId = playParams.catalogId,
                   Int(catalogId) != nil {
                    if let catalogSong = track.relationships?.catalog?.data?.first,
                       let songURL = catalogSong.attributes?.url,
                       let urlObj = URL(string: songURL) {
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
                
                let catalogReleaseDate = album.relationships?.catalog?.data?.first?.attributes?.releaseDate
                let releaseDateString = catalogReleaseDate ?? attrs.releaseDate ?? ""
                
                var parsedYear: Int? = nil
                
                if releaseDateString.count >= 4, let extractedYear = Int(releaseDateString.prefix(4)) {
                    parsedYear = extractedYear
                }
                
                if parsedYear == nil && !releaseDateString.isEmpty {
                    let formatters = ["yyyy-MM-dd", "yyyy-MM", "yyyy"]
                    let df = DateFormatter()
                    df.locale = Locale(identifier: "en_US_POSIX")
                    
                    for format in formatters {
                        df.dateFormat = format
                        if let date = df.date(from: releaseDateString) {
                            parsedYear = Calendar.current.component(.year, from: date)
                            break
                        }
                    }
                }
                
                let year = parsedYear ?? 0
                let isFavorite = attrs.inFavorites ?? false
                
                guard isFavorite else { continue }
                
                let entry = AlbumEntry(
                    album: albumName,
                    artist: artistName,
                    link: albumLink,
                    genre: attrs.genreNames?.first ?? "",
                    itunesId: catalogAlbumId,
                    artworkTemplate: artworkTemplate,
                    artworkBackgroundHex: artworkBackgroundHex,
                    artworkPrimaryTextHex: artworkPrimaryTextHex,
                    libraryId: album.id,
                    isFavorite: isFavorite,
                    releaseDate: releaseDateString,
                    trackCount: attrs.trackCount ?? 0,
                    dateAdded: attrs.dateAdded ?? "",
                    contentRating: attrs.contentRating ?? ""
                )
                
                grouped[year, default: []].append(entry)
            }
            
            for year in grouped.keys {
                grouped[year]?.sort { lhs, rhs in
                    let artistComparison = lhs.sortArtist.localizedCaseInsensitiveCompare(rhs.sortArtist)
                    if artistComparison == .orderedSame {
                        return lhs.album.localizedCaseInsensitiveCompare(rhs.album) == .orderedAscending
                    }
                    return artistComparison == .orderedAscending
                }
            }
            
            albumsByYear = grouped
            totalAlbumsInLibrary = totalFavorites
            
            saveToCache()
            CacheCleanup.clearAfterSync()
            
        } catch {
            errorMessage = MusicManagerError.fetchFailed(underlying: error).errorDescription
        }
        
        isLoading = false
    }
    
    func enrichWithPlayCounts() async {
        isLoadingPlayCounts = true
        
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
            let request = MusicLibraryRequest<Album>()
            let response = try await request.response()
            
            let albums = response.items
            
            guard !albums.isEmpty else {
                isLoadingPlayCounts = false
                return
            }
            
            var newPlayCounts: [String: Int] = playCountsByLibraryId
            
            for album in albums {
                let key = "\(album.artistName.lowercased())|\(album.title.lowercased())"
                
                guard let libraryId = albumKeyToLibraryId[key] else {
                    continue
                }
                
                do {
                    let detailedAlbum = try await album.with([.tracks])
                    guard let tracks = detailedAlbum.tracks else {
                        continue
                    }
                    
                    var trackPlayCounts: [Int] = []
                    for track in tracks {
                        if case .song(let song) = track {
                            trackPlayCounts.append(song.playCount ?? 0)
                        }
                    }
                    
                    guard !trackPlayCounts.isEmpty else { continue }
                    
                    let playedTracks = trackPlayCounts.filter { $0 > 0 }.sorted()
                    let albumPlayCount: Int
                    
                    if playedTracks.isEmpty {
                        albumPlayCount = 0
                    } else if playedTracks.count == 1 {
                        albumPlayCount = playedTracks[0]
                    } else {
                        let percentileIndex = Int(Double(playedTracks.count - 1) * 0.75)
                        albumPlayCount = playedTracks[percentileIndex]
                    }
                    
                    let nonZeroTracks = trackPlayCounts.filter { $0 > 0 }.count
                    let percentagePlayed = Double(nonZeroTracks) / Double(trackPlayCounts.count)
                    
                    let cachedCount = playCountsByLibraryId[libraryId]
                    
                    if albumPlayCount > 0 && percentagePlayed >= 0.4 {
                        if cachedCount != albumPlayCount {
                            newPlayCounts[libraryId] = albumPlayCount
                        }
                    } else if albumPlayCount == 0 && cachedCount != nil {
                        newPlayCounts.removeValue(forKey: libraryId)
                    }
                } catch {
                    // Skip if tracks can't be fetched
                }
            }
            
            playCountsByLibraryId = newPlayCounts
            savePlayCountCache()
            
        } catch {
            // Silently fail
        }
        
        isLoadingPlayCounts = false
    }
    
    func refreshLibrary() async {
        let savedExclusions = excludedLibraryIds
        await fetchFavoriteAlbums()
        excludedLibraryIds = savedExclusions
        saveExclusionsToCache()
        await enrichWithPlayCounts()
    }
    
    func exportJSON(albums: [AlbumEntry]) -> Data? {
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
    
    /* MARK: - Debug / Local Development Actions */
    
    /// Clears local disk caches and memory variables
    func debugClearCache() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: cacheURL)
        try? fileManager.removeItem(at: playCountCacheURL)
        
        albumsByYear = [:]
        playCountsByLibraryId = [:]
        totalAlbumsInLibrary = 0
        lastUpdated = nil
        playCountLastUpdated = nil
    }
    
    /// Toggles album artwork visibility without treating the artwork as unavailable.
    func debugToggleArtworkVisibility() {
        isArtworkHidden.toggle()
    }
    
    /// Resets authorization status, purges system TCC permissions for Media Library,
    /// and clears local cache to force a complete first-run state.
    func debugResetAuthorization() {
        debugClearCache()
        
#if DEBUG
        if let bundleID = Bundle.main.bundleIdentifier {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            task.arguments = ["reset", "MediaLibrary", bundleID]
            try? task.run()
            task.waitUntilExit()
        }
#endif
        
        authorizationStatus = .notDetermined
    }
}

/* MARK: - FocusedValue Key Extension */

struct MusicManagerFocusedKey: FocusedValueKey {
    typealias Value = MusicManager
}

extension FocusedValues {
    var musicManager: MusicManager? {
        get { self[MusicManagerFocusedKey.self] }
        set { self[MusicManagerFocusedKey.self] = newValue }
    }
}
