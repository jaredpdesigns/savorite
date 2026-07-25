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
    let onToggle: () -> Void
    
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
