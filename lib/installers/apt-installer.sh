#!/usr/bin/env bash

# APT repository installer for DEBAPPS
# Handles apps from APT repositories (VSCode, Brave, Signal, etc.)
# Requires: core/common.sh, core/package-manager.sh, lib/db.sh

set -euo pipefail

# Install from APT repository
# Usage: install_apt_repo "app_id"
install_apt_repo() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "install_apt_repo requires an app_id"
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
        remove_apt_repo "$app_id" || {
            print_message FAIL "Failed to remove existing installation"
            return 1
        }
    fi

    # Get source configuration
    local source_type
    source_type=$(echo "$app_config" | jq -r '.source.type')

    if [[ "$source_type" == "apt_repository" ]]; then
        # Install GPG key
        local key_url
        key_url=$(echo "$app_config" | jq -r '.source.key_url')

        local key_name
        key_name=$(echo "$app_config" | jq -r '.source.key_name')

        print_message INFO "Adding GPG signing key..."
        fetch_signing_key "$key_name" "$key_url" || {
            print_message FAIL "Failed to add signing key"
            return 1
        }

        # Add repository
        local repo_line
        repo_line=$(echo "$app_config" | jq -r '.source.repo_line')

        # Replace <DISTRO> placeholder with actual distribution codename
        if [[ "$repo_line" == *"<DISTRO>"* ]]; then
            local distro_codename
            distro_codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
            repo_line="${repo_line//<DISTRO>/$distro_codename}"
            print_message INFO "Detected distribution: ${distro_codename}"
        fi

        local repo_file
        repo_file=$(echo "$app_config" | jq -r '.source.repo_file')

        print_message INFO "Adding APT repository..."
        add_apt_source "$key_name" "$repo_file" "$repo_line" || {
            print_message FAIL "Failed to add repository"
            return 1
        }

        # Handle preferences file if specified (for Firefox, etc.)
        local pref_file
        pref_file=$(echo "$app_config" | jq -r '.source.preferences.file // ""')

        if [[ -n "$pref_file" ]] && [[ "$pref_file" != "null" ]]; then
            local pref_content
            pref_content=$(echo "$app_config" | jq -r '.source.preferences.content')

            print_message INFO "Creating preferences file..."
            echo -e "$pref_content" | sudo tee "$pref_file" >/dev/null
        fi

        # Update package list
        print_message INFO "Updating package lists..."
        run_command sudo apt-get update

        # Install package
        local package_name
        package_name=$(echo "$app_config" | jq -r '.source.package_name')

        # Remove conflicting packages if specified
        local remove_conflicts
        remove_conflicts=$(echo "$app_config" | jq -r '.remove_conflicts[]? // empty' 2>/dev/null)

        if [[ -n "$remove_conflicts" ]]; then
            while IFS= read -r conflict_pkg; do
                if dpkg -l "$conflict_pkg" 2>/dev/null | grep -q "^ii"; then
                    print_message INFO "Removing conflicting package: $conflict_pkg"
                    pkgmgr remove "$conflict_pkg"
                fi
            done <<< "$remove_conflicts"
        fi

        print_message INFO "Installing ${app_name}..."
        pkgmgr install "$package_name" || {
            print_message FAIL "Package installation failed"
            return 1
        }

        # Verify installation (handle multi-package installations)
        local first_package
        first_package=$(echo "$package_name" | awk '{print $1}')

        if dpkg -l "$first_package" 2>/dev/null | grep -q "^ii"; then
            print_message PASS "${app_name} installed successfully"

            # Get installed version from first package
            local installed_version
            installed_version=$(dpkg-query -W -f='${Version}' "$first_package" 2>/dev/null || echo "unknown")

            # Record in database
            db_insert_app "$app_id" "$app_name" "apt_repo" "$installed_version" "system" "{\"package\":\"${package_name}\",\"repo\":\"${repo_file}\"}"

            # Run post-install script if specified
            local post_install_script
            post_install_script=$(echo "$app_config" | jq -r '.post_install_script // ""')

            if [[ -n "$post_install_script" ]] && [[ "$post_install_script" != "null" ]]; then
                print_message INFO "Running post-install setup..."
                eval "$post_install_script" || {
                    print_message WARN "Post-install script had some issues, but installation succeeded"
                }
            fi

            ui_success "Installation Complete" "${app_name} v${installed_version} has been installed successfully"
        else
            print_message FAIL "Installation verification failed"
            return 1
        fi

    elif [[ "$source_type" == "apt_package" ]]; then
        # Simple APT package installation
        local package_name
        package_name=$(echo "$app_config" | jq -r '.source.package_name')

        print_message INFO "Installing ${app_name} from default repositories..."
        pkgmgr install "$package_name" || {
            print_message FAIL "Package installation failed"
            return 1
        }

        # Verify installation
        if dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
            print_message PASS "${app_name} installed successfully"

            local installed_version
            installed_version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null || echo "unknown")

            db_insert_app "$app_id" "$app_name" "apt" "$installed_version" "system" "{\"package\":\"${package_name}\"}"

            ui_success "Installation Complete" "${app_name} v${installed_version} has been installed successfully"
        else
            print_message FAIL "Installation verification failed"
            return 1
        fi
    fi
}

# Remove APT repository package
# Usage: remove_apt_repo "app_id"
remove_apt_repo() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "remove_apt_repo requires an app_id"
        return 1
    fi

    # Get app configuration
    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    local app_name
    app_name=$(echo "$app_config" | jq -r '.name')

    print_message WARN "Removing ${app_name}..."

    # Confirm removal
    if ! ui_confirm "Remove ${app_name}" "This will remove ${app_name}. Keep repository? (No removes repo too)"; then
        print_message INFO "Removal cancelled by user"
        return 0
    fi

    # Get package name
    local package_name
    package_name=$(echo "$app_config" | jq -r '.source.package_name')

    if [[ -z "$package_name" ]] || [[ "$package_name" == "null" ]]; then
        print_message FAIL "Package name not found in configuration"
        return 1
    fi

    # Remove package
    if dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
        print_message INFO "Removing package: ${package_name}"
        pkgmgr remove "$package_name" || {
            print_message FAIL "Failed to remove package"
            return 1
        }
    fi

    # Ask if user wants to remove repository too
    local source_type
    source_type=$(echo "$app_config" | jq -r '.source.type')

    if [[ "$source_type" == "apt_repository" ]]; then
        if ui_confirm "Remove Repository" "Remove the APT repository for ${app_name}?"; then
            local repo_file
            repo_file=$(echo "$app_config" | jq -r '.source.repo_file')

            if [[ -n "$repo_file" ]] && [[ -f "/etc/apt/sources.list.d/${repo_file}" ]]; then
                print_message INFO "Removing repository file..."
                sudo rm -f "/etc/apt/sources.list.d/${repo_file}"
            fi

            # Remove GPG key
            local key_name
            key_name=$(echo "$app_config" | jq -r '.source.key_name')

            if [[ -n "$key_name" ]] && [[ -f "/etc/apt/keyrings/${key_name}.gpg" ]]; then
                print_message INFO "Removing GPG key..."
                sudo rm -f "/etc/apt/keyrings/${key_name}.gpg"
            fi

            print_message INFO "Updating package lists..."
            run_command sudo apt-get update
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

# Reinstall APT repository package
# Usage: reinstall_apt_repo "app_id"
reinstall_apt_repo() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "reinstall_apt_repo requires an app_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    print_message INFO "Reinstalling ${app_name}..."

    # Remove then install (reinstall = remove + install)
    remove_apt_repo "$app_id" || {
        print_message WARN "Remove during reinstall had issues, continuing..."
    }

    install_apt_repo "$app_id" || {
        print_message FAIL "Reinstall failed"
        return 1
    }

    ui_success "Reinstall Complete" "${app_name} has been reinstalled successfully"
}

# Upgrade APT repository package
# Usage: upgrade_apt_repo "app_id"
upgrade_apt_repo() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "upgrade_apt_repo requires an app_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    print_message INFO "Upgrading ${app_name}..."

    # Update package lists
    print_message INFO "Updating package lists..."
    run_command sudo apt-get update

    # Get package name
    local app_config
    app_config=$(get_app_config "$app_id")

    local package_name
    package_name=$(echo "$app_config" | jq -r '.source.package_name')

    # Upgrade package
    print_message INFO "Upgrading package: ${package_name}"
    run_command sudo apt-get install --only-upgrade "$package_name"

    # Update database version
    local new_version
    new_version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null || echo "unknown")

    db_update_version "$app_id" "$new_version"

    ui_success "Upgrade Complete" "${app_name} has been upgraded to v${new_version}"
}
