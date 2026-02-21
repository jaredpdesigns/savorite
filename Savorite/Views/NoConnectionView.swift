//
//  NoConnectionView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/20/26.
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
        }
        .padding()
    }
}

#Preview {
    NoConnectionView {}
}
