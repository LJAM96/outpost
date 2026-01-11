# Output

A native macOS application for managing rclone cloud storage - browse, download, and upload files to any rclone remote.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)

## Features

- 📂 **Browse Remotes** - Navigate files and folders in any configured rclone remote
- ⬇️ **Download Files** - Download files and folders from remotes
- ⬆️ **Upload Files** - Upload via file picker or drag & drop
- ⚙️ **Config Selection** - Switch between rclone configuration files
- 📊 **Transfer Queue** - Track uploads/downloads with progress

## Requirements

- macOS 13.0 (Ventura) or later
- [rclone](https://rclone.org/) installed via Homebrew

```bash
brew install rclone
rclone config  # Configure your remotes
```

## Installation

1. Clone the repository
2. Open `Output.xcodeproj` in Xcode
3. Build and run (⌘R)

## Usage

1. **Launch Output** - The rclone daemon starts automatically
2. **Select a remote** from the sidebar
3. **Browse files** - Double-click folders to navigate
4. **Download** - Select files and click Download
5. **Upload** - Click Upload or drag files into the browser

## Architecture

Output uses rclone's [Remote Control API](https://rclone.org/rc/) for operations:

```
┌───────────────┐     ┌────────────┐     ┌─────────────┐
│   Output App  │────▶│ rclone rcd │────▶│   Remotes   │
│  (SwiftUI)    │◀────│  (Daemon)  │◀────│ (Cloud/NAS) │
└───────────────┘     └────────────┘     └─────────────┘
```

## Roadmap

- 🔜 Mount remotes as local drives (macFUSE/FUSE-T)
- 🔜 Create/edit remotes in-app
- 🔜 Menu bar integration
- 🔜 Auto-mount on startup

## License

MIT License
# outpost
