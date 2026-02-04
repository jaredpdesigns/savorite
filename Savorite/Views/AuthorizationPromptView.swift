//
//  AuthorizationPromptView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import SwiftUI

struct AuthorizationPromptView: View {
    let onAuthorize: () async -> Void

    var body: some View {
        VStack(spacing: 24) {
            Label {
                Text("Savorite")
            } icon: {
                Image("SavoriteIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 34)
                    .accessibilityHidden(true)
            }
            .font(.largeTitle.bold())

            Text("Access your favorite albums from Apple Music and export them as JSON, plain text, or Markdown")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Music Access") {
                Task {
                    await onAuthorize()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Opens system dialog to grant music library access")
        }
        .padding()
    }
}

#Preview {
    NavigationSplitView {
        AuthorizationPromptView {
            // Preview action
        }
    } detail: {
        Text("Detail")
    }
}
