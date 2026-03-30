# icloudpd-tui

Interactive TUI wrapper for [iCloud Photos Downloader](https://github.com/icloud-photos-downloader/icloud_photos_downloader). Browse your iCloud photo library by year/month, check disk space, and selectively download photos and videos — all from the terminal.

## Features

- **Browse & Download** — view your library organized by year/month with file counts, select specific folders, choose photos/videos/all, and download
- **Quick Sync** — fast incremental backup of new photos using `--until-found`
- **Disk Status** — check backup drive space and file counts at a glance
- **Rescan** — check iCloud for recently added photos
- **Dark Forest theme** — styled fzf interface with keyboard hints
- **Safe interrupts** — Ctrl+C stops cleanly, already-downloaded files are kept
- **Stall detection** — kills hung scans with clear error messages
- **Size estimates** — calibrated from your actual file sizes

## Requirements

- [icloudpd](https://github.com/icloud-photos-downloader/icloud_photos_downloader) (iCloud Photos Downloader)
- [fzf](https://github.com/junegunn/fzf) (fuzzy finder)
- [gawk](https://www.gnu.org/software/gawk/) (GNU awk)
- Linux or macOS

## Installation

**One-liner install:**

```bash
# macOS
brew install bash fzf gawk && pipx install icloudpd && git clone https://github.com/pnaaberi/icloudpd-tui.git && cd icloudpd-tui && chmod +x icloudpd-tui && ./icloudpd-tui

# Arch / CachyOS
sudo pacman -S fzf gawk && pipx install icloudpd && git clone https://github.com/pnaaberi/icloudpd-tui.git && cd icloudpd-tui && chmod +x icloudpd-tui && ./icloudpd-tui

# Ubuntu / Debian
sudo apt install fzf gawk && pipx install icloudpd && git clone https://github.com/pnaaberi/icloudpd-tui.git && cd icloudpd-tui && chmod +x icloudpd-tui && ./icloudpd-tui
```

## Usage

```bash
# Launch the interactive TUI
./icloudpd-tui

# Quick sync (download new photos, stop after 50 consecutive duplicates)
./icloudpd-tui 50

# Re-run setup
./icloudpd-tui --setup

# Show help
./icloudpd-tui --help
```

On first run, you'll be prompted to configure your Apple ID, download directory, and mount point. Settings are saved to `~/.config/icloudpd-tui/config`.

## Configuration

Settings are loaded in this priority order:

1. **CLI arguments** (`--help`, `--setup`, numeric quick-sync)
2. **Environment variables**
3. **Config file** (`~/.config/icloudpd-tui/config`)
4. **Interactive prompt** (first run)

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ICLOUD_USERNAME` | Apple ID email | *(prompted on first run)* |
| `ICLOUD_TARGET_DIR` | Download directory | `~/icloud-photos` |
| `ICLOUD_MOUNT_POINT` | Mount point to verify | *(auto-detected)* |
| `ICLOUD_FOLDER_STRUCTURE` | Folder template | `{:%Y/%m}` |
| `ICLOUD_SIZE` | Image size (`original`, `medium`, `thumb`) | `original` |
| `SCAN_RECENT` | How many recent photos to check | `500` |
| `ICLOUDPD` | Path to icloudpd binary | `icloudpd` |

## How It Works

- **Browse view** shows your local backup organized by year/month, with file counts for photos and videos. The "new" column shows files found by the recent scan that haven't been downloaded yet.
- **Quick Sync** uses icloudpd's `--until-found` flag, which scans from newest to oldest and stops after finding N consecutive already-downloaded files. This is the fastest way to grab new photos.
- **Browse & Download** uses date range filters (`--skip-created-before`/`--skip-created-after`). Note: icloudpd always enumerates the full iCloud library before filtering, so this takes longer than Quick Sync for grabbing new files. It's most useful for re-syncing specific time periods.

## Known Limitations

- icloudpd cannot efficiently list the full iCloud library contents. The browse view is built from local files (your backup) plus a quick recent-files check.
- Date-filtered downloads still trigger a full library enumeration by icloudpd. This is an upstream limitation.
- On macOS, CPU-based stall detection is not available (falls back to log file monitoring only).

## License

MIT License. See [LICENSE](LICENSE).

## Acknowledgments

This project would not exist without:

- **[icloudpd](https://github.com/icloud-photos-downloader/icloud_photos_downloader)** — the iCloud Photos Downloader that does all the real work. Originally created by [Nathan Broadbent](https://github.com/ndbroadbent), now maintained by the [icloud-photos-downloader](https://github.com/icloud-photos-downloader) community. MIT License.
- **[fzf](https://github.com/junegunn/fzf)** — the fuzzy finder that powers the interactive UI. Created by [Junegunn Choi](https://github.com/junegunn). MIT License.

This TUI is just a friendly front door — all credit for the iCloud integration goes to the icloudpd team.
