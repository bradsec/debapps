#!/usr/bin/env bash

# Modern UI system for DEBAPPS using Gum
# https://github.com/charmbracelet/gum
# Requires: core/common.sh, gum

set -euo pipefail

# Gum color scheme - Green only (retro CRT) - ANSI 256-color for compatibility
UI_PRIMARY_COLOR="83"      # Bright Green (ANSI color 83) - selected/active
UI_SUCCESS_COLOR="83"      # Bright Green
UI_WARNING_COLOR="83"      # Bright Green (warnings also green)
UI_ERROR_COLOR="203"       # Red (ANSI color 203) - errors only
UI_INFO_COLOR="83"         # Bright Green
UI_BORDER_COLOR="83"       # Bright Green
UI_TEXT_COLOR="83"         # Bright Green
UI_UNSELECTED_COLOR="28"   # Dull Green (ANSI color 28) - unselected items

ASCII_BANNER=$(cat <<EOF 
      ____  __________  ___    ____  ____  _____
     / __ \/ ____/ __ )/   |  / __ \/ __ \/ ___/
    / / / / __/ / __  / /| | / /_/ / /_/ /\__ \\
   / /_/ / /___/ /_/ / ___ |/ ____/ ____/___/ /
/_____/_____/_____/_/  |_/_/   /_/    /____/


Debian Application Installer v2.0
Bash scripts to simplify Linux app installations

EOF
)

# Check and install Gum if needed
check_gum() {
    if ! command -v gum &>/dev/null; then
        print_message INFO "Gum is required for the modern UI. Installing..."

        if pkgmgr install gum; then
            print_message PASS "Gum installed successfully"
        else
            print_message FAIL "Failed to install Gum"
            print_message INFO "You can install it manually: apt install gum"
            return 1
        fi
    fi
}

# Display styled header
# Usage: ui_header ["subtitle"]
ui_header() {
    local subtitle="${1:-}"

    # Clear output to tty so it doesn't get captured by command substitution
    clear >&2

    local sub_banner_content  
    sub_banner_content=$(cat <<EOF
${ASCII_BANNER}

${subtitle}

EOF
    )
    # Output to stderr so it doesn't get captured by command substitution
    gum style \
        --foreground "$UI_PRIMARY_COLOR" \
        --border none \
        --border-foreground "$UI_PRIMARY_COLOR" \
        --align center \
        --width 70 \
        --margin "1 2" \
        --padding "1 2" \
        "${sub_banner_content}" >&2
}

# Display banner with header (for first menu)
# Usage: ui_banner_header "subtitle"
ui_banner_header() {
    local subtitle="${1:-}"

    # Clear output to tty so it doesn't get captured by command substitution
    clear >&2

    # Get system information
    local date_time
    date_time=$(date +"%d-%b-%Y %H:%M:%S")

    local os_info=""
    local hardware_info=""

    if command -v lsb_release &>/dev/null; then
        local dist
        dist=$(lsb_release -d --short 2>/dev/null)
        local arch
        arch=$(uname -m 2>/dev/null)
        local hardware
        hardware=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)

        os_info="${dist} ${arch}"
        hardware_info="${hardware}"
    fi

    # Build banner content using heredoc for proper formatting
    local banner_content  
    banner_content=$(cat <<EOF
${ASCII_BANNER}

Date/Time: ${date_time}
OS: ${os_info}
Hardware: ${hardware_info}

EOF
)

    # Output to stderr so it doesn't get captured by command substitution
    gum style \
        --foreground "$UI_PRIMARY_COLOR" \
        --border none  \
        --border-foreground "$UI_PRIMARY_COLOR" \
        --align center \
        --width 70 \
        --margin "1 2" \
        --padding "1 2" \
        "${banner_content}" >&2
}

# Display category selection menu
# Usage: ui_category_menu
# Returns: category_id (or empty on cancel)
ui_category_menu() {
    if [[ -z "$CONFIG_JSON" ]]; then
        print_message FAIL "Configuration not loaded"
        return 1
    fi

    # Use banner header for first menu
    ui_banner_header "Select a category"

    # Build category options
    local categories
    categories=$(get_categories)

    # Check if we got categories
    if [[ -z "$categories" ]]; then
        print_message FAIL "No categories found in configuration"
        return 1
    fi

    local options=()
    local ids=()

    # Process each category line
    while IFS=: read -r cat_id cat_name cat_desc; do
        # Skip empty lines
        [[ -z "$cat_id" ]] && continue

        ids+=("$cat_id")
        if [[ -n "$cat_desc" ]]; then
            options+=("${cat_name} - ${cat_desc}")
        else
            options+=("${cat_name}")
        fi
    done <<< "$categories"

    # Add exit option
    options+=("Exit")

    # Display menu using gum choose with arguments (not piping)
    local choice
    local exit_code=0
    choice=$(gum choose \
            --header $'Choose a category:\n' \
            --header.foreground "$UI_PRIMARY_COLOR" \
            --header.bold \
            --cursor "> " \
            --cursor.foreground "$UI_PRIMARY_COLOR" \
            --selected.foreground "$UI_PRIMARY_COLOR" \
            --selected.bold \
            --item.foreground "$UI_UNSELECTED_COLOR" \
            --height 15 \
            "${options[@]}") || exit_code=$?

    # Check if user cancelled (ESC pressed)
    if [[ $exit_code -ne 0 ]]; then
        return 1
    fi

    # Handle exit
    if [[ "$choice" == "Exit" ]] || [[ -z "$choice" ]]; then
        return 1
    fi

    # Find matching category ID
    for i in "${!options[@]}"; do
        if [[ "${options[$i]}" == "$choice" ]]; then
            echo "${ids[$i]}"
            return 0
        fi
    done

    return 1
}

# Display app selection menu with status indicators
# Usage: ui_app_menu "category_id"
# Returns: app_id (or empty on back)
ui_app_menu() {
    local category_id="${1:-}"

    if [[ -z "$category_id" ]]; then
        print_message FAIL "ui_app_menu requires a category_id"
        return 1
    fi

    local category_name
    category_name=$(get_category_name "$category_id")

    ui_header "${category_name}"

    # Build app options with status
    local apps
    apps=$(get_apps_by_category "$category_id")

    # Check if we got any apps
    if [[ -z "$apps" ]]; then
        print_message WARN "No applications found in this category"
        sleep 2
        return 1
    fi

    local options=()
    local ids=()

    # Process each app line
    while IFS=: read -r app_id app_name app_desc; do
        # Skip empty lines
        [[ -z "$app_id" ]] && continue

        ids+=("$app_id")

        # Get installation status
        local status_indicator="[ ]"  # Not installed

        # Check if in database
        if db_is_installed "$app_id" 2>/dev/null; then
            status_indicator="[*]"  # Installed
        fi

        # Format option with status
        options+=("${status_indicator} ${app_name} - ${app_desc}")
    done <<< "$apps"

    # Final check if we have any apps
    if [[ ${#options[@]} -eq 0 ]]; then
        print_message WARN "No applications were parsed"
        sleep 2
        return 1
    fi

    # Add back option
    options+=("< Back to Categories")

    # Display menu using arguments instead of piping
    local choice
    local exit_code=0
    choice=$(gum choose \
            --header $'Select an application:\n' \
            --header.foreground "$UI_PRIMARY_COLOR" \
            --header.bold \
            --cursor "> " \
            --cursor.foreground "$UI_PRIMARY_COLOR" \
            --selected.foreground "$UI_PRIMARY_COLOR" \
            --selected.bold \
            --item.foreground "$UI_UNSELECTED_COLOR" \
            --height 20 \
            "${options[@]}") || exit_code=$?

    # Check if user cancelled (ESC pressed)
    if [[ $exit_code -ne 0 ]]; then
        return 1
    fi

    # Handle back
    if [[ "$choice" == "< Back to Categories" ]] || [[ -z "$choice" ]]; then
        return 1
    fi

    # Find matching app ID
    for i in "${!options[@]}"; do
        if [[ "${options[$i]}" == "$choice" ]]; then
            echo "${ids[$i]}"
            return 0
        fi
    done

    return 1
}

# Display action menu (install/remove/info)
# Usage: ui_action_menu "app_id"
# Returns: action (install/remove/reinstall/info or empty on back)
ui_action_menu() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "ui_action_menu requires an app_id"
        return 1
    fi

    local app_name
    app_name=$(get_app_name "$app_id")

    ui_header "${app_name}"

    # Build action options based on installation status
    local options=()
    local is_installed=false

    if db_is_installed "$app_id" 2>/dev/null; then
        is_installed=true
    fi

    if [[ "$is_installed" == true ]]; then
        options+=("Reinstall ${app_name}")
        options+=("Remove ${app_name}")
        options+=("Show Information")
    else
        options+=("Install ${app_name}")
        options+=("Show Information")
    fi

    options+=("< Back")

    # Display menu using arguments instead of piping
    local choice
    local exit_code=0
    choice=$(gum choose \
            --header $'What would you like to do?\n' \
            --header.foreground "$UI_PRIMARY_COLOR" \
            --header.bold \
            --cursor "> " \
            --cursor.foreground "$UI_PRIMARY_COLOR" \
            --selected.foreground "$UI_PRIMARY_COLOR" \
            --selected.bold \
            --item.foreground "$UI_UNSELECTED_COLOR" \
            "${options[@]}") || exit_code=$?

    # Check if user cancelled (ESC pressed)
    if [[ $exit_code -ne 0 ]]; then
        return 1
    fi

    # Handle back
    if [[ "$choice" == "< Back" ]] || [[ -z "$choice" ]]; then
        return 1
    fi

    # Map choice to action
    case "$choice" in
        *"Install"*)
            echo "install"
            ;;
        *"Reinstall"*)
            echo "reinstall"
            ;;
        *"Remove"*)
            echo "remove"
            ;;
        *"Information"*)
            echo "info"
            ;;
        *)
            return 1
            ;;
    esac
}

# Confirmation dialog
# Usage: ui_confirm "Title" "Message"
# Returns: 0 for yes, 1 for no
ui_confirm() {
    local title="${1:-Confirm}"
    local message="${2:-Are you sure?}"

    gum style \
        --foreground "$UI_PRIMARY_COLOR" \
        --border rounded \
        --border-foreground "$UI_PRIMARY_COLOR" \
        --padding "1 2" \
        --margin "1 0" \
        "${title}"

    # Display message in green
    printf '\033[38;5;83m%s\033[38;5;83m\n\n' "$message"

    gum confirm \
        --affirmative "Yes" \
        --negative "No" \
        --prompt.foreground "$UI_PRIMARY_COLOR" \
        --selected.foreground "0" \
        --selected.background "$UI_PRIMARY_COLOR" \
        --unselected.foreground "0" \
        --unselected.background "$UI_UNSELECTED_COLOR"
}

# Information display
# Usage: ui_info "Title" "Message"
ui_info() {
    local title="${1:-Information}"
    local message="${2:-}"

    gum style \
        --foreground "$UI_PRIMARY_COLOR" \
        --border rounded \
        --border-foreground "$UI_PRIMARY_COLOR" \
        --padding "1 2" \
        --margin "1 0" \
        "${title}"

    printf '\033[38;5;83m%s\033[38;5;83m\n\n' "$message"

    gum style --foreground "$UI_PRIMARY_COLOR" "Press Enter to continue..."
    read -r
}

# Error display
# Usage: ui_error "Title" "Message"
ui_error() {
    local title="${1:-Error}"
    local message="${2:-An error occurred}"

    gum style \
        --foreground "$UI_ERROR_COLOR" \
        --border rounded \
        --border-foreground "$UI_ERROR_COLOR" \
        --padding "1 2" \
        --margin "1 0" \
        "[ERROR] ${title}"

    printf '\033[38;5;83m%s\033[38;5;83m\n\n' "$message"

    gum style --foreground "$UI_PRIMARY_COLOR" "Press Enter to continue..."
    read -r
}

# Success display
# Usage: ui_success "Title" "Message"
ui_success() {
    local title="${1:-Success}"
    local message="${2:-Operation completed successfully}"

    gum style \
        --foreground "$UI_PRIMARY_COLOR" \
        --border rounded \
        --border-foreground "$UI_PRIMARY_COLOR" \
        --padding "1 2" \
        --margin "1 0" \
        "[SUCCESS] ${title}"

    printf '\033[38;5;83m%s\033[38;5;83m\n\n' "$message"

    gum style --foreground "$UI_PRIMARY_COLOR" "Press Enter to continue..."
    read -r
}

# Show progress spinner
# Usage: ui_spinner "Message" command args...
ui_spinner() {
    local message="${1:-Processing...}"
    shift

    gum spin \
        --spinner dot \
        --title "$message" \
        --title.foreground "$UI_PRIMARY_COLOR" \
        -- "$@"
}

# Show app information
# Usage: ui_show_app_info "app_id"
ui_show_app_info() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        print_message FAIL "ui_show_app_info requires an app_id"
        return 1
    fi

    local app_config
    app_config=$(get_app_config "$app_id")

    local app_name
    app_name=$(echo "$app_config" | jq -r '.name')

    local app_desc
    app_desc=$(echo "$app_config" | jq -r '.description // "No description"')

    local install_method
    install_method=$(echo "$app_config" | jq -r '.install_method')

    ui_header "App Information" "${app_name}"

    gum style \
        --foreground "$UI_PRIMARY_COLOR" \
        --margin "1 0" \
        "Description: ${app_desc}"

    gum style \
        --foreground "$UI_PRIMARY_COLOR" \
        --margin "1 0" \
        "Install Method: ${install_method}"

    # Show installation status
    if db_is_installed "$app_id" 2>/dev/null; then
        local db_info
        db_info=$(db_get_app "$app_id" 2>/dev/null | jq -r '.[0]')

        local version
        version=$(echo "$db_info" | jq -r '.version // "unknown"')

        local install_date
        install_date=$(echo "$db_info" | jq -r '.install_date')

        local install_date_formatted
        if [[ -n "$install_date" ]] && [[ "$install_date" != "null" ]]; then
            install_date_formatted=$(date -d "@$install_date" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
        else
            install_date_formatted="unknown"
        fi

        gum style \
            --foreground "$UI_PRIMARY_COLOR" \
            --margin "1 0" \
            "Status: Installed"

        gum style \
            --foreground "$UI_PRIMARY_COLOR" \
            --margin "1 0" \
            "Version: ${version}"

        gum style \
            --foreground "$UI_PRIMARY_COLOR" \
            --margin "1 0" \
            "Installed: ${install_date_formatted}"
    else
        gum style \
            --foreground "$UI_PRIMARY_COLOR" \
            --margin "1 0" \
            "Status: Not Installed"
    fi

    echo
    gum style --foreground "$UI_PRIMARY_COLOR" "Press Enter to continue..."
    read -r
}

# Format status indicator for app
# Usage: format_status_indicator "app_id"
# Returns: colored status text
format_status_indicator() {
    local app_id="${1:-}"

    if db_is_installed "$app_id" 2>/dev/null; then
        echo "[Installed]"
    else
        echo "[Not Installed]"
    fi
}

# Input prompt
# Usage: ui_input "Prompt" ["placeholder"]
ui_input() {
    local prompt="${1:-Enter value:}"
    local placeholder="${2:-}"

    local result
    if [[ -n "$placeholder" ]]; then
        result=$(gum input \
            --placeholder "$placeholder" \
            --prompt "$prompt " \
            --prompt.foreground "$UI_PRIMARY_COLOR")
    else
        result=$(gum input \
            --prompt "$prompt " \
            --prompt.foreground "$UI_PRIMARY_COLOR")
    fi

    echo "$result"
}

# Show warnings before installation
# Usage: ui_show_warnings "app_id"
ui_show_warnings() {
    local app_id="${1:-}"

    if [[ -z "$app_id" ]]; then
        return 0
    fi

    local app_config
    app_config=$(get_app_config "$app_id")

    # Check if there are warnings
    local warnings
    warnings=$(echo "$app_config" | jq -r '.warnings[]? // empty' 2>/dev/null)

    if [[ -z "$warnings" ]]; then
        return 0
    fi

    gum style \
        --foreground "$UI_PRIMARY_COLOR" \
        --border rounded \
        --border-foreground "$UI_PRIMARY_COLOR" \
        --padding "1 2" \
        --margin "1 0" \
        "[WARNING]"

    echo "$warnings" | while IFS= read -r warning; do
        gum style --foreground "$UI_PRIMARY_COLOR" "  • ${warning}"
    done

    echo
}

# Initialize UI system
# Usage: ui_init
ui_init() {
    # Check for Gum
    check_gum || {
        print_message FAIL "UI system requires Gum. Cannot continue."
        return 1
    }

    print_message PASS "UI system initialized (Gum)"
}
