#!/usr/bin/env bash

# Multi-method application detection engine for DEBAPPS
# Detects installed applications through various methods
# Requires: core/common.sh

set -euo pipefail

# Detect if an application is installed
# Usage: detect_app "app_id"
# Output: JSON with installation status and details
detect_app() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "detect_app requires an app_id"
        return 1
    fi

    # Get app config
    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    local detection_config
    detection_config=$(echo "$app_config" | jq -r '.detection')

    # Initialize result
    local result='{
        "installed": false,
        "method": "none",
        "version": "",
        "location": "",
        "upgradeable": false,
        "latest_version": ""
    }'

    # Detection priority order:
    # 1. Internal database (fastest, most reliable)
    # 2. Binary in PATH
    # 3. Package manager (apt/dpkg)
    # 4. Snap packages
    # 5. Flatpak packages
    # 6. Desktop files

    # Method 1: Check internal database
    if check_database "$app_id"; then
        local db_info
        db_info=$(db_get_app "$app_id" 2>/dev/null | jq -r '.[0]' 2>/dev/null)

        if [[ -n "$db_info" ]] && [[ "$db_info" != "null" ]]; then
            local version
            version=$(echo "$db_info" | jq -r '.version // "unknown"')

            local location
            location=$(echo "$db_info" | jq -r '.install_location // ""')

            local method
            method=$(echo "$db_info" | jq -r '.install_method // "database"')

            result=$(echo "$result" | jq \
                ".installed=true | .method=\"${method}\" | .version=\"${version}\" | .location=\"${location}\"")
        fi
    fi

    # Method 2: Check binary in PATH (if not already found)
    if [[ $(echo "$result" | jq -r '.installed') == "false" ]]; then
        local binaries
        binaries=$(echo "$detection_config" | jq -r '.binaries[]? // empty' 2>/dev/null)

        if [[ -n "$binaries" ]]; then
            while IFS= read -r binary; do
                if command -v "$binary" &>/dev/null; then
                    local bin_path
                    bin_path=$(command -v "$binary")

                    local version
                    version=$(get_binary_version "$binary")

                    result=$(echo "$result" | jq \
                        ".installed=true | .method=\"binary\" | .version=\"${version}\" | .location=\"${bin_path}\"")
                    break
                fi
            done <<< "$binaries"
        fi
    fi

    # Method 3: Check APT/dpkg (if not already found)
    if [[ $(echo "$result" | jq -r '.installed') == "false" ]]; then
        local apt_packages
        apt_packages=$(echo "$detection_config" | jq -r '.apt_packages[]? // empty' 2>/dev/null)

        if [[ -n "$apt_packages" ]]; then
            while IFS= read -r package; do
                if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
                    local version
                    version=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || echo "unknown")

                    result=$(echo "$result" | jq \
                        ".installed=true | .method=\"apt\" | .version=\"${version}\" | .location=\"system\"")
                    break
                fi
            done <<< "$apt_packages"
        fi
    fi

    # Method 4: Check Snap (if not already found)
    if [[ $(echo "$result" | jq -r '.installed') == "false" ]]; then
        if command -v snap &>/dev/null; then
            local snap_packages
            snap_packages=$(echo "$detection_config" | jq -r '.snap_packages[]? // empty' 2>/dev/null)

            if [[ -n "$snap_packages" ]]; then
                while IFS= read -r package; do
                    if snap list "$package" 2>/dev/null | grep -q "^${package}"; then
                        local version
                        version=$(snap list "$package" 2>/dev/null | awk -v pkg="$package" '$1==pkg {print $2}')

                        result=$(echo "$result" | jq \
                            ".installed=true | .method=\"snap\" | .version=\"${version}\" | .location=\"snap\"")
                        break
                    fi
                done <<< "$snap_packages"
            fi
        fi
    fi

    # Method 5: Check Flatpak (if not already found)
    if [[ $(echo "$result" | jq -r '.installed') == "false" ]]; then
        if command -v flatpak &>/dev/null; then
            local flatpak_packages
            flatpak_packages=$(echo "$detection_config" | jq -r '.flatpak_packages[]? // empty' 2>/dev/null)

            if [[ -n "$flatpak_packages" ]]; then
                while IFS= read -r package; do
                    if flatpak list 2>/dev/null | grep -q "$package"; then
                        local version
                        version=$(flatpak info "$package" 2>/dev/null | grep "Version:" | awk '{print $2}')

                        result=$(echo "$result" | jq \
                            ".installed=true | .method=\"flatpak\" | .version=\"${version}\" | .location=\"flatpak\"")
                        break
                    fi
                done <<< "$flatpak_packages"
            fi
        fi
    fi

    # Method 6: Check desktop files (if not already found)
    if [[ $(echo "$result" | jq -r '.installed') == "false" ]]; then
        local desktop_files
        desktop_files=$(echo "$detection_config" | jq -r '.desktop_files[]? // empty' 2>/dev/null)

        if [[ -n "$desktop_files" ]]; then
            while IFS= read -r desktop; do
                if [[ -f "/usr/share/applications/$desktop" ]] || [[ -f "$HOME/.local/share/applications/$desktop" ]]; then
                    result=$(echo "$result" | jq \
                        ".installed=true | .method=\"desktop\" | .location=\"manual\"")
                    break
                fi
            done <<< "$desktop_files"
        fi
    fi

    # Check for upgradeable version (if installed)
    if [[ $(echo "$result" | jq -r '.installed') == "true" ]]; then
        local installed_version
        installed_version=$(echo "$result" | jq -r '.version')

        # Get latest version
        local latest_info
        latest_info=$(resolve_version "$app_id" 2>/dev/null || echo '{"version":"unknown"}')

        local latest_version
        latest_version=$(echo "$latest_info" | jq -r '.version')

        result=$(echo "$result" | jq ".latest_version=\"${latest_version}\"")

        # Compare versions (if both are known)
        if [[ -n "$installed_version" ]] && [[ "$installed_version" != "unknown" ]] && \
           [[ -n "$latest_version" ]] && [[ "$latest_version" != "unknown" ]] && \
           [[ "$latest_version" != "latest" ]]; then

            if version_compare "$installed_version" "$latest_version"; then
                result=$(echo "$result" | jq ".upgradeable=true")
            fi
        fi
    fi

    echo "$result"
}

# Check if app is in database
# Usage: check_database "app_id"
# Returns: 0 if found, 1 if not
check_database() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        return 1
    fi

    db_is_installed "$app_id" 2>/dev/null
}

# Get binary version
# Usage: get_binary_version "binary_name"
# Returns: version string or "unknown"
get_binary_version() {
    local binary="${1:-}"

    if [[ -z "$binary" ]]; then
        echo "unknown"
        return 0
    fi

    # Skip version detection for known GUI applications to prevent launch
    # These apps open windows when called with --version
    local gui_apps=(
        "cursor" "code" "codium" "sublime" "atom" "vscode"
        "bitwarden" "keepassxc" "obsidian" "joplin" "standardnotes"
        "discord" "slack" "zoom" "signal-desktop"
        "firefox" "chrome" "brave-browser" "google-chrome"
        "postman" "burpsuite"
    )

    for gui_app in "${gui_apps[@]}"; do
        if [[ "$binary" == "$gui_app" ]] || [[ "$binary" == *"/$gui_app" ]]; then
            echo "unknown"
            return 0
        fi
    done

    # Try common version flags with timeout to prevent hanging
    local version="unknown"
    local output

    # Try --version with 2 second timeout
    if output=$(timeout 2 "$binary" --version 2>&1 | head -1 2>/dev/null); then
        if [[ "$output" =~ [0-9]+\.[0-9]+(\.[0-9]+)? ]]; then
            version="${BASH_REMATCH[0]}"
        fi
    fi

    # Try -v if --version didn't work (with timeout)
    if [[ "$version" == "unknown" ]]; then
        if output=$(timeout 2 "$binary" -v 2>&1 | head -1 2>/dev/null); then
            if [[ "$output" =~ [0-9]+\.[0-9]+(\.[0-9]+)? ]]; then
                version="${BASH_REMATCH[0]}"
            fi
        fi
    fi

    echo "$version"
}

# Compare versions (semantic versioning)
# Usage: version_compare "installed_version" "latest_version"
# Returns: 0 if installed < latest (upgradeable), 1 otherwise
version_compare() {
    local installed="${1:-}"
    local latest="${2:-}"

    if [[ -z "$installed" ]] || [[ -z "$latest" ]]; then
        return 1
    fi

    # Strip 'v' prefix if present
    installed="${installed#v}"
    latest="${latest#v}"

    # Simple string comparison (works for most cases)
    if [[ "$installed" == "$latest" ]]; then
        return 1  # Same version, not upgradeable
    fi

    # Use sort -V for semantic version comparison
    local older
    older=$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | head -1)

    if [[ "$older" == "$installed" ]]; then
        return 0  # Installed is older, upgradeable
    else
        return 1  # Installed is newer or equal
    fi
}

# Quick check if app is installed (boolean)
# Usage: is_app_installed "app_id"
# Returns: 0 if installed, 1 if not
is_app_installed() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        return 1
    fi

    local result
    result=$(detect_app "$app_id" 2>/dev/null)

    local installed
    installed=$(echo "$result" | jq -r '.installed')

    if [[ "$installed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Get installed version
# Usage: get_installed_version "app_id"
# Returns: version string or empty
get_installed_version() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        return 1
    fi

    local result
    result=$(detect_app "$app_id" 2>/dev/null)

    echo "$result" | jq -r '.version'
}

# Check if app is upgradeable
# Usage: is_upgradeable "app_id"
# Returns: 0 if upgradeable, 1 if not
is_upgradeable() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        return 1
    fi

    local result
    result=$(detect_app "$app_id" 2>/dev/null)

    local upgradeable
    upgradeable=$(echo "$result" | jq -r '.upgradeable')

    if [[ "$upgradeable" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# List all installed apps from all sources
# Usage: list_all_installed
# Output: JSON array of detected apps
list_all_installed() {
    local all_apps
    all_apps=$(get_all_apps)

    local results='[]'

    while IFS= read -r app_id; do
        local detection
        detection=$(detect_app "$app_id" 2>/dev/null)

        local is_installed
        is_installed=$(echo "$detection" | jq -r '.installed')

        if [[ "$is_installed" == "true" ]]; then
            local app_name
            app_name=$(get_app_name "$app_id")

            local app_info
            app_info=$(echo "$detection" | jq ". + {\"app_id\": \"${app_id}\", \"app_name\": \"${app_name}\"}")

            results=$(echo "$results" | jq ". + [$app_info]")
        fi
    done <<< "$all_apps"

    echo "$results"
}

# Scan system for unknown installations
# Usage: scan_system
# Output: List of found applications not in config
scan_system() {
    print_message INFO "Scanning system for installed applications..."

    local found_apps=()

    # Check common installation locations
    local locations=(
        "/opt"
        "/usr/local/bin"
        "/snap"
        "$HOME/.local/share/applications"
    )

    for location in "${locations[@]}"; do
        if [[ -d "$location" ]]; then
            print_message INFO "Scanning: $location"

            # Look for directories in /opt
            if [[ "$location" == "/opt" ]]; then
                find "$location" -maxdepth 1 -type d 2>/dev/null | while read -r dir; do
                    local app_name
                    app_name=$(basename "$dir")

                    if [[ "$app_name" != "opt" ]] && [[ ! " ${found_apps[*]} " =~ " ${app_name} " ]]; then
                        echo "  Found: $app_name (in /opt)"
                        found_apps+=("$app_name")
                    fi
                done
            fi
        fi
    done

    print_message PASS "System scan complete"
}
