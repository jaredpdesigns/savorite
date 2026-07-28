//
//  NoConnectionView.swift
//  Savorite
//

import SwiftUI

struct NoConnectionView: View {
    let onRetry: () async -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Label("No Internet Connection", systemImage: "wifi.slash")
                .font(.largeTitle.bold())
            
            Text("Connect to the internet to update your library")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await onRetry()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Attempts to reconnect to Apple Music and refresh your favorites")
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}
