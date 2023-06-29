#!/usr/bin/env bash

SCRIPT_SOURCE="passwordapps.sh"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh" "appimage.tmpl.sh")

# Imports bash script functions from a local template or the github hosted template file.
import_templates() {
  local templates_remote="https://raw.githubusercontent.com/bradsec/debapps/main/src/templates/"
  # Set templates_local to relative path to clone repo. Different from debapps.sh
  local templates_local="${SCRIPT_DIR}/templates/"
  for tmpl in ${TEMPLATES_REQUIRED[@]}; do
    if [[ -f "${templates_local}${tmpl}" ]]; then
      source "${templates_local}${tmpl}" || echo -e "An error occurred in template import."
    else
      local remote_template="${templates_remote}${tmpl}"
      if wget -q --spider "${remote_template}"; then
        # Download the remote template to a temporary file
        local tmp_template_file=$(mktemp)
        wget -qO "${tmp_template_file}" "${remote_template}"
        
        # Source the temporary file and then remove it
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

get_date_time
get_os summary
print_message INFO "Script name: ${SCRIPT_SOURCE}"
### END OF REQUIRED FUNCTION ###

function install_opt_app() {
    local app="${1}"
    print_message INFOFULL "This script will install ${app} using the latest AppImage."
	print_message WARN "Any existing ${app} settings or configuration may be lost."
	wait_for user_continue
	# Update packages and install required packages
	print_message INFO "Checking for required packages..."
	run_command sudo apt -y update
	pkgmgr install curl wget
    # If available or required (Ubuntu) install
    pkgmgr install libfuse2
	pkgmgr remove ${app}
    if [[ "${app}" == "bitwarden" ]]; then
        local latest_release=$(curl -s "https://github.com/bitwarden/clients/releases/" | grep -o '<a[^>]*href="/bitwarden/clients/releases/tag/desktop-v[^"]*"' | head -n 1 | awk -F '"' '{print $2}')
        local version_number=$(echo "${latest_release}" | sed -E 's/.*desktop-v([0-9.]+)$/\1/' | tr -d '[:space:]')
        local from_url="https://github.com/bitwarden/clients/releases/download/desktop-v${version_number}/Bitwarden-${version_number}-x86_64.AppImage"
    elif [[ "${app}" == "keepassxc" ]]; then
        local latest_release=$(curl -s "https://github.com/keepassxreboot/keepassxc/releases" | grep -o '<a[^>]*href="/keepassxreboot/keepassxc/releases/tag/[^"]*"' | head -n 1 | awk -F '"' '{print $2}')
        local version_number=$(echo "${latest_release}" | sed -E 's/.*\/tag\/([0-9.]+)$/\1/' | tr -d '[:space:]')
        local from_url="https://github.com/keepassxreboot/keepassxc/releases/download/${version_number}/KeePassXC-${version_number}-x86_64.AppImage"
    fi

    if [[ -d "/opt/${app}" ]]; then
        print_message WARN "A directory for /opt/${app} already exists. Any existing files may be overwritten."
	    wait_for user_continue
    else
        run_command mkdir -p "/opt/${app}"
    fi

    local appimage_save_file="/opt/${app}/${app}.AppImage"
    print_message INFO "Found ${app} version: ${version_number}"
    download_file ${appimage_save_file} ${from_url}
    setup_app_image ${appimage_save_file}
}

function remove_opt_app() {
    local app="${1}"
	print_message WARN "This will delete and remove all files, settings and configuration for ${app}."
	wait_for user_continue
    remove_app_image "/opt/${app}"
}


function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Install Bitwarden (Uses an online vault)"
    echo -e " 2. Install KeePassXC (Uses an offline vault)\n"
    echo -e " 3. Remove Bitwarden"
    echo -e " 4. Remove KeePassXC\n"
    echo -e " 5. Exit\n"
    echo -n "    Enter option [1-5]: "

    while :
    do
        read choice </dev/tty
        case $choice in
        1)  clear
            install_opt_app bitwarden
            ;;
        2)  clear
            install_opt_app keepassxc
            ;;
        3)  clear
            remove_opt_app bitwarden
            ;;
        4)  clear
            remove_opt_app keepassxc
            ;;
        5)  clear
            exit
            ;;
		*)  clear
			display_menu
            ;;
        esac
        echo
        print_message DONE "Selection [${choice}] completed."
		wait_for user_anykey
        clear
        display_menu
    done
}

# Main function
function main() {
	check_superuser
    display_menu
}

main "${@}"
