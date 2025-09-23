#!/usr/bin/env bash

SCRIPT_SOURCE="$(basename -- "$0")"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh" "appimage.tmpl.sh")

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
        tmp_template_file="$(mktemp)"
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
# shellcheck disable=SC2154 # Variables from sourced templates
print_message PASS "${SCRIPT_SOURCE} active."
### END OF REQUIRED FUNCTION ###

function install_opt_app() {
    local app="${1}"
    print_message INFOFULL "This script will install ${app} using the latest AppImage."
	print_message WARN "Any existing ${app} settings or configuration may be lost."
	wait_for user_continue
	# Update packages and install required packages
	print_message INFO "Checking for required packages..."
	run_command sudo apt -y update
	pkgmgr install "curl" "wget"
    # If available or required (Ubuntu) install
    pkgmgr install libfuse2
	pkgmgr remove "${app}"
    if [[ "${app}" == "joplin" ]]; then
	local latest_release
	latest_release="$(curl -s "https://github.com/laurent22/joplin/releases" | grep -o '<a[^>]*href="/laurent22/joplin/releases/tag/v[^"]*"' | head -n 1 | awk -F '"' '{print $2}')"
	local version_number
	version_number="$(echo "${latest_release}" | sed -E 's/.*v([0-9.]+)$/\1/' | tr -d '[:space:]')"
	local from_url="https://github.com/laurent22/joplin/releases/download/v${version_number}/Joplin-${version_number}.AppImage"
    elif [[ "${app}" == "standardnotes" ]]; then
	local latest_release
	latest_release="$(curl -s "https://github.com/standardnotes/app/releases" | grep -o '<a[^>]*href="/standardnotes/app/releases/tag/%40standardnotes%2Fdesktop[^"]*"' | head -n 1 | awk -F '"' '{print $2}')"
	local version_number
	version_number="$(echo "${latest_release}" | sed -E 's/.*%40([0-9.]+)$/\1/' | tr -d '[:space:]')"
	local from_url="https://github.com/standardnotes/app/releases/download/%40standardnotes%2Fdesktop%40${version_number}/standard-notes-${version_number}-linux-x86_64.AppImage"
    elif [[ "${app}" == "obsidian" ]]; then
	local latest_release
	latest_release="$(curl -s "https://github.com/obsidianmd/obsidian-releases/releases" | grep -o '<a[^>]*href="/obsidianmd/obsidian-releases/releases/tag/v[^"]*"' | head -n 1 | awk -F '"' '{print $2}')"
	local version_number
	version_number="$(echo "${latest_release}" | sed -E 's/.*v([0-9.]+)$/\1/' | tr -d '[:space:]')"
	local from_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${version_number}/Obsidian-${version_number}.AppImage"
    fi

    if [[ -d "/opt/${app}" ]]; then
        print_message WARN "A directory for /opt/${app} already exists. Any existing files may be overwritten."
	    wait_for user_continue
    else
        run_command mkdir -p "/opt/${app}"
    fi
    
    local appimage_save_file="/opt/${app}/${app}.AppImage"
    # shellcheck disable=SC2154 # version_number defined in conditional blocks above
    print_message INFO "Found ${app} version: ${version_number}"
    download_file "${appimage_save_file}" "${from_url}"
    setup_app_image "${appimage_save_file}"
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
    echo -e " 1. Install Joplin"
    echo -e " 2. Install Standard Notes"
    echo -e " 3. Install Obsidian\n"
    echo -e " 4. Remove Joplin"
    echo -e " 5. Remove Standard Notes"
    echo -e " 6. Remove Obsidian\n"
    echo -e " 7. Exit\n"
    echo -n "    Enter option [1-7]: "

    while :
    do
        read -r choice </dev/tty
        case "$choice" in
        1)  clear
            install_opt_app joplin
            ;;
        2)  clear
            install_opt_app standardnotes
            ;;
        3)  clear
            install_opt_app obsidian
            ;;
        4)  clear
            remove_opt_app joplin
            ;;
        5)  clear
            remove_opt_app standardnotes
            ;;
        6)  clear
            remove_opt_app obsidian
            ;;
        7)  clear
            exit
            ;;
		*)  clear
			print_message WARN "Invalid option. Please select 1-7."
			continue
            ;;
        esac
        pkgchk
        print_message DONE "Selection [${choice}] completed."
		wait_for user_anykey
        clear
        return
    done
}

# Main function
function main() {
    about
    display_menu
}

main "${@}"
