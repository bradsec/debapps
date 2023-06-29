#!/usr/bin/env bash

SCRIPT_SOURCE="officeapps.sh"
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

function install_onlyoffice() {
	print_message INFO "Installing OnlyOffice..."
    print_message WARN "Downloads for OnlyOffice are over 300MB in size."
    wait_for user_continue
	from_url="https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb"
	save_file="/tmp/onlyoffice.deb"
	download_file ${save_file} ${from_url}
	pkgmgr install ${save_file}
}

function install_libreoffice() {
	print_message INFO "Installing LibreOffice..."
    print_message WARN "Downloads for LibreOffice are approximately 200MB in size."
    wait_for user_continue
	pkgmgr install libreoffice
}

# Display a list of menu items for selection
function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Install OnlyOffice"
    echo -e " 2. Install LibreOffice\n"
    echo -e " 3. Remove OnlyOffice"
    echo -e " 4. Remove LibreOffice\n"
    echo -e " 5. Exit\n"
    echo -n "    Enter option [1-5]: "

    while :
    do
		read choice </dev/tty
		case ${choice} in
		1)  clear
			pkgmgr remove onlyoffice-desktopeditors
			install_onlyoffice
			;;
		2)  clear
			install_libreoffice
			;;
		3)  clear
			pkgmgr remove onlyoffice-desktopeditors
			;;
		4)  clear
			apt-get remove -y libreoffice*
			pkgmgr cleanup
			;;
		5)  clear
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
