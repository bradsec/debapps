#!/usr/bin/env bash

# Functions for working with .AppImage files.
# Requires: generic.sh template to be loaded first.

TEMPLATE_NAME="APPIMAGE"

# Get non-root user
function get_user() {
    if [[ $(command -v logname) ]] >/dev/null 2>&1; then
        echo -ne "$(logname)"
    elif [[ ! -z ${SUDO_USER} ]]; then
        echo -ne "${SUDO_USER}"
    elif [[ $(command -v whoami) ]] >/dev/null 2>&1; then
        echo -ne "$(whoami)"
    else
        echo -ne "${USER}"
    fi
}

setup_app_image() {
    local app_image_path=$(readlink -f "$1")

    if [[ -f "${app_image_path}" ]]; then
        print_message INFO "Setup AppImage: ${app_image_path}"
    else
        print_message FAIL "AppImage not found."
        return 0 
    fi

    local icon_dir="/usr/share/icons/hicolor"
    local desktop_dir="/usr/share/applications"

    # Extract the base name of the image file
    local app_image_filename=$(basename "${app_image_path}")

    # Remove the extension from the app_image_basename
    local app_image_name="${app_image_filename%.*}"

    # Convert the app_image_basename_no_ext to lowercase
    local app_image_name_lower=$(echo "${app_image_name}" | tr '[:upper:]' '[:lower:]')

    # Get app image directory
    local app_image_dir=$(dirname "${app_image_path}")

    # Install log file to help with removal
    local install_log_file="${app_image_dir}/install.log"

    # Log location of main app image
    echo "${app_image_path}" >> "${install_log_file}"

    # Set permissions and ownership and symbolic link
    run_command chmod 755 "${app_image_path}"
    run_command chown -R $(get_user):$(get_user) "${app_image_dir}"

    if [[ -z ${app_image_name_lower} ]]; then
        print_message FAIL "Unable get app image name for symbolic link."
        return 0
    else
        ln -sf "${app_image_path}" "/usr/sbin/${app_image_name_lower}"
        echo "/usr/sbin/${app_image_name_lower}" >> "${install_log_file}"
    fi

    print_message INFO "Extracting AppImage to find icon image and desktop config..."
    cd ${app_image_dir}
    run_command ${app_image_path} --appimage-extract
    local extract_dir="${app_image_dir}/squashfs-root"
    run_command chmod 755 "${extract_dir}"
    run_command chown -R $(get_user):$(get_user) "${extract_dir}"

    # Find application desktop configuration file
    local desktop_config=$(find ${app_image_dir} -type f -name "*.desktop" -print -quit | sed 's|^\./||')

    if [[ -e ${desktop_config} ]]; then
        print_message INFO "Desktop configuration file found."
        local desktop_config_filename=$(basename "$desktop_config")
        local clean_desktop_config_filename=$(echo "${desktop_config_filename}" | sed 's/[^[:alnum:].]//g')
        sed -i "s|^Exec=.*|Exec=${app_image_path} %U|" ${desktop_config}

        cp "${desktop_config}" "${desktop_dir}/${clean_desktop_config_filename}"
        echo "${desktop_dir}/${desktop_config_filename}" >> "${install_log_file}"

        local icon_name=$(grep '^Icon=' "${desktop_dir}/${clean_desktop_config_filename}" | cut -d '=' -f 2)
        local icon_image=$(find "$app_image_dir" -type f -name "*${icon_name}*.png" -print -quit | sed 's|^\./||')
    else
        print_message FAIL "Unable to find a .desktop configuration file for ${app_image_name}."
        return 0
    fi

    # Loop through each icon size and convert/copy the image
    if [[ -e ${icon_image} ]]; then
        print_message INFO "Adding AppImage desktop icon images..."
        # Define the desired icon sizes
        local icon_sizes=("16x16" "22x22" "24x24" "32x32" "36x36" "48x48" "64x64" "72x72" "96x96" "128x128" "192x192" "256x256" "512x512")
        for size in "${icon_sizes[@]}"; do
            local sized_icon_image=$(find "$app_image_dir" -type f -wholename "*/${size}/${icon_name}.png" -print -quit | sed 's|^\./||')
            local target_path="${icon_dir}/${size}/apps"
            local target_file="${target_path}/${icon_name}.png"

            if [[ -e ${sized_icon_image} ]]; then
                local icon_image="${sized_icon_image}"
            else
                local icon_image=$(find "$app_image_dir" -type f -name "*${icon_name}*.png" -print -quit | sed 's|^\./||')
            fi

            echo "${target_path}/${icon_name}.png" >> "${install_log_file}"

            # Create the target directory if it doesn't exist
            if [[ ! -d "$target_path" ]]; then
                run_command mkdir -p "$target_path"
            fi

            # If 'convert' command is available, resize the image; otherwise, copy the original image
            if command -v convert >/dev/null 2>&1; then
                run_command convert "$icon_image" -resize "$size" "$target_file"
            else
                run_command cp "$icon_image" "$target_file"
            fi
        done
        # Force overwrite icon image cache
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            print_message INFO "Refreshing desktop icon image cache..."
            run_command gtk-update-icon-cache -f /usr/share/icons/hicolor
        fi
    else
        print_message FAIL "Unable to find a icon image file for ${app_image_name}."
        return 0 
    fi

    # Clean up
    print_message INFO "Running cleanup..."
    local extract_dir="${app_image_dir}/squashfs-root"
    if [[ -d "${extract_dir}" && ! -z "${extract_dir}" ]]; then
        run_command rm -rf "${extract_dir}"
    fi
    print_message DONE "${app} installed. Use the desktop icon or terminal command to launch."
}

remove_app_image() {
    local app_image_dir="$1"

    # Check if app_image_dir exists
    if [[ ! "${app_image_dir}" || ! -d "${app_image_dir}" ]]; then
        print_message FAIL "AppImage directory not found: ${app_image_dir}"
        return 0
    else
        log_file="${app_image_dir}/install.log"
    fi

    # Check if log_file exists
    if [[ ! -f "${log_file}" ]]; then
        print_message FAIL "The AppImage installation log file does not exist: ${log_file}"
        return 0
    fi

    # Check if log_file ends with ".log" and contains "/opt"
    if [[ "${log_file}" != *.log || "${log_file}" != */opt/* ]]; then
        print_message FAIL "Invalid log file. Expected a file with .log extension and located in /opt directory."
        return 0
    fi

    # Read the first line of the log file
    read -r first_line < "${log_file}"

    local app_image_filename=$(basename "${first_line}")
    local app_image_dir=$(dirname "${first_line}")

    # Check for .AppImage and path contains "/opt"
    if [[ "${app_image_filename}" != *.AppImage || "${app_image_dir}" != */opt/* ]]; then
        print_message FAIL "Invalid AppImage removal location. Expected a file with .AppImage extension and located in /opt directory."
        return 0
    fi

    print_message INFO "Removing files and directories associated with: ${app_image_filename}..."

    local removed_entries=()

    while IFS= read -r line; do
        if [[ -f "$line" ]]; then
            if ! [[ "${removed_entries[*]}" =~ "$line" ]]; then
                print_message INFO "Removing file: ${line}"
                rm "$line"
                removed_entries+=("$line")
            fi
        elif [[ -d "$line" ]]; then
            if ! [[ "${removed_entries[*]}" =~ "$line" ]]; then
                print_message INFO "Removing directory: ${line}"
                rm -rf "$line"
                removed_entries+=("$line")
            fi
        else
            continue
        fi
    done < "${log_file}"

    print_message INFO "Removing base app image directory: ${app_image_dir}"
    rm -rf "${app_image_dir}"
    print_message DONE "${app} removed."
}

print_message INFO "${TEMPLATE_NAME} TEMPLATE IMPORTED."