# Savorite

A macOS app to save and export your favorite albums from Apple Music.

## Features

- **Access Your Favorites**: Connects to your Apple Music library and displays albums you've marked as favorites
- **Organized by Year**: Albums are grouped by release year for easy browsing
- **Search**: Filter albums by title or artist name
- **Export Options**:
  - Download as JSON file
  - Copy as JSON to clipboard
  - Copy as plain text list
  - Copy as Markdown list
- **Selective Export**: Click albums to exclude them from export (shift+click for range selection)
- **Local Caching**: Album data is cached locally for fast subsequent launches
- **Accessibility**: Full VoiceOver support with descriptive labels

## Requirements

- macOS 15.0 or later
- Apple Music subscription with favorited albums

## Setup

1. Open `Savorite.xcodeproj` in Xcode
2. Ensure the following capabilities are enabled:
   - Media Library
   - App Sandbox with:
     - Outgoing Connections (Client)
     - User Selected File: Read/Write
3. Add `Privacy - Media Library Usage Description` to Info.plist
4. Build and run

## Usage

1. Grant music library access when prompted
2. The app will fetch your favorited albums from Apple Music
3. Browse albums by year in the sidebar
4. Click albums to toggle their inclusion in exports
5. Use the Export menu to download or copy album data

## Export Formats

**JSON**: Structured data with album metadata including iTunes ID, artwork URLs, genre, release date, track count, and more.

**Plain Text**: Simple list format:
```
"Album Name" by Artist Name: https://music.apple.com/...
```

**Markdown**: Link-formatted list:
```
- "[Album Name](https://music.apple.com/...)" by Artist Name
```

## License

MIT
