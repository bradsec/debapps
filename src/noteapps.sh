#!/usr/bin/env bash

SCRIPT_SOURCE="$(basename -- "$0")"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh" "appimage.tmpl.sh" "apps.tmpl.sh")

# Imports bash script functions from a local template or the github hosted template file.
import_templates() {
  local templates_remote="https://raw.githubusercontent.com/bradsec/debapps/main/src/templates/"
  # Set templates_local to relative path to clone repo. Different from debapps.sh
  local templates_local="${SCRIPT_DIR}/templates/"
  for tmpl in "${TEMPLATES_REQUIRED[@]}"; do
    if [[ -f "${templates_local}${tmpl}" ]]; then
      # shellcheck disable=SC1090
      source "${templates_local}${tmpl}" || echo -e "An error occurred in template import."
    else
      local remote_template="${templates_remote}${tmpl}"
      if wget -q --spider "${remote_template}"; then
        # Download the remote template to a temporary file
        local tmp_template_file
        tmp_template_file=$(mktemp)
        wget -qO "${tmp_template_file}" "${remote_template}"
        
        # Source the temporary file and then remove it
        # shellcheck disable=SC1090
        source "${tmp_template_file}" || echo -e "An error occurred in template import."
        rm "${tmp_template_file}"
      else
        echo -e "Unable to import required template: \"${tmpl}\". Exiting..."
        exit 1
      fi
    fi
  done
}

import_templates
import_app_manifest
# shellcheck disable=SC2154 # Variables from sourced templates
print_message PASS "${SCRIPT_SOURCE} active."
### END OF REQUIRED FUNCTION ###

function display_menu () {
    local menu_options=(
        "Install Joplin"
        "Install Standard Notes"
        "Install Obsidian"
        "Remove Joplin"
        "Remove Standard Notes"
        "Remove Obsidian"
        "Check download links"
        "Exit"
    )

    while :
    do
        choice=$(menu_select "Note Apps" "${menu_options[@]}")
        case $choice in
        1)  clear
            install_manifest_app joplin
            ;;
        2)  clear
            install_manifest_app standardnotes
            ;;
        3)  clear
            install_manifest_app obsidian
            ;;
        4)  clear
            remove_manifest_app joplin
            ;;
        5)  clear
            remove_manifest_app standardnotes
            ;;
        6)  clear
            remove_manifest_app obsidian
            ;;
        7)  clear
            validate_manifest_apps joplin standardnotes obsidian
            ;;
        8)  clear
            exit
            ;;
		*)  clear
			main
            ;;
        esac
        pkgchk
        print_message DONE "Selection [${choice}] completed."
		wait_for user_anykey
        clear
        main
    done
}

# Main function
function main() {
    about
    display_menu
}

main "${@}"
