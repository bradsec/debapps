#!/usr/bin/env bash

# AppImage installer for DEBAPPS
# Handles AppImage applications (Bitwarden, Joplin, Obsidian, etc.)
# Requires: core/common.sh, core/appimage-handler.sh, lib/version.sh, lib/db.sh

set -euo pipefail

# Install AppImage
# Usage: install_appimage "app_id"
install_appimage() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "install_appimage requires an app_id"
        return 1
    fi

    # Get app configuration
    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    local app_name
    app_name=$(echo "$app_config" | jq -r '.name')

    local app_desc
    app_desc=$(echo "$app_config" | jq -r '.description // ""')

    print_message INFOFULL "Installing ${app_name}"
    print_message INFO "${app_desc}"

    # Show warnings if any
    ui_show_warnings "$app_id"

    # Confirm installation
    if ! ui_confirm "Install ${app_name}" "Do you want to proceed with installation?"; then
        print_message INFO "Installation cancelled by user"
        return 0
    fi

    # Check if already installed via snap or flatpak
    local detection_result
    detection_result=$(detect_app "$app_id" 2>/dev/null || echo '{"installed":false}')

    local is_installed
    is_installed=$(echo "$detection_result" | jq -r '.installed // false')

    local install_method
    install_method=$(echo "$detection_result" | jq -r '.method // ""')

    if [[ "$is_installed" == "true" ]] && [[ "$install_method" != "database" ]]; then
        print_message WARN "${app_name} is already installed via ${install_method}"
        if ! ui_confirm "Already Installed" "${app_name} is installed via ${install_method}. Install AppImage version anyway?"; then
            print_message INFO "Installation cancelled"
            return 0
        fi
    fi

    # Check for dependencies (libfuse2)
    local deps
    deps=$(echo "$app_config" | jq -r '.dependencies[]? // empty' 2>/dev/null)

    if [[ -n "$deps" ]]; then
        print_message INFO "Checking dependencies..."
        while IFS= read -r dep; do
            # Check if package is installed (handles virtual packages and transitions)
            local installed=false

            # Method 1: Check exact package name
            if dpkg -l "$dep" 2>/dev/null | grep -q "^ii"; then
                installed=true
            fi

            # Method 2: Check for package name transitions (e.g., libfuse2 -> libfuse2t64)
            if [[ "$installed" == "false" ]]; then
                if dpkg -l "${dep}t64" 2>/dev/null | grep -q "^ii"; then
                    installed=true
                fi
            fi

            # Method 3: Check if any package provides this (virtual packages)
            if [[ "$installed" == "false" ]]; then
                if dpkg -l "*${dep}*" 2>/dev/null | grep -q "^ii"; then
                    installed=true
                fi
            fi

            if [[ "$installed" == "false" ]]; then
                print_message INFO "Installing dependency: $dep"
                pkgmgr install "$dep" || {
                    print_message WARN "Failed to install $dep, continuing anyway..."
                }
            fi
        done <<< "$deps"
    fi

    # Resolve version and get download URL
    print_message INFO "Resolving latest version..."
    local version_info
    version_info=$(resolve_version "$app_id") || {
        print_message FAIL "Failed to resolve version for ${app_id}"
        return 1
    }

    local version
    version=$(echo "$version_info" | jq -r '.version')

    local download_url
    download_url=$(echo "$version_info" | jq -r '.download_url')

    print_message PASS "Latest version: ${version}"

    # Check if already installed
    if db_is_installed "$app_id" 2>/dev/null; then
        print_message WARN "${app_name} is already installed. Removing first..."
        remove_appimage "$app_id" || {
            print_message FAIL "Failed to remove existing installation"
            return 1
        }
    fi

    # Get install location
    local install_location
    install_location=$(echo "$app_config" | jq -r '.install_location // "/opt/'$app_id'"')

    # Download AppImage
    local appimage_file="/tmp/${app_id}.AppImage"

    print_message INFO "Downloading ${app_name}..."
    download_file "$appimage_file" "$download_url" || {
        print_message FAIL "Download failed"
        return 1
    }

    # Make executable
    chmod +x "$appimage_file"

    # Use the appimage handler from core
    print_message INFO "Setting up AppImage..."
    if setup_app_image "$appimage_file" "$install_location" "$app_name"; then
        print_message PASS "${app_name} installed successfully"

        # Record in database (track all created files)
        local install_files=""
        if [[ -f "${install_location}/install.log" ]]; then
            install_files=$(cat "${install_location}/install.log")
        fi

        db_insert_app "$app_id" "$app_name" "appimage" "$version" "$install_location" "{\"appimage\":true}"

        # Track individual files
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            db_insert_file "$app_id" "$file" "appimage"
        done <<< "$install_files"

        # Cleanup
        rm -f "$appimage_file" 2>/dev/null || true

        ui_success "Installation Complete" "${app_name} v${version} has been installed successfully"
    else
        print_message FAIL "AppImage setup failed"
        rm -f "$appimage_file" 2>/dev/null || true
        return 1
    fi
}

# Remove AppImage
# Usage: remove_appimage "app_id"
remove_appimage() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "remove_appimage requires an app_id"
        return 1
    fi

    # Get app configuration
    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    local app_name
    app_name=$(echo "$app_config" | jq -r '.name')

    print_message WARN "Removing ${app_name}..."

    # Confirm removal
    if ! ui_confirm "Remove ${app_name}" "This will completely remove ${app_name}. Are you sure?"; then
        print_message INFO "Removal cancelled by user"
        return 0
    fi

    # Get install location from database or config
    local install_location
    if db_is_installed "$app_id" 2>/dev/null; then
        local db_info
        db_info=$(db_get_app "$app_id" 2>/dev/null | jq -r '.[0]')
        install_location=$(echo "$db_info" | jq -r '.install_location // ""')
    fi

    if [[ -z "$install_location" ]]; then
        install_location=$(echo "$app_config" | jq -r '.install_location // "/opt/'$app_id'"')
    fi

    # Check if AppImage directory exists
    if [[ ! -d "$install_location" ]]; then
        print_message WARN "AppImage directory not found: ${install_location}"

        # Remove from database if present
        if db_is_installed "$app_id" 2>/dev/null; then
            print_message INFO "Removing database entry..."
            db_remove_app "$app_id"
            print_message PASS "Database: Removed ${app_id} from tracking"
        fi

        ui_success "Removal Complete" "${app_name} has been removed from tracking"
        return 0
    fi

    # Use appimage handler to remove
    print_message INFO "Removing AppImage from: ${install_location}"
    if remove_app_image "$install_location"; then
        print_message PASS "Files removed successfully"
    else
        print_message WARN "Some files may not have been removed"
    fi

    # Remove from database
    if db_is_installed "$app_id" 2>/dev/null; then
        db_remove_app "$app_id"
    fi

    ui_success "Removal Complete" "${app_name} has been removed successfully"
}

# Reinstall AppImage
# Usage: reinstall_appimage "app_id"
reinstall_appimage() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "reinstall_appimage requires an app_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    print_message INFO "Reinstalling ${app_name}..."

    # Remove first
    remove_appimage "$app_id" || {
        print_message WARN "Removal failed, attempting fresh install anyway..."
    }

    # Install
    install_appimage "$app_id"
}

# Upgrade AppImage (same as reinstall)
# Usage: upgrade_appimage "app_id"
upgrade_appimage() {
    local app_id="${1:-}"

    reinstall_appimage "$app_id"
}
