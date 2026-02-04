//
//  NoFavoritesView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import SwiftUI

struct NoFavoritesView: View {
    let onRefresh: () async -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Label("No Favorite Albums Found", systemImage: "star.slash.fill")
                .font(.largeTitle.bold())
            
            Text("Favorite albums in Apple Music to see them here")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await onRefresh()
                }
            } label: {
                Label("Refresh Library", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    NoFavoritesView {
        // Preview action
    }
}
