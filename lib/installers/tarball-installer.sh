#!/usr/bin/env bash

# Tarball installer for DEBAPPS
# Handles tarball-based apps (Postman, Tor Browser, etc.)
# Requires: core/common.sh, lib/db.sh

set -euo pipefail

# Install from tarball
# Usage: install_tarball "app_id"
install_tarball() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "install_tarball requires an app_id"
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

    # Check if already installed
    if db_is_installed "$app_id" 2>/dev/null; then
        print_message WARN "${app_name} is already installed. Removing first..."
        remove_tarball "$app_id" || {
            print_message FAIL "Failed to remove existing installation"
            return 1
        }
    fi

    # Get install location
    local install_location
    install_location=$(echo "$app_config" | jq -r '.install_location // "/opt/'$app_id'"')

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

    # Download tarball - detect compression format from URL
    local tarball_ext=".tar.gz"
    local tar_flags="xzf"

    if [[ "$download_url" == *.tar.xz ]]; then
        tarball_ext=".tar.xz"
        tar_flags="xJf"
    elif [[ "$download_url" == *.tar.bz2 ]]; then
        tarball_ext=".tar.bz2"
        tar_flags="xjf"
    elif [[ "$download_url" == *.tar.gz ]] || [[ "$download_url" == *.tgz ]]; then
        tarball_ext=".tar.gz"
        tar_flags="xzf"
    fi

    local tarball_file="/tmp/${app_id}${tarball_ext}"

    print_message INFO "Downloading ${app_name}..."
    download_file "$tarball_file" "$download_url" || {
        print_message FAIL "Download failed"
        return 1
    }

    # Create install directory
    print_message INFO "Creating installation directory..."
    sudo mkdir -p "$install_location"

    # Extract tarball
    print_message INFO "Extracting files..."
    sudo tar -${tar_flags} "$tarball_file" -C "$install_location" --strip-components=1 || {
        print_message FAIL "Extraction failed"
        rm -f "$tarball_file"
        return 1
    }

    # Handle post-install actions
    local post_install
    post_install=$(echo "$app_config" | jq -r '.post_install // {}')

    # Create symlink if specified
    local symlink_source
    symlink_source=$(echo "$post_install" | jq -r '.symlink.source // ""')

    local symlink_target
    symlink_target=$(echo "$post_install" | jq -r '.symlink.target // ""')

    if [[ -n "$symlink_source" ]] && [[ "$symlink_source" != "null" ]]; then
        print_message INFO "Creating symlink..."
        sudo ln -sf "$symlink_source" "$symlink_target" || {
            print_message WARN "Failed to create symlink"
        }
    fi

    # Create desktop entry if specified
    local desktop_file
    desktop_file=$(echo "$post_install" | jq -r '.desktop_entry.file // ""')

    local desktop_content
    desktop_content=$(echo "$post_install" | jq -r '.desktop_entry.content // ""')

    if [[ -n "$desktop_file" ]] && [[ "$desktop_file" != "null" ]]; then
        print_message INFO "Creating desktop entry..."
        echo -e "$desktop_content" | sudo tee "$desktop_file" >/dev/null
        sudo chmod 644 "$desktop_file"
    fi

    # Set permissions
    print_message INFO "Setting permissions..."
    sudo chown -R root:root "$install_location"

    # Make main executable if it exists
    local main_executable="${install_location}/${app_name}"
    if [[ -f "$main_executable" ]]; then
        sudo chmod +x "$main_executable"
    fi

    # Verify installation
    if [[ -d "$install_location" ]]; then
        print_message PASS "${app_name} installed successfully"

        # Record in database
        db_insert_app "$app_id" "$app_name" "tarball" "$version" "$install_location" "{\"tarball\":true}"

        # Track installed files
        if [[ -n "$symlink_target" ]] && [[ "$symlink_target" != "null" ]]; then
            db_insert_file "$app_id" "$symlink_target" "symlink"
        fi

        if [[ -n "$desktop_file" ]] && [[ "$desktop_file" != "null" ]]; then
            db_insert_file "$app_id" "$desktop_file" "desktop"
        fi

        db_insert_file "$app_id" "$install_location" "directory"

        # Cleanup
        rm -f "$tarball_file" 2>/dev/null || true

        ui_success "Installation Complete" "${app_name} has been installed successfully"
    else
        print_message FAIL "Installation verification failed"
        rm -f "$tarball_file" 2>/dev/null || true
        return 1
    fi
}

# Remove tarball installation
# Usage: remove_tarball "app_id"
remove_tarball() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "remove_tarball requires an app_id"
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

    # Remove installation directory
    if [[ -d "$install_location" ]]; then
        print_message INFO "Removing installation directory: ${install_location}"
        sudo rm -rf "$install_location" || {
            print_message WARN "Failed to remove some files"
        }
    fi

    # Remove symlink if it exists
    local post_install
    post_install=$(echo "$app_config" | jq -r '.post_install // {}')

    local symlink_target
    symlink_target=$(echo "$post_install" | jq -r '.symlink.target // ""')

    if [[ -n "$symlink_target" ]] && [[ "$symlink_target" != "null" ]] && [[ -L "$symlink_target" ]]; then
        print_message INFO "Removing symlink: ${symlink_target}"
        sudo rm -f "$symlink_target"
    fi

    # Remove desktop entry if it exists
    local desktop_file
    desktop_file=$(echo "$post_install" | jq -r '.desktop_entry.file // ""')

    if [[ -n "$desktop_file" ]] && [[ "$desktop_file" != "null" ]] && [[ -f "$desktop_file" ]]; then
        print_message INFO "Removing desktop entry: ${desktop_file}"
        sudo rm -f "$desktop_file"
    fi

    # Remove from database
    if db_is_installed "$app_id" 2>/dev/null; then
        db_remove_app "$app_id"
    fi

    ui_success "Removal Complete" "${app_name} has been removed successfully"
}

# Reinstall tarball
# Usage: reinstall_tarball "app_id"
reinstall_tarball() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "reinstall_tarball requires an app_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    print_message INFO "Reinstalling ${app_name}..."

    # Remove first
    remove_tarball "$app_id" || {
        print_message WARN "Removal failed, attempting fresh install anyway..."
    }

    # Install
    install_tarball "$app_id"
}

# Upgrade tarball (same as reinstall)
# Usage: upgrade_tarball "app_id"
upgrade_tarball() {
    local app_id="${1:-}"

    reinstall_tarball "$app_id"
}
