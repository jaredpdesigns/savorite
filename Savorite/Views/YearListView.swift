//
//  YearListView.swift
//  Savorite
//

import SwiftUI

struct YearListView: View {
    @Environment(\.colorScheme) private var colorScheme
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
                    Image("SavoriteIconFlat")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 34)
                        .accessibilityHidden(true)
                        .foregroundStyle(Color.primary)
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
                    let isSelectedInDarkMode = selectedYear == 0 && colorScheme == .dark
                    
                    HStack {
                        Text("All Favorites")
                            .foregroundStyle(isSelectedInDarkMode ? Color.black : Color.primary)
                    }
                    .tag(0)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("All Favorites, \(count) \(label)")
                } else {
                    ForEach(filteredYears, id: \.self) { year in
                        let matches = matchingAlbumsCount(year)
                        // Hide years that have 0 search matches when searching
                        if searchText.isEmpty || matches > 0 {
                            let albumCount = searchText.isEmpty
                            ? (albumsByYear[year]?.count ?? 0)
                            : matches
                            let countLabel = searchText.isEmpty ? "albums" : "matches"
                            let yearLabel = year == 0 ? "Unknown Year" : String(year)
                            let isSelectedInDarkMode = selectedYear == year && colorScheme == .dark
                            HStack {
                                Text(yearLabel)
                                    .font(.headline)
                                    .foregroundStyle(isSelectedInDarkMode ? Color.black : Color.primary)
                                Spacer()
                                if searchText.isEmpty {
                                    Text("\(albumsByYear[year]?.count ?? 0) albums")
                                        .foregroundStyle(isSelectedInDarkMode ? Color.black.opacity(0.8) : Color.secondary)
                                        .font(.body)
                                } else {
                                    Text("\(matches) matches")
                                        .foregroundStyle(isSelectedInDarkMode ? Color.black.opacity(0.8) : Color.secondary)
                                        .font(.body)
                                }
                            }
                            .tag(year)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(yearLabel), \(albumCount) \(countLabel)")
                        }
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
