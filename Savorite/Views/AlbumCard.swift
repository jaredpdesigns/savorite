//
//  AlbumCard.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import AppKit
import SwiftUI

struct AlbumCard: View {
    let album: AlbumEntry
    let isExcluded: Bool
    let playCount: Int?  /* Optional play count passed from parent */
    let showPlayCountBadge: Bool  /* Whether to show the play count badge */
    let onToggle: (Bool) -> Void  /* Bool indicates if shift key was held */
    
    private var playCountText: String {
        guard let count = playCount else { return "" }
        return "\(count) \(count == 1 ? "play" : "plays")"
    }
    
    private var accessibilityLabelText: String {
        var label = "\(album.album) by \(album.artist)"
        
        /* Include play count if available */
        if let count = playCount, count > 0 {
            label += ", played \(count) \(count == 1 ? "time" : "times")"
        }
        
        if isExcluded {
            label += ", hidden from export"
        }
        
        return label
    }
    
    private var accessibilityHintText: String {
        isExcluded ? "Double-tap to include in export" : "Double-tap to exclude from export"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack() {
                AsyncImage(url: URL(string: album.cover)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(.quaternary)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                    case .failure:
                        Rectangle()
                            .fill(.quaternary)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .opacity(isExcluded ? 0.25 : 1.0)
                .overlay(alignment: .topLeading) {
                    /* Play count badge in top-left corner with glass effect */
                    if showPlayCountBadge, let count = playCount, count > 0 {
                        Text(playCountText)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                            .accessibilityHidden(true)
                    }
                }
                
                /* Excluded icon centered */
                if isExcluded {
                    Image(systemName: "star.slash.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: isExcluded ? .clear : .black.opacity(0.25), radius: 4, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.album)
                    .font(.headline)
                
                Text(album.artist)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            let isShiftHeld = NSEvent.modifierFlags.contains(.shift)
            onToggle(isShiftHeld)
        }
        .contextMenu {
            Button {
                onToggle(false)
            } label: {
                Label(
                    isExcluded ? "Include in Export" : "Exclude from Export",
                    systemImage: "star.slash.fill"
                ).font(.body)
            }
            
            if let url = URL(string: album.link), !album.link.isEmpty {
                Divider()
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open in Apple Music", systemImage: "music.pages.fill").font(.body)
                }
            }
        }
    }
}

#Preview("Included") {
    AlbumCard(
        album: AlbumEntry(
            album: "SABLE, fABLE",
            artist: "Bon Iver",
            link: "https://music.apple.com/us/album/1791161215",
            genre: "Alternative",
            itunesId: 1791161215,
            artworkTemplate: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/44/95/21/449521a9-3e07-9a15-02be-d1412884e240/51719.jpg/{w}x{h}bb.jpg",
            libraryId: "l.test",
            isFavorite: true,
            releaseDate: "2025-01-17"
        ),
        isExcluded: false,
        playCount: 12,
        showPlayCountBadge: true
    ) { _ in }
        .frame(width: 220)
        .padding()
}

#Preview("Excluded") {
    AlbumCard(
        album: AlbumEntry(
            album: "SABLE, fABLE",
            artist: "Bon Iver",
            link: "https://music.apple.com/us/album/1791161215",
            genre: "Alternative",
            itunesId: 1791161215,
            artworkTemplate: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/44/95/21/449521a9-3e07-9a15-02be-d1412884e240/51719.jpg/{w}x{h}bb.jpg",
            libraryId: "l.test",
            isFavorite: true,
            releaseDate: "2025-01-17"
        ),
        isExcluded: true,
        playCount: nil,
        showPlayCountBadge: false
    ) { _ in }
        .frame(width: 220)
        .padding()
}
