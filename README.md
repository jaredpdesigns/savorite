# Savorite

A macOS app to save and export your favorite albums from Apple Music, with play count tracking to discover your most-listened albums.

## Features

- **Access Your Favorites**: Connects to your Apple Music library and displays albums you've marked as favorites
- **Organized by Year**: Albums are grouped by release year for easy browsing
- **Top Albums**: View your most-listened albums per year, filtered by play count (5+ listens)
- **Play Count Tracking**: Automatically calculates album play counts using median track plays
- **Smart Refresh**:
  - Quick refresh for play counts only
  - Full refresh to check for new favorites
- **Search**: Filter albums by title or artist name
- **Export Options**:
  - Copy as JSON to clipboard (includes play counts)
  - Copy as plain text list
  - Copy as Markdown list
  - Download as JSON file

## How It Works

### Viewing Your Music

- **All Albums**: Browse all favorite albums from a year
- **Top Albums**: See your most-listened albums (5+ plays) to create year-end lists
- Years with fewer than 10 favorites are hidden (except current year)

### Refreshing Data

- **Refresh Play Counts**: Fast update of listening statistics
- **Check for New Favorites**: Full library scan for newly favorited albums
- Data is cached locally for quick app startup
