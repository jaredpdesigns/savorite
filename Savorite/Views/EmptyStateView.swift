//
//  EmptyStateView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Label("No Year Selected", systemImage: "music.note.list")
                .font(.largeTitle.bold())
            
            Text("Select a year from the sidebar to view your favorite albums")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EmptyStateView()
}
