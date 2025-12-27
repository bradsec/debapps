#!/usr/bin/env bash

# Flatpak installer for DEBAPPS
# Handles Flatpak application installation and management
# Requires: core/common.sh, lib/db.sh

set -euo pipefail

# Check if Flatpak is installed and configured
# Usage: check_flatpak_available
# Returns: 0 if available, 1 if not
check_flatpak_available() {
    if ! command -v flatpak &>/dev/null; then
        return 1
    fi

    # Check if Flathub repository is configured
    if ! flatpak remotes 2>/dev/null | grep -q flathub; then
        print_message WARN "Flatpak is installed but Flathub repository is not configured"
        return 1
    fi

    return 0
}

# Search for an app in Flatpak repositories
# Usage: search_flatpak_app "app_id"
# Returns: 0 if found, 1 if not
search_flatpak_app() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        return 1
    fi

    # Get app config
    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    # Get flatpak app ID from config
    local flatpak_id
    flatpak_id=$(echo "$app_config" | jq -r '.flatpak_id // ""')

    if [[ -z "$flatpak_id" ]] || [[ "$flatpak_id" == "null" ]]; then
        return 1
    fi

    # Search for the app in flatpak
    if flatpak search "$flatpak_id" 2>/dev/null | grep -q "$flatpak_id"; then
        return 0
    fi

    return 1
}

# Get flatpak app ID from config
# Usage: get_flatpak_id "app_id"
# Returns: flatpak app ID or empty
get_flatpak_id() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        return 1
    fi

    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    echo "$app_config" | jq -r '.flatpak_id // ""'
}

# Install from Flatpak
# Usage: install_flatpak "app_id" "flatpak_id"
install_flatpak() {
    local app_id="${1:-}"
    local flatpak_id="${2:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "install_flatpak requires an app_id"
        return 1
    fi

    if [[ -z "$flatpak_id" ]]; then
        print_message FAIL "install_flatpak requires a flatpak_id"
        return 1
    fi

    # Check if Flatpak is available
    if ! check_flatpak_available; then
        print_message FAIL "Flatpak is not installed or configured"
        print_message INFO "Please install Flatpak first from System Apps"
        return 1
    fi

    # Get app configuration
    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    local app_name
    app_name=$(echo "$app_config" | jq -r '.name')

    local app_desc
    app_desc=$(echo "$app_config" | jq -r '.description // ""')

    print_message INFOFULL "Installing ${app_name} (Flatpak)"
    print_message INFO "${app_desc}"
    print_message INFO "Flatpak ID: ${flatpak_id}"

    # Show warnings if any
    ui_show_warnings "$app_id"

    # Confirm installation
    if ! ui_confirm "Install ${app_name} (Flatpak)" "Do you want to proceed with Flatpak installation?"; then
        print_message INFO "Installation cancelled by user"
        return 0
    fi

    # Check if already installed
    if flatpak list 2>/dev/null | grep -q "$flatpak_id"; then
        print_message WARN "${app_name} is already installed via Flatpak"

        if ! ui_confirm "Reinstall?" "${app_name} is already installed. Reinstall?"; then
            return 0
        fi

        remove_flatpak "$app_id" "$flatpak_id" || {
            print_message FAIL "Failed to remove existing installation"
            return 1
        }
    fi

    # Install from Flathub
    if gum spin --spinner dot --spinner.foreground "83" --title.foreground "83" --title "Installing ${app_name} from Flathub..." -- sudo flatpak install -y flathub "$flatpak_id"; then
        print_message PASS "${app_name} installed successfully via Flatpak"

        # Get installed version
        local installed_version
        installed_version=$(flatpak info "$flatpak_id" 2>/dev/null | grep "Version:" | awk '{print $2}' || echo "unknown")

        # Record in database with flatpak_id in metadata
        db_insert_app "$app_id" "$app_name" "flatpak" "$installed_version" "flatpak" "{\"flatpak_id\":\"${flatpak_id}\"}"

        ui_success "Installation Complete" "${app_name} v${installed_version} has been installed via Flatpak"
    else
        print_message FAIL "Flatpak installation failed"
        return 1
    fi
}

# Remove Flatpak installation
# Usage: remove_flatpak "app_id" ["flatpak_id"]
remove_flatpak() {
    local app_id="${1:-}"
    local flatpak_id="${2:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "remove_flatpak requires an app_id"
        return 1
    fi

    # Get app configuration
    local app_config
    app_config=$(get_app_config "$app_id") || return 1

    local app_name
    app_name=$(echo "$app_config" | jq -r '.name')

    print_message WARN "Removing ${app_name} (Flatpak)..."

    # Confirm removal
    if ! ui_confirm "Remove ${app_name}" "This will remove the Flatpak version of ${app_name}. Are you sure?"; then
        print_message INFO "Removal cancelled by user"
        return 0
    fi

    # If flatpak_id not provided, get it from database
    if [[ -z "$flatpak_id" ]]; then
        if db_is_installed "$app_id" 2>/dev/null; then
            # Parse metadata JSON string from database
            flatpak_id=$(db_get_app "$app_id" 2>/dev/null | jq -r '.[0].metadata | fromjson | .flatpak_id // ""' 2>/dev/null)
        fi

        if [[ -z "$flatpak_id" ]] || [[ "$flatpak_id" == "null" ]]; then
            print_message FAIL "No Flatpak ID found for ${app_name}"
            return 1
        fi
    fi

    # Check if installed
    if ! flatpak list 2>/dev/null | grep -q "$flatpak_id"; then
        print_message WARN "${app_name} is not installed via Flatpak"

        # Remove from database anyway if present
        if db_is_installed "$app_id" 2>/dev/null; then
            db_remove_app "$app_id"
        fi

        return 0
    fi

    # Remove flatpak
    if gum spin --spinner dot --spinner.foreground "83" --title.foreground "83" --title "Removing ${app_name}..." -- sudo flatpak uninstall -y "$flatpak_id"; then
        print_message PASS "${app_name} removed successfully"

        # Remove from database
        if db_is_installed "$app_id" 2>/dev/null; then
            db_remove_app "$app_id"
        fi

        ui_success "Removal Complete" "${app_name} has been removed from Flatpak"
    else
        print_message FAIL "Failed to remove Flatpak application"
        return 1
    fi
}

# Reinstall Flatpak application
# Usage: reinstall_flatpak "app_id" "flatpak_id"
reinstall_flatpak() {
    local app_id="${1:-}"
    local flatpak_id="${2:-}"

    if [[ -z "$app_id" ]] || [[ -z "$flatpak_id" ]]; then
        print_message FAIL "reinstall_flatpak requires app_id and flatpak_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    print_message INFO "Reinstalling ${app_name} (Flatpak)..."

    # Remove first (pass flatpak_id to avoid database lookup)
    remove_flatpak "$app_id" "$flatpak_id" || {
        print_message WARN "Removal failed, attempting fresh install anyway..."
    }

    # Install
    install_flatpak "$app_id" "$flatpak_id"
}

# Upgrade Flatpak application
# Usage: upgrade_flatpak "app_id" "flatpak_id"
upgrade_flatpak() {
    local app_id="${1:-}"
    local flatpak_id="${2:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "upgrade_flatpak requires an app_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    print_message INFO "Upgrading ${app_name} (Flatpak)..."

    # If no flatpak_id provided, get from database
    if [[ -z "$flatpak_id" ]]; then
        # Parse metadata JSON string from database
        flatpak_id=$(db_get_app "$app_id" 2>/dev/null | jq -r '.[0].metadata | fromjson | .flatpak_id // ""' 2>/dev/null)

        if [[ -z "$flatpak_id" ]] || [[ "$flatpak_id" == "null" ]]; then
            print_message FAIL "No Flatpak ID found for ${app_name}"
            return 1
        fi
    fi

    # Update flatpak
    if gum spin --spinner dot --spinner.foreground "83" --title.foreground "83" --title "Upgrading ${app_name}..." -- sudo flatpak update -y "$flatpak_id"; then
        print_message PASS "${app_name} upgraded successfully"

        # Update database version
        local new_version
        new_version=$(flatpak info "$flatpak_id" 2>/dev/null | grep "Version:" | awk '{print $2}' || echo "unknown")

        db_update_version "$app_id" "$new_version"

        ui_success "Upgrade Complete" "${app_name} has been upgraded to v${new_version}"
    else
        print_message FAIL "Flatpak upgrade failed"
        return 1
    fi
}
