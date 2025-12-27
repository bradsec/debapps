#!/usr/bin/env bash

# .deb tarball installer for DEBAPPS
# Handles .tar.gz archives containing multiple .deb packages (LibreOffice, etc.)
# Requires: core/common.sh, core/package-manager.sh, lib/version.sh, lib/db.sh

set -euo pipefail

# Install from .deb tarball
# Usage: install_deb_tarball "app_id"
install_deb_tarball() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "install_deb_tarball requires an app_id"
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
        remove_deb_tarball "$app_id" || {
            print_message FAIL "Failed to remove existing installation"
            return 1
        }
    fi

    # Download tarball
    local tarball_file="/tmp/${app_id}_${version}.tar.gz"

    print_message INFO "Downloading ${app_name}..."
    download_file "$tarball_file" "$download_url" || {
        print_message FAIL "Download failed"
        return 1
    }

    # Create temporary extraction directory
    local extract_dir="/tmp/${app_id}_extract_$$"
    mkdir -p "$extract_dir"

    # Extract tarball
    print_message INFO "Extracting package archive..."
    tar -xzf "$tarball_file" -C "$extract_dir" || {
        print_message FAIL "Extraction failed"
        rm -rf "$tarball_file" "$extract_dir"
        return 1
    }

    # Find DEBS directory (LibreOffice structure)
    local debs_dir
    debs_dir=$(find "$extract_dir" -type d -name "DEBS" | head -1)

    if [[ -z "$debs_dir" ]]; then
        # No DEBS directory, look for .deb files in root
        debs_dir="$extract_dir"
    fi

    # Check if we have any .deb files
    local deb_count
    deb_count=$(find "$debs_dir" -maxdepth 1 -name "*.deb" 2>/dev/null | wc -l)

    if [[ $deb_count -eq 0 ]]; then
        print_message FAIL "No .deb packages found in archive"
        rm -rf "$tarball_file" "$extract_dir"
        return 1
    fi

    print_message INFO "Found ${deb_count} .deb packages to install"

    # Install all .deb packages
    print_message INFO "Installing packages..."
    sudo dpkg -i "$debs_dir"/*.deb 2>&1 | grep -v "Selecting previously unselected package" || true

    # Fix broken dependencies if needed
    print_message INFO "Fixing dependencies..."
    run_command_verbose sudo apt-get -y --fix-broken install

    # Verify installation
    local package_name
    package_name=$(echo "$app_config" | jq -r '.detection.apt_packages[0] // ""')

    if [[ -n "$package_name" ]] && dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
        print_message PASS "${app_name} installed successfully"

        # Get actual installed version from dpkg
        local installed_version
        installed_version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null || echo "$version")

        # Record in database
        db_insert_app "$app_id" "$app_name" "deb_tarball" "$installed_version" "system" "{\"package\":\"${package_name}\"}"

        # Cleanup
        rm -rf "$tarball_file" "$extract_dir" 2>/dev/null || true

        ui_success "Installation Complete" "${app_name} v${installed_version} has been installed successfully"
    else
        print_message FAIL "Installation verification failed"
        rm -rf "$tarball_file" "$extract_dir" 2>/dev/null || true
        return 1
    fi
}

# Remove .deb tarball installation
# Usage: remove_deb_tarball "app_id"
remove_deb_tarball() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "remove_deb_tarball requires an app_id"
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

    # Get package names to remove
    local package_pattern
    package_pattern=$(echo "$app_config" | jq -r '.remove_pattern // ""')

    if [[ -z "$package_pattern" ]]; then
        # Use detection package name
        local package_name
        package_name=$(echo "$app_config" | jq -r '.detection.apt_packages[0] // ""')

        if [[ -n "$package_name" ]]; then
            # Get all packages matching the base name (e.g., libreoffice*)
            local base_package="${package_name%%-*}"
            package_pattern="${base_package}*"
        fi
    fi

    if [[ -n "$package_pattern" ]]; then
        print_message INFO "Removing packages matching: ${package_pattern}"

        # Get list of installed packages matching pattern
        local packages_to_remove
        packages_to_remove=$(dpkg -l | grep "^ii" | awk '{print $2}' | grep "^${package_pattern}" || true)

        if [[ -n "$packages_to_remove" ]]; then
            echo "$packages_to_remove" | while read -r pkg; do
                print_message INFO "Removing package: ${pkg}"
                pkgmgr remove "$pkg" || {
                    print_message WARN "Failed to remove ${pkg}"
                }
            done
        else
            print_message WARN "No installed packages found matching ${package_pattern}"
        fi
    fi

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

# Reinstall .deb tarball package
# Usage: reinstall_deb_tarball "app_id"
reinstall_deb_tarball() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "reinstall_deb_tarball requires an app_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    print_message INFO "Reinstalling ${app_name}..."

    # Remove first
    remove_deb_tarball "$app_id" || {
        print_message WARN "Removal failed, attempting fresh install anyway..."
    }

    # Install
    install_deb_tarball "$app_id"
}

# Upgrade .deb tarball package
# Usage: upgrade_deb_tarball "app_id"
upgrade_deb_tarball() {
    local app_id="${1:-}"

    reinstall_deb_tarball "$app_id"
}
