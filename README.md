
# debapps - Bash scripts to simplify Debian Linux app installations.

- These scripts will work with most Debian based Linux distros such as Ubuntu, Kali and Pop!_OS.
- Includes menu options to both installing and also removing the applications.

### USAGE

⚠️ **SECURITY WARNING**: Remote script execution methods (Options 1 and 3 below) download and execute code with root privileges. This poses significant security risks. Always review scripts before execution.

Option 1. **(NOT RECOMMENDED - SECURITY RISK)** Remote execution:
```
# WARNING: This downloads and executes remote code with sudo privileges
# Only use if you trust the source and have verified the script content
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/bradsec/debapps/main/debapps.sh)"
```

Option 2. **(RECOMMENDED)** Clone the repo and run locally:
```terminal
# Download and review the code first
git clone https://github.com/bradsec/debapps.git
# Review the script content before execution
less ./debapps/debapps.sh
# Run the script
sudo bash ./debapps/debapps.sh
```

Option 3. **(NOT RECOMMENDED - SECURITY RISK)** Remote execution of specific scripts:
```
# WARNING: This downloads and executes remote code with sudo privileges
# Only use if you trust the source and have verified the script content
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/bradsec/debapps/main/src/passwordapps.sh)"
```

**Security Best Practices:**
- Always review script contents before execution
- Use Option 2 (local clone) whenever possible
- Verify file hashes when provided
- Run scripts in a test environment first

### Example of main menu:
```terminal

██████╗ ███████╗██████╗  █████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ██║█████╗  ██████╔╝███████║██████╔╝██████╔╝███████╗
██║  ██║██╔══╝  ██╔══██╗██╔══██║██╔═══╝ ██╔═══╝ ╚════██║
██████╔╝███████╗██████╔╝██║  ██║██║     ██║     ███████║
╚═════╝ ╚══════╝╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝

 Bash scripts to simplify Linux app installations.

 i OS Detected: Debian GNU/Linux 13 (trixie) x86_64
 i Hardware Detected: Intel(R) Core(TM) i7-10850H CPU @ 2.70GHz

 Application Categories

 Use arrow keys or j/k. Press Enter to select.

 >  1. Password Manager apps
    2. Note apps
    3. Messenger apps
    4. Office apps
    5. Collaboration apps
    6. Web Browsers and Web API Tools
    7. Code Editor apps
    8. Burp Suite apps
    9. Managed DebApps installs
   10. Check manifest download links
   11. Exit

```

Menus support arrow-key navigation in interactive terminals. Use the up/down arrow keys or `j`/`k`, then press Enter to select. If no controlling terminal is available, menus fall back to numeric input.

Scriptname | Compatability | Applications
---|---|---
<a href="https://github.com/bradsec/debapps/tree/main/src/passwordapps.sh" target="_blank">passwordapps.sh</a> | Debian/Ubuntu | Bitwarden, KeePassXC |
<a href="https://github.com/bradsec/debapps/tree/main/src/noteapps.sh" target="_blank">noteapps.sh</a> | Debian/Ubuntu | Joplin, Standard Notes, Obsidian |
<a href="https://github.com/bradsec/debapps/tree/main/src/messengerapps.sh" target="_blank">messengerapps.sh</a> | Debian/Ubuntu | Signal, Threema
<a href="https://github.com/bradsec/debapps/tree/main/src/officeapps.sh" target="_blank">officeapps.sh</a> | Debian/Ubuntu | OnlyOffice, LibreOffice
<a href="https://github.com/bradsec/debapps/tree/main/src/collabapps.sh" target="_blank">collabapps.sh</a> | Debian/Ubuntu | Discord, Slack, Zoom, Microsoft Teams
<a href="https://github.com/bradsec/debapps/tree/main/src/webapps.sh" target="_blank">webapps.sh</a> | Debian/Ubuntu | Firefox, Google Chrome, Brave, TOR Browser, Postman API Tool
<a href="https://github.com/bradsec/debapps/tree/main/src/codeeditapps.sh" target="_blank">codeeditapps.sh</a> | Debian/Ubuntu | Sublime-Text 3 & 4, Visual Studio Codium, Microsoft Visual Studio Code (VSCode), Cursor ai
<a href="https://github.com/bradsec/debapps/tree/main/src/burpapps.sh" target="_blank">burpapps.sh</a> | Debian/Ubuntu | PortSwigger Burp Suite Community or Professional Editions - GUI Installer

### Notes
* **As the scripts need to install files and change permissions outside of user home directories they require `sudo` or superuser priviledges.**
* Scripts inherit common functions from the imported <a href="https://github.com/bradsec/debapps/tree/main/src/templates" target="_blank">templates</a>.
* Menu options for application installation and removal are provided in each script.
* Installers avoid Snap and Flatpak. The preferred order is official apt repository, official `.deb`, then AppImage/archive/upstream installer when no better Debian-native method is available.
* File hashes (MD5, SHA1, SHA256) will be shown during installation for any downloaded packages or files for security comparison with the publisher.
* **UPGRADING** For applications which do not auto-update or update by running `sudo apt update && sudo apt upgrade`, just re-run the install option/script to upgrade the package.
* Most of the Debian app installers fetch x64 sources, the script sources may need modification to run on other system architecture such as x86 (32-bit) or arm processors.

### Manifest-driven installers

Shared app metadata lives in `src/app-manifest.sh`. Menu scripts can import `src/templates/apps.tmpl.sh`, call `import_app_manifest`, and then install or remove apps with:

```terminal
install_manifest_app bitwarden
remove_manifest_app bitwarden
```

Each manifest entry declares an app id, display name, install type, package name, optional download resolver, repository metadata, and install-specific flags. Repository-backed installers for Signal, VSCodium, OnlyOffice, Firefox, Brave, and VS Code use the `apt-repo` path. Direct `.deb` installers for Bitwarden, Cursor, Discord, Slack, Zoom, Threema, and Google Chrome also use this path. Joplin, Standard Notes, and Obsidian remain AppImage installers; KeePassXC uses the distro apt package.

The main menu and migrated category menus include checks that resolve the current download URL or apt repository metadata and validate reachability without downloading packages or installing applications:

```terminal
validate_manifest_app bitwarden
validate_manifest_apps discord slack zoom
validate_all_manifest_apps
```

Manifest installs are recorded in `$HOME/.debapps_config` for the invoking user. The main menu includes "Managed DebApps installs" to show recorded applications and reinstall/upgrade or remove them through the manifest handlers. This tracks apps installed through `install_manifest_app`; bespoke installers can be migrated into the manifest layer when they need the same management behavior.

Remaining migration work is mostly for archive and bespoke installers: Postman, Tor Browser fallback handling, and Burp Suite installer validation.

### Troubleshooting

- If an install fails. Try running the remove app option then try install again. If it continues to fail raise an issue with details including hardware and OS version details.
- Some GNOME desktop icons may not appear until GNOME is shell is reloaded. Try logging out and back in.
