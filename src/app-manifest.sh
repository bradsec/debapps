#!/usr/bin/env bash

# Application metadata and download resolvers for manifest-driven installers.

function resolve_bitwarden_appimage_url() {
    local latest_release
    latest_release=$(curl -s "https://github.com/bitwarden/clients/releases/" \
        | grep -o '<a[^>]*href="/bitwarden/clients/releases/tag/desktop-v[^"]*"' \
        | head -n 1 \
        | awk -F '"' '{print $2}')
    local version_number
    version_number=$(echo "${latest_release}" | sed -E 's/.*desktop-v([0-9.]+)$/\1/' | tr -d '[:space:]')
    echo "https://github.com/bitwarden/clients/releases/download/desktop-v${version_number}/Bitwarden-${version_number}-x86_64.AppImage"
}

function resolve_bitwarden_deb_url() {
    curl -fsSL "https://api.github.com/repos/bitwarden/clients/releases?per_page=10" \
        | sed -n 's/.*"browser_download_url": "\(.*Bitwarden-.*-amd64\.deb\)".*/\1/p' \
        | head -n 1
}

function resolve_keepassxc_appimage_url() {
    local latest_release
    latest_release=$(curl -s "https://github.com/keepassxreboot/keepassxc/releases" \
        | grep -o '<a[^>]*href="/keepassxreboot/keepassxc/releases/tag/[^"]*"' \
        | head -n 1 \
        | awk -F '"' '{print $2}')
    local version_number
    version_number=$(echo "${latest_release}" | sed -E 's|.*/tag/([0-9.]+)$|\1|' | tr -d '[:space:]')
    echo "https://github.com/keepassxreboot/keepassxc/releases/download/${version_number}/KeePassXC-${version_number}-x86_64.AppImage"
}

function resolve_joplin_appimage_url() {
    local latest_release
    latest_release=$(curl -s "https://github.com/laurent22/joplin/releases" \
        | grep -o '<a[^>]*href="/laurent22/joplin/releases/tag/v[^"]*"' \
        | head -n 1 \
        | awk -F '"' '{print $2}')
    local version_number
    version_number=$(echo "${latest_release}" | sed -E 's/.*v([0-9.]+)$/\1/' | tr -d '[:space:]')
    echo "https://github.com/laurent22/joplin/releases/download/v${version_number}/Joplin-${version_number}.AppImage"
}

function resolve_standardnotes_appimage_url() {
    local latest_release
    latest_release=$(curl -s "https://github.com/standardnotes/app/releases" \
        | grep -o '<a[^>]*href="/standardnotes/app/releases/tag/%40standardnotes%2Fdesktop[^"]*"' \
        | head -n 1 \
        | awk -F '"' '{print $2}')
    local version_number
    version_number=$(echo "${latest_release}" | sed -E 's/.*%40([0-9.]+)$/\1/' | tr -d '[:space:]')
    echo "https://github.com/standardnotes/app/releases/download/%40standardnotes%2Fdesktop%40${version_number}/standard-notes-${version_number}-linux-x86_64.AppImage"
}

function resolve_obsidian_appimage_url() {
    local latest_release
    latest_release=$(curl -s "https://github.com/obsidianmd/obsidian-releases/releases" \
        | grep -o '<a[^>]*href="/obsidianmd/obsidian-releases/releases/tag/v[^"]*"' \
        | head -n 1 \
        | awk -F '"' '{print $2}')
    local version_number
    version_number=$(echo "${latest_release}" | sed -E 's/.*v([0-9.]+)$/\1/' | tr -d '[:space:]')
    echo "https://github.com/obsidianmd/obsidian-releases/releases/download/v${version_number}/Obsidian-${version_number}.AppImage"
}

function get_arch_for_cursor() {
    local arch
    arch=$(uname -m)
    if [[ "${arch}" == "x86_64" ]]; then
        echo "x64"
    elif [[ "${arch}" == "aarch64" ]]; then
        echo "arm64"
    else
        print_message FAIL "Unsupported architecture: ${arch}"
        return 1
    fi
}

function resolve_cursor_appimage_url() {
    local cursor_arch
    local cursor_platform
    cursor_arch=$(get_arch_for_cursor) || return 1
    cursor_platform="linux-${cursor_arch}"
    curl -fsSL "https://www.cursor.com/api/download?platform=${cursor_platform}&releaseTrack=stable" \
        | sed -n 's/.*"downloadUrl":"\([^"]*\)".*/\1/p'
}

function resolve_cursor_deb_url() {
    local cursor_arch
    local cursor_platform
    cursor_arch=$(get_arch_for_cursor) || return 1
    cursor_platform="linux-${cursor_arch}"
    curl -fsSL "https://www.cursor.com/api/download?platform=${cursor_platform}&releaseTrack=stable" \
        | sed -n 's/.*"debUrl":"\([^"]*\)".*/\1/p'
}

function resolve_onlyoffice_source() {
    echo "deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main"
}

function resolve_firefox_source() {
    cat <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
}

function resolve_firefox_pin() {
    cat <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
EOF
}

function resolve_vscode_source() {
    cat <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
}

function resolve_vscode_pin() {
    cat <<'EOF'
Package: code
Pin: origin "packages.microsoft.com"
Pin-Priority: 9999
EOF
}

function resolve_discord_deb_url() {
    echo "https://discord.com/api/download?platform=linux&format=deb"
}

function resolve_slack_deb_url() {
    local slack_version
    slack_version="$(curl -sL https://slack.com/downloads/linux \
        | sed -n 's/.*<span class="page-downloads__hero__meta-text__version">Version \([^<]\+\)<\/span>.*/\1/p')"
    echo "https://downloads.slack-edge.com/desktop-releases/linux/x64/${slack_version}/slack-desktop-${slack_version}-amd64.deb"
}

function resolve_zoom_deb_url() {
    echo "https://zoom.us/client/latest/zoom_amd64.deb"
}

function resolve_threema_deb_url() {
    echo "https://releases.threema.ch/web-electron/v1/release/Threema-Latest.deb"
}

function resolve_chrome_deb_url() {
    echo "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
}

function resolve_postman_archive_url() {
    echo "https://dl.pstmn.io/download/latest/linux64"
}

register_app --id signal --name "Signal" --type apt-repo --package signal-desktop \
    --key-url "https://updates.signal.org/desktop/apt/keys.asc" \
    --keyring-path "/usr/share/keyrings/signal-desktop-keyring.gpg" \
    --source-url "https://updates.signal.org/static/desktop/apt/signal-desktop.sources" \
    --source-path "/etc/apt/sources.list.d/signal-desktop.sources" \
    --remove-file "/etc/apt/sources.list.d/signal.list" \
    --remove-file "/etc/apt/sources.list.d/signal-desktop.sources" \
    --remove-file "/usr/share/keyrings/signal-desktop-keyring.gpg"
register_app --id bitwarden --name "Bitwarden" --type deb --package bitwarden --resolver resolve_bitwarden_deb_url
register_app --id keepassxc --name "KeePassXC" --type apt --package keepassxc
register_app --id joplin --name "Joplin" --type appimage --package joplin --resolver resolve_joplin_appimage_url
register_app --id standardnotes --name "Standard Notes" --type appimage --package standardnotes --resolver resolve_standardnotes_appimage_url
register_app --id obsidian --name "Obsidian" --type appimage --package obsidian --resolver resolve_obsidian_appimage_url
register_app --id cursor --name "Cursor" --type deb --package cursor --resolver resolve_cursor_deb_url
register_app --id discord --name "Discord" --type deb --package discord --resolver resolve_discord_deb_url --fix-broken true
register_app --id slack --name "Slack" --type deb --package slack-desktop --resolver resolve_slack_deb_url --fix-broken true
register_app --id zoom --name "Zoom" --type deb --package zoom --resolver resolve_zoom_deb_url --fix-broken true
register_app --id threema --name "Threema" --type deb --package threema --resolver resolve_threema_deb_url
register_app --id onlyoffice --name "OnlyOffice" --type apt-repo --package onlyoffice-desktopeditors \
    --key-url "https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE" \
    --keyring-path "/usr/share/keyrings/onlyoffice.gpg" \
    --source-resolver resolve_onlyoffice_source \
    --source-path "/etc/apt/sources.list.d/onlyoffice.list" \
    --remove-file "/etc/apt/sources.list.d/onlyoffice.list" \
    --remove-file "/usr/share/keyrings/onlyoffice.gpg"
register_app --id chrome --name "Google Chrome" --type deb --package google-chrome-stable --resolver resolve_chrome_deb_url
register_app --id postman --name "Postman" --type archive --package postman --resolver resolve_postman_archive_url
register_app --id vscodium --name "VSCodium" --type apt-repo --package codium \
    --key-url "https://repo.vscodium.dev/vscodium.gpg" \
    --keyring-path "/usr/share/keyrings/vscodium.gpg" \
    --source-url "https://repo.vscodium.dev/vscodium.sources" \
    --source-path "/etc/apt/sources.list.d/vscodium.sources" \
    --remove-file "/etc/apt/sources.list.d/vscodium.list" \
    --remove-file "/etc/apt/sources.list.d/vscodium.sources" \
    --remove-file "/usr/share/keyrings/vscodium.gpg"
register_app --id firefox --name "Firefox" --type apt-repo --package firefox \
    --key-url "https://packages.mozilla.org/apt/repo-signing-key.gpg" \
    --keyring-path "/etc/apt/keyrings/packages.mozilla.org.asc" \
    --key-fingerprint "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3" \
    --source-resolver resolve_firefox_source \
    --source-path "/etc/apt/sources.list.d/mozilla.sources" \
    --pin-path "/etc/apt/preferences.d/mozilla" \
    --pin-resolver resolve_firefox_pin \
    --remove-file "/etc/apt/sources.list.d/mozilla.list" \
    --remove-file "/etc/apt/sources.list.d/mozilla.sources" \
    --remove-file "/etc/apt/preferences.d/mozilla" \
    --remove-file "/etc/apt/keyrings/packages.mozilla.org.asc"
register_app --id brave --name "Brave" --type apt-repo --package brave-browser \
    --key-url "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
    --keyring-path "/usr/share/keyrings/brave-browser-archive-keyring.gpg" \
    --source-url "https://brave-browser-apt-release.s3.brave.com/brave-browser.sources" \
    --source-path "/etc/apt/sources.list.d/brave-browser-release.sources" \
    --remove-file "/etc/apt/sources.list.d/brave-browser.list" \
    --remove-file "/etc/apt/sources.list.d/brave-browser-release.list" \
    --remove-file "/etc/apt/sources.list.d/brave-browser-release.sources" \
    --remove-file "/usr/share/keyrings/brave-browser-archive-keyring.gpg"
register_app --id vscode --name "Visual Studio Code" --type apt-repo --package code \
    --key-url "https://packages.microsoft.com/keys/microsoft.asc" \
    --keyring-path "/usr/share/keyrings/microsoft.gpg" \
    --source-resolver resolve_vscode_source \
    --source-path "/etc/apt/sources.list.d/vscode.sources" \
    --pin-path "/etc/apt/preferences.d/code" \
    --pin-resolver resolve_vscode_pin \
    --remove-file "/etc/apt/sources.list.d/vscode.list" \
    --remove-file "/etc/apt/sources.list.d/vscode.sources" \
    --remove-file "/etc/apt/preferences.d/code" \
    --remove-file "/usr/share/keyrings/microsoft.gpg"
