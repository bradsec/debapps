#!/usr/bin/env bash

SCRIPT_SOURCE="$(basename -- "$0")"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh")

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
# shellcheck disable=SC2154 # Variables from sourced templates
print_message PASS "${SCRIPT_SOURCE} active."
### END OF REQUIRED FUNCTION ###

function install_burp() {
    burp_product=${1}
	print_message INFO "Installing BurpSuite ${burp_product^}..."
	print_message WARN "Downloads for BurpSuite products are approximately 240MB in size."
    wait_for user_continue
	print_message INFO "Fetching latest release..."
	burp_release="$(curl -Ls -o /dev/null -w '%{url_effective}' https://portswigger.net/burp/releases/community/latest | grep -Po '(?-)\d+' | sed -z 's/\n/./;s/\n/./;s/\n//')"
	from_url="https://portswigger-cdn.net/burp/releases/download?product=${burp_product}&version=${burp_release}&type=Linux"
	save_file="/tmp/burp${burp_product}.sh"
	download_file "${save_file}" "${from_url}"
	run_command chmod +x "${save_file}"
	run_command "${save_file}"
}

function remove_burp() {
    burp_product=${1}
	print_message INFO "Removing BurpSuite ${burp_product^}..."
	user_prompt=$(message USER "Set BurpSuite install location or enter to use default [/opt/BurpSuite${burp_product^}]: ")
	read -r -p "${user_prompt}" app_path </dev/tty
	app_path=${app_path:-/opt/BurpSuite${burp_product^}}
	print_message INFO "Running uninstall in ${app_path}..."
	run_command "${app_path}/uninstall"
}

# Display a list of menu items for selection
function display_menu() {
    echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Install BurpSuite Community"
    echo -e " 2. Install BurpSuite Professional\n"
    echo -e " 3. Remove BurpSuite Community"
    echo -e " 4. Remove BurpSuite Professional\n"
    echo -e " 5. Exit\n"
    echo -n "    Enter option [1-5]: "

    while :
    do
        read -r choice </dev/tty
        case ${choice} in
        1)  clear
            install_burp community
            ;;
        2)  clear
            install_burp pro
            ;;
        3)  clear
            remove_burp community
            ;;
        4)  clear
            remove_burp pro
            ;;
        5)  clear
            exit
            ;;
        *)  clear
            main
            ;;
        esac
        pkgchk
        print_message DONE "\nSelection [${choice}] completed."
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