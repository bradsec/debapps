#!/usr/bin/env bash

SCRIPT_SOURCE="$(basename -- "$0")"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh" "apps.tmpl.sh")

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

function install_libreoffice() {
	print_message INFO "Installing LibreOffice..."
    print_message WARN "Downloads for LibreOffice are approximately 200MB in size."
    wait_for user_continue
	pkgmgr install libreoffice
}

# Display a list of menu items for selection
function display_menu () {
    local menu_options=(
        "Install OnlyOffice"
        "Install LibreOffice"
        "Remove OnlyOffice"
        "Remove LibreOffice"
        "Check download links"
        "Exit"
    )

    while :
    do
		choice=$(menu_select "Office Apps" "${menu_options[@]}")
		case ${choice} in
		1)  clear
			print_message WARN "Downloads for OnlyOffice are over 300MB in size."
			wait_for user_continue
			remove_manifest_app onlyoffice
			install_manifest_app onlyoffice
			;;
		2)  clear
			install_libreoffice
			;;
		3)  clear
			remove_manifest_app onlyoffice
			;;
		4)  clear
			run_command sudo apt-get remove -y 'libreoffice*'
			run_command sudo apt -y autoclean
			run_command sudo apt -y autoremove
			;;
		5)  clear
			validate_manifest_app onlyoffice
			;;
		6)  clear
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
