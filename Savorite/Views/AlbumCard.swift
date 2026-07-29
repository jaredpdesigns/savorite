//
//  AlbumCard.swift
//  Savorite
//

import AppKit
import SwiftUI

struct AlbumCard: View {
    let album: AlbumEntry
    let isExcluded: Bool
    let playCount: Int?
    let isArtworkHidden: Bool
    let onToggle: () -> Void
    
    private var artworkURL: URL? {
        guard !album.cover.isEmpty else { return nil }
        return URL(string: album.cover)
    }
    
    private var artworkBackgroundColor: Color {
        Color(appleMusicHex: album.artworkBackgroundHex)
        ?? Color(nsColor: .quaternaryLabelColor)
    }
    
    private var artworkForegroundColor: Color {
        Color(appleMusicHex: album.artworkPrimaryTextHex)
        ?? Color(nsColor: .secondaryLabelColor)
    }
    
    private var playCountText: String {
        guard let count = playCount else { return "" }
        return "\(count) \(count == 1 ? "play" : "plays")"
    }
    
    private var accessibilityLabelText: String {
        var label = "\(album.album) by \(album.artist)"
        
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
    
    private func artworkPlaceholder(isLoading: Bool) -> some View {
        Rectangle()
            .fill(artworkBackgroundColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(artworkForegroundColor)
                } else {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(artworkForegroundColor)
                }
            }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack() {
                Group {
                    if let artworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            switch phase {
                            case .empty:
                                artworkPlaceholder(isLoading: true)
                            case .success(let image):
                                ZStack {
                                    Rectangle()
                                        .fill(artworkBackgroundColor)
                                    
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .opacity(isArtworkHidden ? 0 : 1)
                                }
                                .aspectRatio(1, contentMode: .fit)
                            case .failure:
                                artworkPlaceholder(isLoading: false)
                            @unknown default:
                                artworkPlaceholder(isLoading: false)
                            }
                        }
                    } else {
                        artworkPlaceholder(isLoading: false)
                    }
                }
                .opacity(isExcluded ? 0.25 : 1.0)
                
                if isExcluded {
                    Image(systemName: "star.slash.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: isExcluded ? .clear : .black.opacity(0.25), radius: 4, y: 2)
            
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.album)
                        .font(.headline)
                    
                    Text(album.artist)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
                
                Menu {
                    Button {
                        onToggle()
                    } label: {
                        Label(
                            isExcluded ? "Include in Export" : "Exclude from Export",
                            systemImage: "star.slash.fill"
                        )
                    }
                    
                    if let url = URL(string: album.link), !album.link.isEmpty {
                        Divider()
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("Open in Apple Music", systemImage: "music.pages.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Options for \(album.album)")
                .accessibilityHint("Opens menu to exclude album or open in Apple Music")
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
    }
}

private extension Color {
    init?(appleMusicHex hex: String?) {
        guard
            let hex,
            hex.count == 6,
            let value = UInt64(hex, radix: 16)
        else {
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}
