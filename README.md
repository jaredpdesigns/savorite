# Savorite

A macOS app to save and export your favorite albums from Apple Music, with play count tracking to discover your most-listened albums.

## Features

- **Access Your Favorites**: Connects to your Apple Music library and displays albums you've marked as favorites
- **Organized by Year**: Albums are grouped by release year for easy browsing
- **Top Albums**: View your most-listened albums per year, filtered by play count (5+ listens)
  - Visual play count badges show listen counts at a glance
- **Smart Play Count Tracking**: Calculates album play counts
  - Accounts for skipped tracks (intros, interludes) without inflating counts
  - Requires 50% of tracks played to qualify as an album listen
- **Interactive Album Management**:
  - Click albums to exclude/include from exports
  - Shift-click for range selection
  - Right-click for context menu with quick actions
  - Open albums directly in Apple Music
- **Search**: Filter albums by title or artist name across all years
- **Export Options**:
  - Copy as JSON to clipboard
  - Copy as plain text list
  - Copy as Markdown list
  - Download as JSON file

## How It Works

### Viewing Your Music

- **All Albums**: Browse all favorite albums from a year
- **Top Albums**: See your most-listened albums (5+ plays) with visual play count badges
- Years with fewer than 10 favorites are hidden (except current year)
- Quick search across all albums and artists

### Managing Your Collection

- **Exclude Albums**: Click any album to exclude it from exports
- **Range Selection**: Shift-click to select multiple albums at once to exclude
- **Open in Apple Music**: Right-click any album and select "Open in Apple Music"

### Refreshing Data

- **Refresh**: Updates your library with new favorites and refreshes all play counts
- Data is cached locally for quick app startup
- Play counts are calculated from actual listening data, not simple averages
