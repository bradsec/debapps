#!/usr/bin/env bash

SCRIPT_SOURCE="goapps.sh"
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

function install_golang() {
    print_message INFO "Installing Go Programming Language..."
    run_command rm -rf /usr/local/go
    from_url="https://go.dev$(curl -s https://go.dev/dl/ | \
        grep linux | grep $(dpkg --print-architecture) -A 0 | sed -r 's/.*href="([^"]+).*/\1/g' | awk 'NR==1')"
    save_file="/tmp/golang.tar.gz"
    download_file ${save_file} ${from_url}
    run_command tar -C /usr/local -xzf ${save_file}
    echo "export PATH=/usr/local/go/bin:${PATH}" > /etc/profile.d/go.sh
    chmod +x /etc/profile.d/go.sh
    source /etc/profile.d/go.sh
    go_version="$(go version)"
    print_message DONE "${go_version} installed."
}


# Display a list of menu items for selection
function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Install Go (Golang) Programming Language\n"
    echo -e " 2. Remove Go\n"
    echo -e " 3. Exit\n"
    echo -n "    Enter option [1-3]: "

    while :
    do
		read choice </dev/tty
		case ${choice} in
		1)  clear
			install_golang
			;;
		2)  clear
			run_command rm -rf /usr/local/go
			run_command rm /etc/profile.d/go.sh
			;;
		3)  clear
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
