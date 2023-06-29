#!/usr/bin/env bash

SCRIPT_SOURCE="codeeditapps.sh"
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

get_date_time
get_os summary
print_message INFO "Script name: ${SCRIPT_SOURCE}"
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
	from_url="https://github.com$(curl -s https://github.com/VSCodium/vscodium/releases \
	| awk -F"[><]" '{for(i=1;i<=NF;i++){if($i ~ /a href=.*\//){print "<" $i ">"}}}' \
	| grep $(dpkg --print-architecture) -A 0 | awk 'NR==1' | sed -r 's/.*href="([^"]+).*/\1/g')"
	save_file="/tmp/codium.deb"
	download_file ${save_file} ${from_url}
	pkgmgr install ${save_file}
}

function install_vscode() {
	print_message INFO "Installing Microsoft Visual Studio Code..."
	pkgmgr install curl wget gpg software-properties-common apt-transport-https
	fetch_signing_key "packages.microsoft" "https://packages.microsoft.com/keys/microsoft.asc"
	add_apt_source "packages.microsoft" "vscode.list" "https://packages.microsoft.com/repos/code stable main"
	run_command sudo apt -y update
	pkgmgr install code
}

# Display a list of menu items for selection
function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Install Sublime-Text 4"
    echo -e " 2. Install VS Codium"
    echo -e " 3. Install VS Code\n"
    echo -e " 4. Remove Sublime-Text"
    echo -e " 5. Remove VS Codium"
    echo -e " 6. Remove VS Code\n"
    echo -e " 7. Exit\n"
    echo -n "    Enter option [1-7]: "

    while :
    do
		read choice </dev/tty
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
			pkgmgr remove sublime-text
			run_command rm -f /etc/apt/sources.list.d/sublimetext.list
			run_command sudo apt -y update
			;;
		5)  clear
			pkgmgr remove codium
			;;
		6)  clear
			pkgmgr remove code
			run_command rm -f /etc/apt/sources.list.d/vscode.list
			run_command sudo apt -y update
			;;
		7)  clear
			exit
			;;
		*)  clear
			display_menu
            ;;
		esac
		echo -e "\nSelection [${choice}] completed."
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
