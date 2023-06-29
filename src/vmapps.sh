#!/usr/bin/env bash

SCRIPT_SOURCE="vmapps.sh"
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

# Initial setup prerequisites
function initial_setup() {
    print_message INFO "Running initial setup and checking for required packages..."
    run_command sudo apt -y update
    pkgmgr install wget curl gcc build-essential linux-headers-$(uname -r)
}

# Function to get latest modules release download link
function get_vmware_mod_link() {
    get_html=$(curl -s https://github.com/mkubecek/vmware-host-modules/tags)
    grep -m1 -o '/mkubecek/vmware-host-modules/archive/refs/tags/*[a-z]\+[^>"]*.tar.gz' <<<${get_html}
}

# Install function
function vmware_install() {
    local app="${1}"
    print_message WARN "Downloads for VMWare products are over 500MB in size."
    wait_for user_continue
    print_message INFO "Installing VMWare ${app}..."
    dload_url="https://www.vmware.com/go/get${app}-linux"
    print_message INFO "Fetching latest version of VMWare ${app}..."
    vmware_filepath="/tmp/vmware_${app}.bundle"
    if ! [[ -f "{vmware_filepath}" ]]; then
        download_file ${vmware_filepath} ${dload_url}
    fi
    print_message INFO "Running VMWare installer ${vmware_filepath}..."
    run_command chmod a+x ${vmware_filepath}
    run_command_verbose ${vmware_filepath}
    # print_message INFO "Download and install latest vmware-host-modules..."
    # dload_url="https://github.com/$(get_vmware_mod_link)"
    # save_file="/tmp/vmwarehostmods.tar.gz"
    # download_file ${save_file} ${dload_url}
    # run_command cd /tmp
    # run_command tar -xvf ${save_file}
    # extract_dir=$(ls | grep -m1 vmware-host-modules)
    # run_command cd ${extract_dir}
    # run_command tar -cf vmmon.tar vmmon-only
    # run_command tar -cf vmnet.tar vmnet-only
    # run_command cp -v vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/
    # print_message INFO "Installing required VMWare modules..."
    # run_command vmware-modconfig --console --install-all
    print_message DONE "Installation of VMWare ${app} completed."
}

# Uninstall function
function vmware_uninstall() {
    local app="${1}"
    print_message INFO "Uninstalling VMWare ${app}..."
    if ! [[ -x "$(command -v vmware-installer -u vmware-${app})" ]]; then
        print_message INFO "VMWare ${app} not installed"
    else
        vmware-installer -u vmware-${app} || true
    fi
}

function vbox_install() {
    print_message INFO "Installing VirtualBox..."
    fetch_signing_key "oracle-virtual-box-archive" "https://www.virtualbox.org/download/oracle_vbox_2016.asc"
    code_name="$(get_os codename)"
    # As at 14 May 2022 no release for Ubuntu jammy
    # As of 24 June 2023 no release for Debian 12 Bookworm
    if [[ ${code_name} == "jammy" ]]; then
        code_name="focal"
    elif [[ ${code_name} == "bookworm" ]]; then
        code_name="bullseye"   
    fi
	add_apt_source "oracle-virtual-box-archive" "virtual-box.list" "https://download.virtualbox.org/virtualbox/debian ${code_name} contrib"
    run_command sudo apt -y update
    vbox_pkg=$(apt-cache search virtualbox | grep Oracle | sed 's/\s.*$//' | tail -1)
    pkgmgr size ${vbox_pkg}
    print_message WARN "Downloads for VirtualBox are approximately 80MB in size... "
    wait_for user_continue
    pkgmgr install ${vbox_pkg}
    print_message DONE "Installation of VirtualBox completed."
}

function vbox_uninstall() {
    vbox_pkg=
    if [[ $(dpkg --get-selections | grep virtualbox) ]] &>/dev/null; then
       vbox_pkg=$(dpkg --get-selections | grep virtualbox | sed 's/\s.*$//')
       pkgmgr remove ${vbox_pkg}
       run_command rm -f /etc/apt/sources.list.d/virtual-box*
    else
        print_message INFO "No VirtualBox package found."
    fi
    run_command sudo apt -y update
    pkgmgr cleanup
}

function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Install VMWare Workstation"
    echo -e " 2. Install VMWare Player"
    echo -e " 3. Install Oracle Virtual Box\n"
    echo -e " 4. Uninstall VMWare Workstation"
    echo -e " 5. Uninstall VMWare Player"
    echo -e " 6. Uninstall Oracle Virtual Box\n"
    echo -e " 7. Exit\n"
    echo -n "    Enter option [1-7]: "

    while :
    do
        read choice </dev/tty
        case $choice in
        1)  clear
            initial_setup
            vmware_install workstation
            ;;
        2)  clear
            initial_setup
            vmware_install player
            ;;
        3)  clear
            initial_setup
            vbox_install
            ;;
        4)  clear
            vmware_uninstall workstation
            ;;
        5)  clear
            vmware_uninstall player
            ;;
        6)  clear
            vbox_uninstall
            ;;
        7)  clear
            exit
            ;;
		*)  clear
			display_menu
            ;;        
        esac
        print_message DONE "Selection [${choice}] completed."
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
