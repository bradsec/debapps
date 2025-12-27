#!/usr/bin/env bash

# AppImage handling functions
# Refactored from src/templates/appimage.tmpl.sh
# Requires: core/common.sh to be loaded first

set -euo pipefail

# Setup AppImage - extract, install icons, create desktop entry
# Usage: setup_app_image "/path/to/app.AppImage" "/opt/install/location" "App Name"
setup_app_image() {
    local app_image_path
    app_image_path="$(readlink -f "${1:-}")"

    local install_location="${2:-}"
    local app_name="${3:-}"

    # Validate input
    if [[ -z "$app_image_path" ]]; then
        print_message FAIL "setup_app_image requires an AppImage path"
        return 1
    fi

    if [[ -z "$install_location" ]]; then
        print_message FAIL "setup_app_image requires an install location"
        return 1
    fi

    if [[ ! -f "${app_image_path}" ]]; then
        print_message FAIL "AppImage not found: ${app_image_path}"
        return 1
    fi

    print_message INFO "Setup AppImage: ${app_image_path}"

    # Create install directory and set proper ownership
    print_message INFO "Creating directory: ${install_location}"
    sudo mkdir -p "${install_location}"

    # Get current user
    local current_user
    current_user="$(get_user)"

    # Set ownership of install directory to user
    sudo chown "${current_user}:${current_user}" "${install_location}"

    # Extract the base name of the image file
    local app_image_filename
    app_image_filename="$(basename "${app_image_path}")"

    # Move AppImage to permanent location in /opt
    local permanent_path="${install_location}/${app_image_filename}"
    print_message INFO "Moving AppImage to: ${permanent_path}"
    sudo mv "${app_image_path}" "${permanent_path}"

    # Update app_image_path to permanent location
    app_image_path="${permanent_path}"

    local icon_dir="/usr/share/icons/hicolor"
    local desktop_dir="/usr/share/applications"

    # Extract the base name of the image file
    local app_image_filename
    app_image_filename="$(basename "${app_image_path}")"

    # Remove the extension from the filename
    local app_image_name="${app_image_filename%.*}"

    # Convert to lowercase for symlink
    local app_image_name_lower
    app_image_name_lower="$(echo "${app_image_name}" | tr '[:upper:]' '[:lower:]')"

    # Get app image directory
    local app_image_dir
    app_image_dir="$(dirname "${app_image_path}")"

    # Install log file to help with removal
    local install_log_file="${app_image_dir}/install.log"

    # Log location of main app image
    echo "${app_image_path}" > "${install_log_file}"

    # Set permissions and ownership
    run_command chmod 755 "${app_image_path}"
    run_command chown "${current_user}:${current_user}" "${app_image_path}"

    # Create symbolic link
    if [[ -z "${app_image_name_lower}" ]]; then
        print_message FAIL "Unable to get app image name for symbolic link."
        return 1
    fi

    print_message INFO "Creating symbolic link: /usr/sbin/${app_image_name_lower}"
    run_command sudo ln -sf "${app_image_path}" "/usr/sbin/${app_image_name_lower}"
    echo "/usr/sbin/${app_image_name_lower}" >> "${install_log_file}"

    # Extract AppImage to find icon and desktop config
    print_message INFO "Extracting AppImage to find icon image and desktop config..."

    cd "${app_image_dir}" || {
        print_message FAIL "Unable to change to directory: ${app_image_dir}"
        return 1
    }

    run_command "${app_image_path}" --appimage-extract

    local extract_dir="${app_image_dir}/squashfs-root"

    if [[ ! -d "${extract_dir}" ]]; then
        print_message FAIL "AppImage extraction failed - squashfs-root not found"
        return 1
    fi

    run_command chmod 755 "${extract_dir}"
    # No need to chown extracted directory - will be cleaned up anyway

    # Find application desktop configuration file
    local desktop_config
    desktop_config=$(find "${extract_dir}" -type f -name "*.desktop" -print -quit 2>/dev/null | sed 's|^\./||')

    if [[ ! -e "${desktop_config}" ]]; then
        print_message FAIL "Unable to find a .desktop configuration file for ${app_image_name}."

        # Cleanup extraction directory
        rm -rf "${extract_dir}"
        return 1
    fi

    print_message INFO "Desktop configuration file found: ${desktop_config}"

    local desktop_config_filename
    desktop_config_filename=$(basename "$desktop_config")

    # Keep original filename (don't sanitize - it's already valid from the AppImage)
    local clean_desktop_config_filename="${desktop_config_filename}"

    # Update Exec path in desktop file to use absolute path
    sed -i "s|^Exec=.*|Exec=${app_image_path} %U|" "${desktop_config}"

    # Ensure Type is set
    if ! grep -q "^Type=" "${desktop_config}"; then
        sed -i '/^\[Desktop Entry\]/a Type=Application' "${desktop_config}"
    fi

    # Ensure Terminal is set to false
    if grep -q "^Terminal=" "${desktop_config}"; then
        sed -i "s|^Terminal=.*|Terminal=false|" "${desktop_config}"
    else
        sed -i '/^\[Desktop Entry\]/a Terminal=false' "${desktop_config}"
    fi

    # Ensure Categories field exists (required for desktop menu visibility)
    if ! grep -q "^Categories=" "${desktop_config}"; then
        print_message WARN "Desktop file missing Categories field, adding default"
        sed -i '/^\[Desktop Entry\]/a Categories=Utility;' "${desktop_config}"
    fi

    # Ensure StartupNotify is set
    if ! grep -q "^StartupNotify=" "${desktop_config}"; then
        sed -i '/^\[Desktop Entry\]/a StartupNotify=true' "${desktop_config}"
    fi

    # Remove NoDisplay if present (would hide from menus)
    if grep -q "^NoDisplay=true" "${desktop_config}"; then
        print_message WARN "Removing NoDisplay=true from desktop file"
        sed -i '/^NoDisplay=true/d' "${desktop_config}"
    fi

    # Validate desktop file before installing
    if command -v desktop-file-validate &>/dev/null; then
        print_message INFO "Validating desktop file..."
        if desktop-file-validate "${desktop_config}" &>/dev/null; then
            print_message PASS "Desktop file is valid"
        else
            print_message WARN "Desktop file has validation warnings (will install anyway)"
        fi
    fi

    # Install desktop file using desktop-file-install (proper method)
    if command -v desktop-file-install &>/dev/null; then
        print_message INFO "Installing desktop file using desktop-file-install..."
        run_command sudo desktop-file-install --dir="${desktop_dir}" "${desktop_config}"
    else
        # Fallback to manual copy
        print_message INFO "Installing desktop file manually..."
        run_command sudo cp "${desktop_config}" "${desktop_dir}/${clean_desktop_config_filename}"
        run_command sudo chmod 644 "${desktop_dir}/${clean_desktop_config_filename}"
    fi

    echo "${desktop_dir}/${clean_desktop_config_filename}" >> "${install_log_file}"

    print_message INFO "Desktop file installed: ${desktop_dir}/${clean_desktop_config_filename}"

    # Extract icon name from desktop file
    local icon_name
    icon_name=$(grep '^Icon=' "${desktop_dir}/${clean_desktop_config_filename}" | cut -d '=' -f 2)

    # Find icon image
    local icon_image
    icon_image=$(find "${extract_dir}" -type f -name "*${icon_name}*.png" -print -quit 2>/dev/null | sed 's|^\./||')

    if [[ ! -e "${icon_image}" ]]; then
        print_message WARN "Unable to find icon image file for ${app_image_name}. Skipping icon installation."

        # Cleanup extraction directory
        rm -rf "${extract_dir}"
        return 0
    fi

    # Install icons at multiple resolutions
    print_message INFO "Adding AppImage desktop icon images..."

    # Define the desired icon sizes
    local icon_sizes=("16x16" "22x22" "24x24" "32x32" "36x36" "48x48" "64x64" "72x72" "96x96" "128x128" "192x192" "256x256" "512x512")

    for size in "${icon_sizes[@]}"; do
        local sized_icon_image
        sized_icon_image=$(find "${extract_dir}" -type f -wholename "*/${size}/${icon_name}.png" -print -quit 2>/dev/null | sed 's|^\./||')

        local target_path="${icon_dir}/${size}/apps"
        local target_file="${target_path}/${icon_name}.png"

        # Use size-specific icon if available, otherwise use generic icon
        local source_icon
        if [[ -e "${sized_icon_image}" ]]; then
            source_icon="${sized_icon_image}"
        else
            source_icon="${icon_image}"
        fi

        echo "${target_file}" >> "${install_log_file}"

        # Create the target directory if it doesn't exist
        if [[ ! -d "$target_path" ]]; then
            run_command sudo mkdir -p "$target_path"
        fi

        # If ImageMagick 'convert' is available, resize; otherwise copy original
        if command -v convert &>/dev/null; then
            run_command sudo convert "$source_icon" -resize "$size" "$target_file"
        else
            run_command sudo cp "$source_icon" "$target_file"
        fi
    done

    # Force update icon cache
    if command -v gtk-update-icon-cache &>/dev/null; then
        print_message INFO "Refreshing desktop icon image cache..."
        run_command sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor
    fi

    # Update desktop database for application menu discovery
    if command -v update-desktop-database &>/dev/null; then
        print_message INFO "Updating desktop application database..."
        run_command sudo update-desktop-database /usr/share/applications
    fi

    # Refresh desktop environment (best effort)
    print_message INFO "Notifying desktop environment of changes..."

    # Try to refresh the desktop environment
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        case "${XDG_CURRENT_DESKTOP}" in
            *GNOME*|*gnome*)
                # GNOME usually picks up changes automatically
                print_message INFO "GNOME detected - changes should appear within a few seconds"
                ;;
            *KDE*|*kde*)
                # KDE needs kbuildsycoca to refresh
                if command -v kbuildsycoca5 &>/dev/null; then
                    run_command kbuildsycoca5 --noincremental 2>/dev/null || true
                elif command -v kbuildsycoca6 &>/dev/null; then
                    run_command kbuildsycoca6 --noincremental 2>/dev/null || true
                fi
                print_message INFO "KDE cache updated"
                ;;
            *XFCE*|*xfce*)
                # XFCE panel restart
                if command -v xfce4-panel &>/dev/null; then
                    run_command xfce4-panel --restart 2>/dev/null || true
                fi
                print_message INFO "XFCE panel restarted"
                ;;
        esac
    fi

    # Clean up extraction directory
    print_message INFO "Running cleanup..."
    if [[ -d "${extract_dir}" && -n "${extract_dir}" ]]; then
        run_command rm -rf "${extract_dir}"
    fi

    print_message DONE "${app_image_name} installed successfully!"
    echo
    print_message INFO "Desktop integration complete. The application should appear in your menu."
    print_message INFO "If you don't see it immediately:"
    print_message INFO "  1. Wait a few seconds for desktop to refresh"
    print_message INFO "  2. Try searching for '${app_name}' in your application launcher"
    print_message INFO "  3. If still not visible, log out and log back in"
    echo
}

# Remove AppImage and associated files
# Usage: remove_app_image "/opt/appname"
remove_app_image() {
    local app_image_dir="${1:-}"

    # Validate input
    if [[ -z "${app_image_dir}" ]]; then
        print_message FAIL "remove_app_image requires an AppImage directory path"
        return 1
    fi

    # Check if app_image_dir exists
    if [[ ! -d "${app_image_dir}" ]]; then
        print_message FAIL "AppImage directory not found: ${app_image_dir}"
        return 1
    fi

    local log_file="${app_image_dir}/install.log"

    # Check if log_file exists
    if [[ ! -f "${log_file}" ]]; then
        print_message FAIL "The AppImage installation log file does not exist: ${log_file}"
        print_message INFO "You may need to manually remove files from ${app_image_dir}"
        return 1
    fi

    # Security check: log_file must end with ".log" and contain "/opt"
    if [[ "${log_file}" != *.log ]] || [[ "${log_file}" != */opt/* ]]; then
        print_message FAIL "Invalid log file. Expected a file with .log extension and located in /opt directory."
        return 1
    fi

    # Read the first line of the log file
    local first_line
    read -r first_line < "${log_file}" || {
        print_message FAIL "Unable to read log file: ${log_file}"
        return 1
    }

    local app_image_filename
    app_image_filename=$(basename "${first_line}")

    local app_image_path_dir
    app_image_path_dir=$(dirname "${first_line}")

    # Security check: must be .AppImage and path must contain "/opt"
    if [[ "${app_image_filename}" != *.AppImage ]] || [[ "${app_image_path_dir}" != */opt/* ]]; then
        print_message FAIL "Invalid AppImage removal location. Expected a file with .AppImage extension and located in /opt directory."
        return 1
    fi

    print_message INFO "Removing files and directories associated with: ${app_image_filename}..."

    local removed_entries=()

    # Read log file and remove each entry
    while IFS= read -r line; do
        # Skip empty lines
        if [[ -z "$line" ]]; then
            continue
        fi

        # Security: validate that the path is safe and expected
        # Must not contain ".." (directory traversal)
        # Must start with allowed paths
        if [[ "$line" =~ \.\. ]] || [[ ! "$line" =~ ^(/opt/|/usr/share/|/usr/sbin/) ]]; then
            print_message WARN "Skipping invalid or unsafe path: ${line}"
            continue
        fi

        # Skip if already removed
        if [[ " ${removed_entries[*]} " =~ " ${line} " ]]; then
            continue
        fi

        # Remove file or directory
        if [[ -f "$line" ]]; then
            print_message INFO "Removing file: ${line}"
            sudo rm -f "$line"
            removed_entries+=("$line")
        elif [[ -d "$line" ]]; then
            print_message INFO "Removing directory: ${line}"
            sudo rm -rf "$line"
            removed_entries+=("$line")
        else
            # Entry doesn't exist, skip
            continue
        fi
    done < "${log_file}"

    # Remove base app image directory
    print_message INFO "Removing base app image directory: ${app_image_dir}"
    sudo rm -rf "${app_image_dir}"

    # Update desktop database after removal
    if command -v update-desktop-database &>/dev/null; then
        print_message INFO "Updating desktop application database..."
        sudo update-desktop-database /usr/share/applications 2>/dev/null || true
    fi

    # Update icon cache after removal
    if command -v gtk-update-icon-cache &>/dev/null; then
        print_message INFO "Updating icon cache..."
        sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    fi

    print_message DONE "AppImage removed successfully."
}
