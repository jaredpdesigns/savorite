//
//  AccessDeniedView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import SwiftUI

struct AccessDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Label("Access Denied", systemImage: "lock.circle.fill")
                .font(.largeTitle.bold())
            
            Text("Savorite needs access to your music library, please enable it in:")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text("System Settings → Privacy & Security → Media & Apple Music")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Media") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Opens Privacy settings where you can enable music library access")
        }
        .padding()
    }
}

#Preview {
    NavigationSplitView {
        AccessDeniedView()
    } detail: {
        Text("Detail")
    }
}
