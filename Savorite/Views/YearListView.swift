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
    @Binding var sidebarGrouping: SidebarGrouping
    let allMatchingCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedYear) {
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
                
                HStack {
                    Text("\(totalFavorites) Favorite Albums")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Picker("Grouping", selection: $sidebarGrouping) {
                            Text("Group by Year").tag(SidebarGrouping.byYear)
                            Text("No Grouping").tag(SidebarGrouping.none)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.large)
                    }
                    .menuIndicator(.hidden)
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                if sidebarGrouping == .none {
                    let count = searchText.isEmpty ? totalFavorites : allMatchingCount
                    let label = searchText.isEmpty ? "albums" : "matches"
                    
                    HStack {
                        Text("All Favorites")
                    }
                    .tag(0)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("All Favorites, \(count) \(label)")
                } else {
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
                }
            }
            .listStyle(.sidebar)
            
            if let lastUpdated = lastUpdated {
                VStack(spacing: 16) {
                    Divider()
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 16)
                
            }
        }
    }
}
