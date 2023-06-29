#!/usr/bin/env bash

SCRIPT_SOURCE="debapps.sh"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh")

# Imports bash script functions from a local template or the github hosted template file.
import_templates() {
  local templates_remote="https://raw.githubusercontent.com/bradsec/debapps/main/src/templates/"
  # Set templates_local to relative path to clone repo.
  local templates_local="${SCRIPT_DIR}/src/templates/"
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

script_fetch() {
  local script_local="${SCRIPT_DIR}/src/${1}"
  local script_remote="https://raw.githubusercontent.com/bradsec/debapps/main/src/${1}"
  if [[ -f "${script_local}" ]]; then
    print_message INFO "Using local script: ${script_local}"
    bash "${script_local}"
  else
    print_message INFO "Fetching remote script: ${script_remote}"
    bash -c "$(wget -qO- ${script_remote})"
  fi
}

get_date_time
get_os summary
print_message INFO "Script name: ${SCRIPT_SOURCE}"
### END OF REQUIRED FUNCTION ###

about() {
echo ${CYAN}
cat << "EOF"
██████╗ ███████╗██████╗  █████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ██║█████╗  ██████╔╝███████║██████╔╝██████╔╝███████╗
██║  ██║██╔══╝  ██╔══██╗██╔══██║██╔═══╝ ██╔═══╝ ╚════██║
██████╔╝███████╗██████╔╝██║  ██║██║     ██║     ███████║
╚═════╝ ╚══════╝╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝
 
 These scripts will work with most [x64] Debian based Linux distros.
 More info at: https://github.com/bradsec/debapps
EOF
echo ${RESET}
}


# Display a list of menu items for selection
function display_menu () {
	echo
    echo -e " ========================"                         
    echo -e "  Application Categories "
    echo -e " ========================\n"
    echo -e "  1. Password manager apps"
    echo -e "  2. Note apps"
    echo -e "  3. Messenger apps"
    echo -e "  4. Office apps"
    echo -e "  5. Collaboration apps"
    echo -e "  6. Web browsers and other web apps"
    echo -e "  7. Code editor apps"
    echo -e "  8. Virtual machine apps"
    echo -e "  9. Burp Suite apps\n"
    echo -e " 10. Go (golang) installer"
    echo -e " 11. Unifi Network Application (controller) for Raspberry Pi\n"
    echo -e " 12. Exit\n"
    echo -n "     Enter option [1-12]: "

    while :
    do
		read choice </dev/tty
		case ${choice} in
		1)  clear
            print_message INFO "Fetching Password manager application options menu..."
            script_fetch passwordapps.sh
			;;
		2)  clear
            print_message INFO "Fetching Note application options..."
            script_fetch noteapps.sh
			;;
		3)  clear
            print_message INFO "Fetching Messenger application options..."
			      script_fetch messengerapps.sh
			;;
		4)  clear
            print_message INFO "Fetching Office application options..."
            script_fetch officeapps.sh
			;;
		5)  clear
            print_message INFO "Fetching Collaboration application options..."
			      script_fetch collabapps.sh
			;;
		6)  clear
            print_message INFO "Fetching Web browser application options..."
            script_fetch webapps.sh
			;;
		7)  clear
            print_message INFO "Fetching Code editor options..."
			      script_fetch codeeditapps.sh
			;;
		8)  clear
            print_message INFO "Fetching Virtual machine application options..."
            script_fetch vmapps.sh
			;;
		9)  clear
            print_message INFO "Fetching Burp application options..."
			      script_fetch burpapps.sh
			;;
		10)  clear
            print_message INFO "Fetching Go application options..."
            script_fetch goapps.sh
			;;
		11)  clear
            print_message INFO "Fetching Raspberry Pi Unifi controller options..."
			      script_fetch unifiapps.sh
			;;
		12) clear
			exit
			;;
		*)  clear
			display_menu
            ;;
		esac
		clear
		display_menu
    done
}

# Main function
function main() {
    check_superuser
    about
    display_menu
}

main "${@}"
