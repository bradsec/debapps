#!/usr/bin/env bash

# Generic .deb package installer for DEBAPPS
# Handles direct .deb downloads (Slack, Discord, Zoom, etc.)
# Requires: core/common.sh, core/package-manager.sh, lib/version.sh, lib/db.sh

set -euo pipefail

# Install .deb package
# Usage: install_deb "app_id"
install_deb() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "install_deb requires an app_id"
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
        remove_deb "$app_id" || {
            print_message FAIL "Failed to remove existing installation"
            return 1
        }
    fi

    # Download .deb file
    local deb_file="/tmp/${app_id}_${version}.deb"

    print_message INFO "Downloading ${app_name}..."
    download_file "$deb_file" "$download_url" || {
        print_message FAIL "Download failed"
        return 1
    }

    # Install .deb package
    print_message INFO "Installing package..."
    run_command_verbose sudo dpkg -i "$deb_file"

    local install_result=$?

    # Fix broken dependencies if needed
    local post_install
    post_install=$(echo "$app_config" | jq -r '.post_install.fix_dependencies // false')

    if [[ "$post_install" == "true" ]] || [[ $install_result -ne 0 ]]; then
        print_message INFO "Fixing package dependencies..."
        run_command_verbose sudo apt-get -y --fix-broken install
    fi

    # Verify installation
    local package_name
    package_name=$(echo "$app_config" | jq -r '.detection.apt_packages[0] // ""')

    if [[ -n "$package_name" ]] && dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
        print_message PASS "${app_name} installed successfully"

        # Get actual installed version from dpkg
        local installed_version
        installed_version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null || echo "$version")

        # Record in database
        db_insert_app "$app_id" "$app_name" "deb" "$installed_version" "system" "{\"package\":\"${package_name}\"}"

        # Cleanup downloaded file
        rm -f "$deb_file" 2>/dev/null || true

        ui_success "Installation Complete" "${app_name} v${installed_version} has been installed successfully"
    else
        print_message FAIL "Installation verification failed"
        rm -f "$deb_file" 2>/dev/null || true
        return 1
    fi
}

# Remove .deb package
# Usage: remove_deb "app_id"
remove_deb() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "remove_deb requires an app_id"
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

    # Get package name from detection config
    local package_name
    package_name=$(echo "$app_config" | jq -r '.detection.apt_packages[0] // ""')

    if [[ -z "$package_name" ]]; then
        print_message FAIL "Package name not found in configuration"
        return 1
    fi

    # Check if package is installed
    if ! dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
        print_message WARN "${app_name} is not installed via apt/dpkg"

        # Remove from database anyway if present
        if db_is_installed "$app_id" 2>/dev/null; then
            db_remove_app "$app_id"
        fi

        return 0
    fi

    # Remove package
    print_message INFO "Removing package: ${package_name}"
    pkgmgr remove "$package_name" || {
        print_message FAIL "Failed to remove package"
        return 1
    }

    # Remove from database
    if db_is_installed "$app_id" 2>/dev/null; then
        db_remove_app "$app_id"
    fi

    # Cleanup
    print_message INFO "Running system cleanup..."
    run_command sudo apt-get -y autoremove
    run_command sudo apt-get -y autoclean

    ui_success "Removal Complete" "${app_name} has been removed successfully"
}

# Reinstall .deb package (remove then install)
# Usage: reinstall_deb "app_id"
reinstall_deb() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "reinstall_deb requires an app_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    print_message INFO "Reinstalling ${app_name}..."

    # Remove first
    remove_deb "$app_id" || {
        print_message WARN "Removal failed, attempting fresh install anyway..."
    }

    # Install
    install_deb "$app_id"
}

# Upgrade .deb package (same as reinstall for .deb packages)
# Usage: upgrade_deb "app_id"
upgrade_deb() {
    local app_id="${1:-}"

    reinstall_deb "$app_id"
}

# Show .deb package information
# Usage: show_deb_info "app_id"
show_deb_info() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "show_deb_info requires an app_id"
        return 1
    fi

    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    local app_name
    app_name=$(echo "$app_config" | jq -r '.name')

    local package_name
    package_name=$(echo "$app_config" | jq -r '.detection.apt_packages[0] // ""')

    print_message INFO "Package Information: ${app_name}"
    echo

    if [[ -n "$package_name" ]] && dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
        print_message PASS "Status: Installed"

        local installed_version
        installed_version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null || echo "unknown")

        print_message INFO "Installed Version: ${installed_version}"
        print_message INFO "Package Name: ${package_name}"

        # Show package details
        echo
        print_message INFO "Package Details:"
        dpkg-query -W -f='  Description: ${Description}\n  Size: ${Installed-Size} KB\n' "$package_name" 2>/dev/null || true

    else
        print_message WARN "Status: Not Installed"
    fi

    echo
    print_message INFO "Press Enter to continue..."
    read -r
}
