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

function install_sublimetext4() {
    print_message INFO "Installing Sublime-Text 4..."
    pkgmgr install apt-transport-https
    fetch_signing_key "packages.sublimehq" "https://download.sublimetext.com/sublimehq-pub.gpg"
    add_apt_source "packages.sublimehq" "sublimetext.list" "https://download.sublimetext.com/ apt/stable/"
    run_command sudo apt -y update
    pkgmgr install sublime-text
}

function install_vscodium() {
    print_message INFO "Installing VSCodium..."
	install_manifest_app vscodium
}

function install_vscode() {
	print_message INFO "Installing Microsoft Visual Studio Code..."
	install_manifest_app vscode
}

# Display a list of menu items for selection
function display_menu() {
    local menu_options=(
        "Install Sublime-Text 4"
        "Install VS Codium"
        "Install VS Code"
        "Install Cursor AI"
        "Remove Sublime-Text"
        "Remove VS Codium"
        "Remove VS Code"
        "Remove Cursor"
        "Check download links"
        "Exit"
    )

    while :
    do
        choice=$(menu_select "Code Editor Apps" "${menu_options[@]}")
        case ${choice} in
        1)  clear
            pkgmgr remove sublime-text
            install_sublimetext4
            ;;
        2)  clear
            install_vscodium
            ;;
        3)  clear
            install_vscode
            ;;
        4)  clear
            install_manifest_app cursor
            ;;
        5)  clear
            pkgmgr remove sublime-text
            run_command rm -f /etc/apt/sources.list.d/sublimetext.list
            run_command sudo apt -y update
            ;;
        6)  clear
            remove_manifest_app vscodium
            ;;
        7)  clear
            remove_manifest_app vscode
            ;;
        8)  clear
            remove_manifest_app cursor
            ;;
        9)  clear
            validate_manifest_apps cursor vscodium vscode
            ;;
        10)  clear
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
