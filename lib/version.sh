#!/usr/bin/env bash

# Version resolution engine for DEBAPPS
# Handles dynamic version detection and download URL generation
# Requires: core/common.sh, curl, jq

set -euo pipefail

# Cache configuration
CACHE_DIR="${SCRIPT_DIR}/data/cache"
CACHE_TTL=900  # 15 minutes in seconds

# Ensure cache directory exists
ensure_cache_dir() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
    fi
}

# Check if cached version is still valid
# Usage: is_cache_valid "cache_file"
# Returns: 0 if valid, 1 if expired or doesn't exist
is_cache_valid() {
    local cache_file="${1:-}"

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    local cache_age
    cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))

    if [[ $cache_age -lt $CACHE_TTL ]]; then
        return 0
    else
        return 1
    fi
}

# Resolve version for any app
# Usage: resolve_version "app_id"
# Output: JSON with version and download_url
resolve_version() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        echo "{\"error\":\"resolve_version requires an app_id\"}"
        return 1
    fi

    ensure_cache_dir

    local cache_file="${CACHE_DIR}/${app_id}_version.json"

    # Check cache first
    if is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    # Get app config
    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    local source_config
    source_config=$(echo "$app_config" | jq -r '.source')

    local source_type
    source_type=$(echo "$source_config" | jq -r '.type')

    local result=""

    # Resolve based on source type
    case "$source_type" in
        github_release)
            result=$(resolve_github_release "$app_id" "$source_config")
            ;;
        direct_download)
            result=$(resolve_direct_download "$source_config")
            ;;
        slack_latest)
            result=$(resolve_slack_latest "$source_config")
            ;;
        apt_repository)
            result=$(resolve_apt_repository "$source_config")
            ;;
        cursor_latest)
            result=$(resolve_cursor_latest "$source_config")
            ;;
        apt_package)
            result=$(resolve_apt_package "$source_config")
            ;;
        burp_installer)
            result=$(resolve_burp_installer "$source_config")
            ;;
        tor_browser_latest)
            result=$(resolve_tor_browser_latest "$source_config")
            ;;
        libreoffice_deb_tarball)
            result=$(resolve_libreoffice_deb_tarball "$source_config")
            ;;
        *)
            result='{"error":"Unknown source type: '"${source_type}"'"}'
            ;;
    esac

    # Cache the result
    if [[ -n "$result" ]]; then
        echo "$result" > "$cache_file" 2>/dev/null || true
    fi

    echo "$result"
}

# Resolve GitHub release version
# Usage: resolve_github_release "app_id" "source_config_json"
resolve_github_release() {
    local app_id="${1:-}"
    local source_config="${2:-}"

    local repo
    repo=$(echo "$source_config" | jq -r '.repo')

    local asset_pattern
    asset_pattern=$(echo "$source_config" | jq -r '.asset_pattern')

    local version_prefix
    version_prefix=$(echo "$source_config" | jq -r '.version_prefix // ""')

    if [[ -z "$repo" ]]; then
        echo "{\"error\":\"GitHub repo not specified for ${app_id}\"}"
        return 1
    fi

    # Use GitHub API
    local api_url
    local api_response

    # If version_prefix is specified, search through all releases for matching tag
    if [[ -n "$version_prefix" ]]; then
        api_url="https://api.github.com/repos/${repo}/releases"
        api_response=$(curl -sL -H "Accept: application/vnd.github+json" "$api_url" 2>/dev/null)
    else
        api_url="https://api.github.com/repos/${repo}/releases/latest"
        api_response=$(curl -sL -H "Accept: application/vnd.github+json" "$api_url" 2>/dev/null)
    fi

    if [[ -z "$api_response" ]]; then
        echo "{\"error\":\"Failed to fetch from GitHub API\"}"
        return 1
    fi

    # Check for API error
    local error_message
    error_message=$(echo "$api_response" | jq -r '.message // empty' 2>/dev/null)

    if [[ -n "$error_message" ]]; then
        echo "{\"error\":\"GitHub API error: ${error_message}\"}"
        return 1
    fi

    # Extract tag name
    local tag_name
    if [[ -n "$version_prefix" ]]; then
        # Find first stable release with matching tag prefix (exclude drafts and prereleases)
        tag_name=$(printf '%s' "$api_response" | jq -r ".[] | select(.tag_name | startswith(\"${version_prefix}\")) | select(.draft == false) | select(.prerelease == false) | .tag_name" 2>/dev/null | head -1)
    else
        tag_name=$(printf '%s' "$api_response" | jq -r '.tag_name // empty' 2>/dev/null)
    fi

    if [[ -z "$tag_name" ]]; then
        echo "{\"error\":\"No release tag found for ${repo}\"}"
        return 1
    fi

    # Remove version prefix if specified (e.g., "v" or "desktop-")
    local version="$tag_name"
    if [[ -n "$version_prefix" ]]; then
        version="${tag_name#$version_prefix}"
    fi

    # Build download URL from pattern
    local download_url="${asset_pattern//\{VERSION\}/$version}"

    # If pattern contains repo-relative path, make it absolute
    if [[ "$download_url" != http* ]]; then
        download_url="https://github.com/${repo}/releases/download/${tag_name}/${download_url}"
    fi

    echo "{\"version\":\"${version}\",\"download_url\":\"${download_url}\"}"
}

# Resolve direct download (no version)
# Usage: resolve_direct_download "source_config_json"
resolve_direct_download() {
    local source_config="${1:-}"

    local url
    url=$(echo "$source_config" | jq -r '.url')

    if [[ -z "$url" ]]; then
        echo "{\"error\":\"Download URL not specified\"}"
        return 1
    fi

    echo "{\"version\":\"latest\",\"download_url\":\"${url}\"}"
}

# Resolve Slack latest version
# Usage: resolve_slack_latest "source_config_json"
resolve_slack_latest() {
    local source_config="${1:-}"

    # Scrape version from Slack downloads page
    local downloads_page
    downloads_page=$(curl -sL "https://slack.com/downloads/linux" 2>/dev/null)

    # Extract version from the page (look for version number patterns)
    local version
    version=$(echo "$downloads_page" | grep -o 'slack-desktop-[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 | sed 's/slack-desktop-//')

    if [[ -z "$version" ]]; then
        # Fallback: try to find any version pattern
        version=$(echo "$downloads_page" | grep -o 'Version [0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 | sed 's/Version //')
    fi

    if [[ -z "$version" ]]; then
        echo "{\"error\":\"Unable to determine Slack version from downloads page\"}"
        return 1
    fi

    # Build download URL with found version
    local download_url="https://downloads.slack-edge.com/desktop-releases/linux/x64/${version}/slack-desktop-${version}-amd64.deb"

    echo "{\"version\":\"${version}\",\"download_url\":\"${download_url}\"}"
}

# Resolve APT repository version
# Usage: resolve_apt_repository "source_config_json"
resolve_apt_repository() {
    local source_config="${1:-}"

    local package_name
    package_name=$(echo "$source_config" | jq -r '.package_name')

    if [[ -z "$package_name" ]]; then
        echo "{\"error\":\"Package name not specified\"}"
        return 1
    fi

    # Query apt-cache for version (requires repo to be added first)
    local version="unknown"

    if command -v apt-cache &>/dev/null; then
        version=$(apt-cache policy "$package_name" 2>/dev/null | grep "Candidate:" | awk '{print $2}')
    fi

    if [[ -z "$version" ]] || [[ "$version" == "(none)" ]]; then
        version="latest"
    fi

    echo "{\"version\":\"${version}\",\"download_url\":\"apt:${package_name}\"}"
}

# Resolve Cursor AI latest version
# Usage: resolve_cursor_latest "source_config_json"
resolve_cursor_latest() {
    local source_config="${1:-}"

    local url
    url=$(echo "$source_config" | jq -r '.url // "https://api2.cursor.sh/updates/download/golden/linux-x64/cursor/latest"')

    # Try to get version from API
    local version="latest"
    local api_response
    api_response=$(curl -sL "https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable" 2>/dev/null)

    if [[ -n "$api_response" ]]; then
        # Try to extract version from JSON response
        local api_version
        api_version=$(echo "$api_response" | jq -r '.version // empty' 2>/dev/null)

        if [[ -n "$api_version" ]]; then
            version="$api_version"
        fi
    fi

    echo "{\"version\":\"${version}\",\"download_url\":\"${url}\"}"
}

# Resolve APT package version (simple apt install)
# Usage: resolve_apt_package "source_config_json"
resolve_apt_package() {
    local source_config="${1:-}"

    local package_name
    package_name=$(echo "$source_config" | jq -r '.package_name')

    if [[ -z "$package_name" ]]; then
        echo "{\"error\":\"Package name not specified\"}"
        return 1
    fi

    local version="unknown"

    if command -v apt-cache &>/dev/null; then
        version=$(apt-cache policy "$package_name" 2>/dev/null | grep "Candidate:" | awk '{print $2}')
    fi

    if [[ -z "$version" ]] || [[ "$version" == "(none)" ]]; then
        version="latest"
    fi

    echo "{\"version\":\"${version}\",\"download_url\":\"apt:${package_name}\"}"
}

# Clear version cache
# Usage: clear_version_cache ["app_id"]
clear_version_cache() {
    local app_id="${1:-}"

    ensure_cache_dir

    if [[ -n "$app_id" ]]; then
        # Clear specific app cache
        local cache_file="${CACHE_DIR}/${app_id}_version.json"
        if [[ -f "$cache_file" ]]; then
            rm -f "$cache_file"
            print_message PASS "Cleared version cache for ${app_id}"
        fi
    else
        # Clear all version cache
        rm -f "${CACHE_DIR}"/*_version.json 2>/dev/null || true
        print_message PASS "Cleared all version cache"
    fi
}

# Get cached version info (bypass TTL check)
# Usage: get_cached_version "app_id"
get_cached_version() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        return 1
    fi

    local cache_file="${CACHE_DIR}/${app_id}_version.json"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    else
        return 1
    fi
}

# Resolve Burp Suite installer
# Usage: resolve_burp_installer "source_config_json"
resolve_burp_installer() {
    local source_config="${1:-}"

    local edition
    edition=$(echo "$source_config" | jq -r '.edition // "community"')

    # Detect architecture
    local arch_type="linux"
    case "$(uname -m)" in
        aarch64) arch_type="linuxarm64" ;;
        arm64) arch_type="linuxarm64" ;;
        *) arch_type="linux" ;;
    esac

    # Get latest version from releases page
    local version
    version=$(curl -sL "https://portswigger.net/burp/releases" 2>/dev/null | \
        grep -oP 'professional-community-\d+(-\d+)+' | \
        head -1 | \
        sed 's/professional-community-//' | \
        tr '-' '.')

    if [[ -z "$version" ]]; then
        echo "{\"error\":\"Failed to fetch Burp Suite version\"}"
        return 1
    fi

    # Map edition to product name
    local product="community"
    if [[ "$edition" == "pro" ]]; then
        product="pro"
    fi

    # Construct download URL
    local download_url="https://portswigger.net/burp/releases/download?product=${product}&version=${version}&type=${arch_type}"

    echo "{\"version\":\"${version}\",\"download_url\":\"${download_url}\",\"arch\":\"${arch_type}\"}"
}

# Resolve Tor Browser latest version
# Usage: resolve_tor_browser_latest "source_config_json"
resolve_tor_browser_latest() {
    local source_config="${1:-}"

    local base_url
    base_url=$(echo "$source_config" | jq -r '.base_url // "https://www.torproject.org/download/"')

    # Get latest version from Tor download page
    local download_page
    download_page=$(curl -sL "$base_url" 2>/dev/null)

    local version
    version=$(echo "$download_page" | grep -oP 'torbrowser-install-linux-x86_64-\K[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)

    if [[ -z "$version" ]]; then
        # Fallback: try to get from dist directory listing
        version=$(curl -sL "https://dist.torproject.org/torbrowser/" 2>/dev/null | \
            grep -oP 'href="[0-9]+\.[0-9]+(\.[0-9]+)?/"' | \
            grep -oP '[0-9]+\.[0-9]+(\.[0-9]+)?' | \
            sort -V | tail -1)
    fi

    if [[ -z "$version" ]]; then
        echo "{\"error\":\"Failed to determine Tor Browser version\"}"
        return 1
    fi

    # Construct download URL
    local download_url="https://dist.torproject.org/torbrowser/${version}/tor-browser-linux-x86_64-${version}.tar.xz"

    echo "{\"version\":\"${version}\",\"download_url\":\"${download_url}\"}"
}

# Resolve LibreOffice .deb tarball version
# Usage: resolve_libreoffice_deb_tarball "source_config_json"
resolve_libreoffice_deb_tarball() {
    local source_config="${1:-}"

    local base_url
    base_url=$(echo "$source_config" | jq -r '.base_url // "https://download.documentfoundation.org/libreoffice/stable/"')

    # Get latest version from stable directory listing
    local version
    version=$(curl -sL "$base_url" 2>/dev/null | \
        grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+' | \
        sort -V | \
        tail -1)

    if [[ -z "$version" ]]; then
        echo "{\"error\":\"Failed to determine LibreOffice version\"}"
        return 1
    fi

    # Construct download URL
    local download_url="${base_url}${version}/deb/x86_64/LibreOffice_${version}_Linux_x86-64_deb.tar.gz"

    echo "{\"version\":\"${version}\",\"download_url\":\"${download_url}\"}"
}

# Display version cache statistics
# Usage: version_cache_stats
version_cache_stats() {
    ensure_cache_dir

    local total_cached
    total_cached=$(find "$CACHE_DIR" -name "*_version.json" 2>/dev/null | wc -l)

    print_message INFO "Version cache statistics:"
    echo "  Total cached versions: ${total_cached}"
    echo "  Cache directory: ${CACHE_DIR}"
    echo "  Cache TTL: ${CACHE_TTL} seconds (15 minutes)"

    if [[ $total_cached -gt 0 ]]; then
        echo
        echo "  Cached apps:"
        find "$CACHE_DIR" -name "*_version.json" 2>/dev/null | while read -r cache_file; do
            local app_id
            app_id=$(basename "$cache_file" | sed 's/_version.json$//')

            local age
            age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))

            local version
            version=$(jq -r '.version // "unknown"' < "$cache_file" 2>/dev/null)

            local status="valid"
            if [[ $age -ge $CACHE_TTL ]]; then
                status="expired"
            fi

            echo "    ${app_id}: v${version} (${status}, age: ${age}s)"
        done
    fi
}
