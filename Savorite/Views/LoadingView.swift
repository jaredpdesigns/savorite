//
//  LoadingView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import SwiftUI

struct LoadingView: View {
    let currentCount: Int
    let totalCount: Int

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

            if totalCount > 0 {
                Text("Fetching \(totalCount.formatted()) albums")
                    .font(.body)
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(currentCount), total: Double(totalCount))
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 200)
                    .accessibilityLabel("Loading progress")
                    .accessibilityValue("\(currentCount) of \(totalCount) albums")
            } else {
                ProgressView()
                    .accessibilityLabel("Loading")
                Text("Connecting to Apple Music...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview("Connecting") {
    LoadingView(currentCount: 0, totalCount: 0)
}

#Preview("Loading Progress") {
    LoadingView(currentCount: 1250, totalCount: 3605)
}
