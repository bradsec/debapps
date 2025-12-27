# DEBAPPS - Debian Application Installer

Simple all in one installation scripts for Debian applications

![Version](https://img.shields.io/badge/version-2.0-green)
![License](https://img.shields.io/badge/license-MIT-blue)
![Shell](https://img.shields.io/badge/shell-bash-brightgreen)

```terminal
                                                                          
                   ____  __________  ___    ____  ____  _____             
                  / __ \/ ____/ __ )/   |  / __ \/ __ \/ ___/             
                 / / / / __/ / __  / /| | / /_/ / /_/ /\__ \              
                / /_/ / /___/ /_/ / ___ |/ ____/ ____/___/ /              
               /_____/_____/_____/_/  |_/_/   /_/    /____/               
                                                                          
                                                                          
                    Debian Application Installer v2.0                     
             Bash scripts to simplify Linux app installations                     
                                                                          
Choose a category:                                                            
                                                                              
> Password Manager Apps - Secure password management applications             
  Note Apps - Note taking and knowledge management                            
  Messenger Apps - Secure messaging applications                              
  Office Apps - Office productivity suites                                    
  Collaboration Apps - Team communication and video conferencing              
  Web Browsers and Web API Tools - Web browsers and API development tools     
  Code Editor Apps - Text editors and integrated development environments     
  Burp Suite Apps - Web application security testing                          
  System Apps - System tools and utilities                                    
  Exit                                                                        
                                                                                               
```

## Features

- **Modern Gum-based UI** with retro CRT green terminal aesthetic
- **JSON-driven configuration** - easily add new applications
- **Multi-method detection** - detects apps installed via apt, snap, flatpak, AppImage, or manual installation
- **Dynamic version resolution** - always fetches latest versions, no hardcoded version numbers
- **SQLite database** - tracks installed applications and files
- **Multiple install methods** - supports .deb, AppImage, apt repositories, tarballs, and installers
- **Smart dependency handling** - automatically installs required dependencies
- **Desktop integration** - properly integrates AppImages with desktop search and menus
- **Security hardened** - SQL injection protection, input validation, safe file operations

## Supported Applications

### Password Managers
- Bitwarden - Open source password manager with cloud sync
- KeePassXC - Offline password manager with strong encryption

### Note Taking
- Joplin - Open source note taking with sync
- Standard Notes - Encrypted note taking with extensions
- Obsidian - Knowledge base on local markdown files

### Messaging
- Signal - Private messenger with end-to-end encryption
- Threema - Swiss secure messenger                              
- Telegram Desktop - Fast and secure messaging app with cloud sync   

### Office Suites
- OnlyOffice - Free office suite compatible with Microsoft Office
- LibreOffice - Free and open source office suite

### Collaboration
- Discord - Voice, video, and text communication
- Slack - Team collaboration and messaging
- Zoom - Video conferencing and webinars

### Web Browsers & Tools
- Firefox - Fast, private and secure browser from Mozilla
- Google Chrome - Fast and secure browser from Google
- Brave - Privacy-focused browser with ad blocking
- Tor Browser - Anonymous browsing through Tor network
- Postman - API development and testing platform

### Code Editors
- Sublime Text - Sophisticated text editor
- Visual Studio Code - Free source code editor from Microsoft
- VSCodium - Open source VS Code without Microsoft telemetry
- Cursor AI - AI-powered code editor built on VS Code

### Security Tools
- Burp Suite Community - Free web security testing tool
- Burp Suite Professional - Professional web security testing

### System Tools
- Docker - Platform for building, running, and shipping applications in containers 

## Installation

### Prerequisites

DEBAPPS will automatically install required dependencies:
- `jq` - JSON processor
- `gum` - Terminal UI toolkit
- `sqlite3` - Database engine
- `curl` - URL transfer tool
- `wget` - File downloader

### Quick Start

```bash
# Clone the repository
git clone https://github.com/bradsec/debapps.git
cd debapps

# Make executable
chmod +x debapps

# Run (will request sudo for installations)
./debapps
```

### Usage

```bash
./debapps              # Interactive mode (recommended)
./debapps --version    # Show version information
./debapps --help       # Show help message
```

## How It Works

### Installation Flow

1. **Category Selection** - Choose from Password Managers, Note Apps, Browsers, etc.
2. **App Selection** - Browse available applications in the category
3. **Action Selection** - Install, Remove, Reinstall, Upgrade, or View Info
4. **Authentication** - Provide sudo password when needed
5. **Automatic Installation** - DEBAPPS handles download, installation, and configuration
6. **Desktop Integration** - Applications appear in your desktop menu automatically

### Install Methods

#### AppImage
- Downloads latest AppImage from GitHub releases
- Extracts icons and desktop files
- Creates symbolic links in `/usr/sbin`
- Installs icons in hicolor theme
- Updates desktop database for menu integration
- Supports automatic upgrades

#### DEB Packages
- Downloads .deb files from direct URLs or GitHub releases
- Installs via `dpkg` with automatic dependency fixing
- Tracks installation in database
- Supports removal and reinstallation

#### APT Repositories
- Adds GPG keys and repository sources
- Installs packages from official repositories
- Handles repository preferences and conflicts
- Integrates with system package manager

#### Tarballs
- Downloads and extracts compressed archives
- Creates symbolic links and desktop entries
- Supports various compression formats (tar.gz, tar.xz)
- Proper cleanup on removal

#### Installers
- Executes .sh installer scripts (Burp Suite)
- Supports unattended installation
- Runs official uninstaller on removal

## Adding New Applications

### Configuration Structure

Applications are defined in `config/apps.json`. Each app requires:

```json
{
  "id": "app-identifier",
  "name": "Application Name",
  "description": "Brief description of the app",
  "install_method": "appimage|deb|apt_repo|tarball|installer",
  "source": {
    "type": "source_type",
    ...source-specific fields...
  },
  "detection": {
    "binaries": ["binary-name"],
    "desktop_files": ["app.desktop"],
    "apt_packages": ["package-name"],
    "snap_packages": ["snap-name"],
    "flatpak_packages": ["flatpak.id"]
  },
  "install_location": "/opt/appname",
  "dependencies": ["libfuse2", "other-deps"]
}
```

### Source Types

#### 1. GitHub Release (AppImage/DEB)

```json
"source": {
  "type": "github_release",
  "repo": "owner/repository",
  "asset_pattern": "AppName-{VERSION}-x86_64.AppImage",
  "version_prefix": "v"
}
```

- Automatically fetches latest release from GitHub API
- `{VERSION}` is replaced with actual version number
- `version_prefix` is stripped from tag name (optional)

#### 2. Direct Download

```json
"source": {
  "type": "direct_download",
  "url": "https://example.com/download/app-latest.deb"
}
```

- Direct download URL (use for "latest" URLs)
- Version is marked as "latest"

#### 3. APT Repository

```json
"source": {
  "type": "apt_repository",
  "key_url": "https://example.com/keys/signing-key.gpg",
  "key_name": "example.keyring",
  "repo_line": "https://example.com/apt stable main",
  "repo_file": "example.list",
  "package_name": "package-name"
}
```

- Adds APT repository with GPG key
- Installs package from repository

#### 4. Burp Suite Installer

```json
"source": {
  "type": "burp_installer",
  "edition": "community|pro",
  "base_url": "https://portswigger.net/burp/releases"
}
```

- Fetches latest version from PortSwigger
- Downloads appropriate Linux installer
- Supports both community and professional editions

#### 5. Cursor AI

```json
"source": {
  "type": "cursor_latest",
  "url": "https://api2.cursor.sh/updates/download/golden/linux-x64/cursor/latest"
}
```

- Always downloads latest stable release
- Fetches version info from API

### Example: Adding a New Application

Let's add a new AppImage application called "Example App":

```json
{
  "id": "example-app",
  "name": "Example App",
  "description": "Example application for demonstration",
  "install_method": "appimage",
  "source": {
    "type": "github_release",
    "repo": "example/example-app",
    "asset_pattern": "ExampleApp-{VERSION}-x86_64.AppImage",
    "version_prefix": "v"
  },
  "detection": {
    "binaries": ["example-app"],
    "desktop_files": ["example-app.desktop"]
  },
  "install_location": "/opt/example-app",
  "dependencies": ["libfuse2"]
}
```

Add this to the appropriate category in `config/apps.json`, then run DEBAPPS - your new app will appear automatically!

### Categories

Applications are organized by category:

- `password` - Password Manager Apps
- `notes` - Note Apps
- `messenger` - Messenger Apps
- `office` - Office Apps
- `collab` - Collaboration Apps
- `web` - Web Browsers and Web API Tools
- `code` - Code Editor Apps
- `burp` - Burp Suite Apps

To add a new category, create a new object in the `categories` array:

```json
{
  "id": "new-category",
  "name": "New Category Name",
  "description": "Category description",
  "apps": [
    ...app definitions...
  ]
}
```

## Architecture

### Directory Structure

```
debapps/
├── debapps                    # Main executable
├── config/
│   └── apps.json             # Application configuration
├── core/
│   ├── common.sh             # Core utilities
│   ├── package-manager.sh    # APT/dpkg operations
│   └── appimage-handler.sh   # AppImage operations
├── lib/
│   ├── config.sh             # Configuration loader
│   ├── db.sh                 # Database operations
│   ├── detect.sh             # Application detection
│   ├── ui.sh                 # User interface (Gum)
│   ├── version.sh            # Version resolution
│   └── installers/
│       ├── appimage-installer.sh
│       ├── deb-installer.sh
│       ├── apt-installer.sh
│       ├── tarball-installer.sh
│       └── burp-installer.sh
├── data/
│   ├── installed-apps.db     # SQLite database
│   └── cache/                # Version cache (15 min TTL)
└── test-links.sh             # Link validation tool
```

### Database Schema

```sql
CREATE TABLE installed_apps (
    app_id TEXT PRIMARY KEY,
    app_name TEXT NOT NULL,
    install_method TEXT NOT NULL,
    version TEXT,
    install_date INTEGER,
    install_location TEXT,
    metadata TEXT
);

CREATE TABLE install_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_type TEXT,
    FOREIGN KEY(app_id) REFERENCES installed_apps(app_id) ON DELETE CASCADE
);
```

## Testing

### Test Download Links

```bash
# Quick test (validates URL format only)
./test-links.sh --quick

# Full test (validates connectivity - slow)
./test-links.sh
```

This validates all download URLs in the configuration file.

### Manual Testing Checklist

- [ ] Install app from each category
- [ ] Verify app appears in desktop menu
- [ ] Launch app from desktop
- [ ] Remove app via DEBAPPS
- [ ] Verify clean removal (no leftover files)
- [ ] Reinstall app
- [ ] Upgrade app to latest version

## Security

### Security Features

- **SQL Injection Protection** - All database inputs are sanitized
- **Input Validation** - App IDs, package names, and paths are validated
- **Path Traversal Prevention** - File paths are validated before operations
- **URL Validation** - Only http/https URLs are allowed
- **Timeout Protection** - Network operations have timeouts
- **Safe Temp Files** - Uses mktemp for race-condition-free temp files
- **Privilege Separation** - Only requests sudo when needed

### Security Best Practices

1. **Always verify downloads** - Check download sources in `config/apps.json`
2. **Review permissions** - Applications request only necessary permissions
3. **Keep updated** - Run upgrades regularly
4. **Audit logs** - Check `/var/log/debapps-security.log` (future feature)
5. **Report issues** - File security issues at GitHub

## Troubleshooting

### Common Issues

#### App doesn't appear in desktop menu

**Solution:** Log out and log back in, or run:
```bash
update-desktop-database /usr/share/applications/
gtk-update-icon-cache -f -t /usr/share/icons/hicolor/
```

#### AppImage won't execute

**Solution:** Install libfuse2:
```bash
sudo apt install libfuse2
```

#### Download fails

**Solutions:**
1. Check internet connection
2. Verify URL in `config/apps.json` is current
3. Clear version cache: `rm -rf data/cache/*`
4. Try manual download to test URL

#### Database errors

**Solution:** Reinitialize database:
```bash
rm data/installed-apps.db
./debapps
```

#### Permission denied

**Solution:** DEBAPPS needs sudo for installations:
```bash
./debapps
# Enter password when prompted
```


## License

MIT License - see LICENSE file for details
