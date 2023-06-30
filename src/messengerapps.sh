#!/usr/bin/env bash

SCRIPT_SOURCE="messengerapps.sh"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh")

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
print_message PASS "${SCRIPT_SOURCE} active."
### END OF REQUIRED FUNCTION ###

function install_signal() {
	print_message INFO "Installing Signal..."
	pkgmgr install apt-transport-https
	fetch_signing_key "packages.signal" "https://updates.signal.org/desktop/apt/keys.asc"
	add_apt_source "packages.signal" "signal.list" "https://updates.signal.org/desktop/apt xenial main"
	run_command sudo apt -y update
	pkgmgr install signal-desktop
}

function install_threema() {
	print_message INFO "Installing Threema..."
	from_url="https://releases.threema.ch/web-electron/v1/release/Threema-Latest.deb"
	save_file="/tmp/threema.deb"
	download_file ${save_file} ${from_url}
	pkgmgr install ${save_file}
}

# Display a list of menu items for selection
function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Install Signal"
    echo -e " 2. Install Threema\n"
    echo -e " 3. Remove Signal"
    echo -e " 4. Remove Threema\n"
    echo -e " 5. Exit\n"
    echo -n "    Enter option [1-5]: "

    while :
    do
		read choice </dev/tty
		case ${choice} in
		1)  clear
			pkgmgr remove signal-desktop
			run_command rm -f /etc/apt/sources.list.d/signal.list
            run_command sudo apt -y update
			install_signal
			;;
		2)  clear
			pkgmgr remove threema
			install_threema
			;;
		3)  clear
			pkgmgr remove signal-desktop
			run_command rm -f /etc/apt/sources.list.d/signal.list
			run_command sudo apt -y update
			;;
		4)  clear
			pkgmgr remove threema
			;;
		5)  clear
			exit
			;;
		*)  clear
			main
            ;;
		esac
		echo -e "\nSelection [${choice}] completed."
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
