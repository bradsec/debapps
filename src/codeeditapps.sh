#!/usr/bin/env bash

SCRIPT_SOURCE="codeeditapps.sh"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#### START OF REQUIRED INFORMATION FOR IMPORTING BASH TEMPLATES ###
TEMPLATES_REQUIRED=("generic.tmpl.sh" "debian.tmpl.sh" "appimage.tmpl.sh")

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

function get_arch_for_cursor() {
    local arch=$(uname -m)
    if [ "$arch" == "x86_64" ]; then
        echo "x64"
    elif [ "$arch" == "aarch64" ]; then
        echo "arm64"
    else
        echo "Unsupported architecture: $arch" >&2
        exit 1
    fi
}

function install_opt_app() {
    local app="${1}"
    print_message INFOFULL "This script will install ${app} using the latest AppImage."
	print_message WARN "Any existing ${app} settings or configuration may be lost."
	wait_for user_continue
	# Update packages and install required packages
	print_message INFO "Checking for required packages..."
	run_command sudo apt -y update
	pkgmgr install curl wget
    # If available or required (Ubuntu) install
    pkgmgr install libfuse2
	pkgmgr remove ${app}
    if [[ "${app}" == "cursor" ]]; then
		local cursor_arch=$(get_arch_for_cursor)
        local from_url="https://downloader.cursor.sh/linux/appImage/${cursor_arch}"
    fi

    if [[ -d "/opt/${app}" ]]; then
        print_message WARN "A directory for /opt/${app} already exists. Any existing files may be overwritten."
	    wait_for user_continue
    else
        run_command mkdir -p "/opt/${app}"
    fi

    local appimage_save_file="/opt/${app}/${app}.AppImage"
    print_message INFO "Found ${app} version: ${version_number}"
    download_file ${appimage_save_file} ${from_url}
    setup_app_image ${appimage_save_file}
}

function remove_opt_app() {
    local app="${1}"
	print_message WARN "This will delete and remove all files, settings and configuration for ${app}."
	wait_for user_continue
    remove_app_image "/opt/${app}"
}

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
    echo -e " 3. Install VS Code"
	echo -e " 4. Install Cursor AI\n"
    echo -e " 5. Remove Sublime-Text"
    echo -e " 6. Remove VS Codium"
	echo -e " 7. Remove VS Code"
    echo -e " 8. Remove Cursor\n"
    echo -e " 9. Exit\n"
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
			install_opt_app cursor
			;;
		5)  clear
			pkgmgr remove sublime-text
			run_command rm -f /etc/apt/sources.list.d/sublimetext.list
			run_command sudo apt -y update
			;;
		6)  clear
			pkgmgr remove codium
			;;
		7)  clear
			pkgmgr remove code
			run_command rm -f /etc/apt/sources.list.d/vscode.list
			run_command sudo apt -y update
			;;
        8)  clear
            remove_opt_app cursor
            ;;
		9)  clear
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