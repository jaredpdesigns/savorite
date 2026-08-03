//
//  AuthorizationPromptView.swift
//  Savorite
//

import SwiftUI

struct AuthorizationPromptView: View {
    let onAuthorize: () async -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Label {
                Text("Savorite")
            } icon: {
                Image("SavoriteIconFlat")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 34)
                    .accessibilityHidden(true)
                    .foregroundStyle(.red)
            }
            .font(.largeTitle.bold())
            
            Text("Access your favorite albums from Apple Music and export them as JSON, plain text, or Markdown.\nTo begin, you must allow Savorite access to your Apple Music library.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Continue") {
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
    AuthorizationPromptView {}
}
