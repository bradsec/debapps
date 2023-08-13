#!/usr/bin/env bash

SCRIPT_SOURCE="unifiapps.sh"
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

function install_app() {
    print_message INFOFULL "Installing Unifi Controller..."
    print_message WARN "IMPORTANT: Backup/export any existing Unifi controller configurations before running."
    print_message WARN "Download for Unifi Controller is approximately 170MB."
    wait_for user_continue
    print_message INFO "Removing any old versions and possible conflicting packages..."
    # Remove any existing unifi installation
    remove_app
    # Unifi controller depends on older packages including mongodb <= 3.6
    print_message INFO "Adding required repo keys and sources..."
    fetch_keyserver_signing_key "debian-stretch-repo" "keyserver.ubuntu.com" "04EE7237B7D453EC"
    add_apt_source "debian-stretch-repo" "debian-stretch.list" "http://archive.debian.org/debian stretch main contrib non-free"
    fetch_keyserver_signing_key "unifi-repo" "keyserver.ubuntu.com" "06E85760C0A52C50"
    add_apt_source "unifi-repo" "100-ubnt-unifi.list" "https://www.ui.com/downloads/unifi/debian stable ubiquiti" "armhf"
    run_command sudo apt -y update
    # Install required packages
    print_message INFO "Running check for required packages..."
    pkgmgr install curl ca-certificates apt-transport-https openjdk-11-jre-headless haveged jsvc
    run_command apt-mark hold openjdk*
    # Install unifi verbose to show working
    print_message INFO "Running unifi installation with verbose output..."
    apt-get -y install unifi
    print_message INFO "Reboot required to ensure unifi starts correctly."
    local hostip=$(hostname -I | awk '{print $1}')
    print_message INFO "After reboot access Unifi in browser at https://${hostip}:8443"
    wait_for user_continue
    run_command /usr/sbin/shutdown -r now
    }


function remove_app() {
    print_message INFOFULL "Removing Unifi Controller..."
    systemctl stop unifi >/dev/null 2>&1 || true
    systemctl stop mongodb >/dev/null 2>&1 || true
    run_command apt-mark unhold openjdk*
    pkgmgr remove unifi mongodb-org* mongodb* openjdk-11-jre-headless haveged jsvc
    run_command rm -f /etc/apt/sources.list.d/100-ubnt-unifi.list
    run_command rm -f /etc/apt/sources.list.d/debian-stretch.list
    run_command rm -rf /usr/lib/unifi /var/lib/unifi
    run_command rm -f /etc/systemd/system/unifi.service
    run_command rm -rf /var/log/mongodb /var/lib/mongodb
    pkgmgr cleanup
    run_command sudo apt -y update
    pkgmgr fix
}


function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Setup Unifi Controller"
    echo -e " 2. Remove Unifi Controller\n"
    echo -e " 3. Exit\n"
    echo -n "    Enter option [1-3]: "

    while :
    do
        read choice </dev/tty
        case $choice in
        1)  clear
            install_app
            ;;
        2)  clear
            remove_app
            ;;
        3)  clear
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
