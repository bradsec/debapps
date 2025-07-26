#!/usr/bin/env bash

SCRIPT_SOURCE="$(basename -- "$0")"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh")

# Imports bash script functions from a local template or the github hosted template file.
import_templates() {
  local templates_remote="https://raw.githubusercontent.com/bradsec/debapps/main/src/templates/"
  # Set templates_local to relative path to clone repo.
  local templates_local="${SCRIPT_DIR}/src/templates/"
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

script_fetch() {
  local script_name="$1"
  local script_local="${SCRIPT_DIR}/src/${script_name}"
  
  # Validate script name to prevent path injection
  if [[ ! "$script_name" =~ ^[a-zA-Z0-9_-]+\.sh$ ]]; then
    print_message FAIL "Invalid script name: ${script_name}"
    return 1
  fi
  
  if [[ -f "${script_local}" ]]; then
    print_message INFO "Using local script: ${script_local}"
    bash "${script_local}"
  else
    print_message FAIL "Local script not found: ${script_local}"
    print_message WARN "Remote script execution has been disabled for security reasons."
    print_message INFO "Please clone the repository to use all features:"
    print_message INFO "git clone https://github.com/bradsec/debapps.git"
    return 1
  fi
}

### END OF REQUIRED FUNCTION ###

# Display a list of menu items for selection
function display_menu() {
    echo
    echo -e " ========================"                         
    echo -e "  Application Categories "
    echo -e " ========================\n"
    echo -e "  1. Password Manager apps"
    echo -e "  2. Note apps"
    echo -e "  3. Messenger apps"
    echo -e "  4. Office apps"
    echo -e "  5. Collaboration apps"
    echo -e "  6. Web Browsers and Web API Tools"
    echo -e "  7. Code Editor apps"
    echo -e "  8. Burp Suite apps\n"
    echo -e "  9. Exit\n"
    echo -n "     Enter option [1-10]: "

    while :
    do
        read -r choice </dev/tty
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
            print_message INFO "Fetching Burp application options..."
	            script_fetch burpapps.sh
            ;;
        9)  clear
            exit
            ;;
        *)  clear
            main
            ;;
        esac
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
