//
//  AlbumEntry.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import Foundation

/* Model representing an album entry for caching and export. */
struct AlbumEntry: Codable, Identifiable {
    let album: String
    let artist: String
    let link: String
    let genre: String
    let itunesId: Int
    
    /* Artwork template URL with {w}x{h} placeholders */
    let artworkTemplate: String
    
    /* Library ID for querying Apple Music API */
    let libraryId: String
    
    /* Whether the album is favorited (starred) in Apple Music */
    let isFavorite: Bool
    
    /* Full release date string from API (e.g., "2025-10-03") */
    let releaseDate: String
    
    /* Additional useful fields */
    let trackCount: Int
    let dateAdded: String
    let contentRating: String
    
    /* Play count (enriched separately from main cache) */
    let playCount: Int?
    
    /* Use stable libraryId for SwiftUI list identity */
    var id: String {
        libraryId
    }
    
    // Computed property for display (600px version)
    var cover: String {
        artworkTemplate
            .replacingOccurrences(of: "{w}", with: "600")
            .replacingOccurrences(of: "{h}", with: "600")
    }
    
    init(
        album: String,
        artist: String,
        link: String,
        genre: String,
        itunesId: Int,
        artworkTemplate: String = "",
        libraryId: String = "",
        isFavorite: Bool = false,
        releaseDate: String = "",
        trackCount: Int = 0,
        dateAdded: String = "",
        contentRating: String = "",
        playCount: Int? = nil
    ) {
        self.album = album
        self.artist = artist
        self.link = link
        self.genre = genre
        self.itunesId = itunesId
        self.artworkTemplate = artworkTemplate
        self.libraryId = libraryId
        self.isFavorite = isFavorite
        self.releaseDate = releaseDate
        self.trackCount = trackCount
        self.dateAdded = dateAdded
        self.contentRating = contentRating
        self.playCount = playCount
    }
    
    enum CodingKeys: String, CodingKey {
        case album
        case artist
        case link
        case genre
        case itunesId
        case artworkTemplate
        case libraryId
        case isFavorite
        case releaseDate
        case trackCount
        case dateAdded
        case contentRating
        case playCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        album = try container.decode(String.self, forKey: .album)
        artist = try container.decode(String.self, forKey: .artist)
        link = try container.decode(String.self, forKey: .link)
        genre = try container.decode(String.self, forKey: .genre)
        itunesId = try container.decode(Int.self, forKey: .itunesId)
        artworkTemplate = try container.decodeIfPresent(String.self, forKey: .artworkTemplate) ?? ""
        libraryId = try container.decodeIfPresent(String.self, forKey: .libraryId) ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate) ?? ""
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount) ?? 0
        dateAdded = try container.decodeIfPresent(String.self, forKey: .dateAdded) ?? ""
        contentRating = try container.decodeIfPresent(String.self, forKey: .contentRating) ?? ""
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(album, forKey: .album)
        try container.encode(artist, forKey: .artist)
        try container.encode(link, forKey: .link)
        try container.encode(genre, forKey: .genre)
        try container.encode(itunesId, forKey: .itunesId)
        try container.encode(artworkTemplate, forKey: .artworkTemplate)
        try container.encode(libraryId, forKey: .libraryId)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(releaseDate, forKey: .releaseDate)
        try container.encode(trackCount, forKey: .trackCount)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(contentRating, forKey: .contentRating)
        try container.encodeIfPresent(playCount, forKey: .playCount)
    }
}
