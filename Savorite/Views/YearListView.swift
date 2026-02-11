//
//  YearListView.swift
//  Savorite
//
//  Created by Jared Pendergraft on 2/3/26.
//

import SwiftUI

struct YearListView: View {
    @Binding var selectedYear: Int?
    let filteredYears: [Int]
    let albumsByYear: [Int: [AlbumEntry]]
    let totalFavorites: Int
    let lastUpdated: Date?
    let searchText: String
    let matchingAlbumsCount: (Int) -> Int
    
    var body: some View {
        List(selection: $selectedYear) {
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text("Savorite")
                } icon: {
                    Image("SavoriteIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 34)
                        .accessibilityHidden(true)
                        .foregroundStyle(.red)
                }
                .font(.largeTitle.bold())
                Text("\(totalFavorites) favorite albums")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            
            Divider()
            
            ForEach(filteredYears, id: \.self) { year in
                let albumCount = searchText.isEmpty
                ? (albumsByYear[year]?.count ?? 0)
                : matchingAlbumsCount(year)
                let countLabel = searchText.isEmpty ? "albums" : "matches"
                
                HStack {
                    Text(String(year))
                        .font(.headline)
                    Spacer()
                    if searchText.isEmpty {
                        Text("\(albumsByYear[year]?.count ?? 0) albums")
                            .foregroundStyle(.secondary)
                            .font(.body)
                    } else {
                        Text("\(matchingAlbumsCount(year)) matches")
                            .foregroundStyle(.secondary)
                            .font(.body)
                    }
                }
                .tag(year)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(year), \(albumCount) \(countLabel)")
            }
            
            if let lastUpdated = lastUpdated {
                Divider()
                Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
        }
        .listStyle(.sidebar)
    }
}
