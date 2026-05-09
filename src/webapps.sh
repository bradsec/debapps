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

function install_firefox() {
	print_message INFOFULL "This will install the latest Firefox browser version."
	print_message WARN "This script will attempt to remove any existing installations of Firefox including Firefox ESR."
	print_message WARN "Existing Firefox settings and preferences will be lost."
	wait_for user_continue
    pkgmgr remove firefox-esr
    remove_manifest_app firefox
	install_manifest_app firefox
	print_message DONE "Firefox installed."
}

function install_brave() {
	print_message INFOFULL "This will install the latest Brave browser version."
	print_message WARN "This script will attempt to remove any existing installations of Brave."
	print_message WARN "Existing Brave settings and preferences will be lost."
	wait_for user_continue
	remove_manifest_app brave
	install_manifest_app brave
	print_message DONE "Brave installed."
}

function install_tor_browser(){
	print_message INFOFULL "This will install the latest Tor-Browser version."
	if sudo apt-cache show torbrowser-launcher >/dev/null 2>&1; then
		pkgmgr install torbrowser-launcher
		print_message DONE "Tor-Browser launcher installed."
		return 0
	fi

	print_message WARN "torbrowser-launcher is not available from configured apt repositories. Falling back to the official tarball."
	pkgmgr install curl
	local tor_link
	tor_link="https://www.torproject.org$(curl -s https://www.torproject.org/download/ | \
	grep linux | sed -r 's/.*href="([^"]+).*/\1/g' | awk 'NR==1')"
	local from_url="${tor_link}"
	local save_file="/tmp/torbrowser.tar.xz"
	download_file "${save_file}" "${from_url}"
	run_command tar -xvJf "${save_file}" --directory /opt/
	local pkg_path
	# shellcheck disable=SC2010 # Using ls|grep for directory matching
	pkg_path="/opt/$(ls /opt/ | grep tor-browser)"
	run_command chown -R "$(get_user):$(get_user)" "${pkg_path}"
	run_command chmod 755 "${pkg_path}/start-tor-browser.desktop"
	run_command mkdir -p /usr/local/bin
	run_command ln -sf "${pkg_path}/start-tor-browser.desktop" /usr/local/bin/tor-browser
	run_command cd "${pkg_path}"
	su -c './start-tor-browser.desktop --register-app' "$(logname)" >/dev/null 2>&1
	print_message DONE "Tor-Browser installed."
}

function install_chrome() {
	print_message INFO "Installing Google Chrome..."
	remove_manifest_app chrome
	install_manifest_app chrome
	print_message DONE "Chrome installed."
}

function install_postman() {
	print_message INFO "Installing Postman..."
	# Download latest linux 64 version
	local from_url="https://dl.pstmn.io/download/latest/linux64"
	local save_file="/tmp/postman.tar.gz"
	download_file "${save_file}" "${from_url}"
    # Extract files to /opt/
    run_command tar -xvf "${save_file}" --directory /opt/
    run_command mkdir -p /usr/local/bin
    run_command ln -sf /opt/Postman/Postman /usr/local/bin/postman
    if [[ -f /opt/Postman/app/resources/app/assets/icon.png ]]; then
        run_command mkdir -p /usr/share/icons/hicolor/256x256/apps
        run_command cp /opt/Postman/app/resources/app/assets/icon.png /usr/share/icons/hicolor/256x256/apps/postman.png
    fi
    # Write desktop icon configuration file
	local postman_config="[Desktop Entry]
Name=Postman
Comment=Postman is an API platform for building and using APIs
GenericName=Postman
X-GNOME-FullName=Postman
Exec=/opt/Postman/Postman %U
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=postman
Categories=Network;WebBrowser;
StartupWMClass=Postman
StartupNotify=true"
    write_config_file "${postman_config}" "/usr/share/applications/postman.desktop"
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        run_command gtk-update-icon-cache -f /usr/share/icons/hicolor
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        run_command update-desktop-database /usr/share/applications
    fi
    run_command rm "${save_file}"
	print_message DONE "Postman installed."
}

function remove_postman() {
    run_command rm -rf /opt/Postman
    run_command rm -f /usr/local/bin/postman /usr/sbin/postman
    run_command rm -f /usr/share/applications/postman.desktop
    run_command rm -f /usr/share/icons/hicolor/256x256/apps/postman.png
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        run_command gtk-update-icon-cache -f /usr/share/icons/hicolor
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        run_command update-desktop-database /usr/share/applications
    fi
}


function display_menu() {
    local menu_options=(
        "Install Firefox"
        "Install Google Chrome"
        "Install Brave"
        "Install TOR Browser"
        "Install Postman API Tool"
        "Remove Firefox"
        "Remove Google Chrome"
        "Remove Brave"
        "Remove TOR Browser"
        "Remove Postman API Tool"
        "Check download links"
        "Exit"
    )

    while :
    do
        choice=$(menu_select "Web Browsers and Web API Tools" "${menu_options[@]}")
        case $choice in
        1)  clear
            install_firefox
            ;;
        2)  clear
            install_chrome
            ;;
        3)  clear
            install_brave
            ;;
        4)  clear
            install_tor_browser
            ;;
        5)  clear
            install_postman
            ;;
        6)  clear
            remove_manifest_app firefox
            ;;
        7)  clear
            remove_manifest_app chrome
            run_command sudo apt -y update
            run_command sudo apt -y autoclean
            run_command sudo apt -y autoremove
            ;;
        8)  clear
            remove_manifest_app brave
            ;;
        9)  clear
            pkgmgr remove torbrowser-launcher
            remove_opt_app tor-browser
            ;;
        10) clear
            remove_postman
            local user_name
            user_name=$(get_user)
            # Validate user name to prevent path injection
            if [[ -n "$user_name" && "$user_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                local postman_user_dir="/home/${user_name}/Postman"
                print_message USER "Remove local user Postman files ${postman_user_dir}"
                wait_for user_continue
                if [[ -d "$postman_user_dir" ]]; then
                    run_command rm -rf "$postman_user_dir"
                else
                    print_message INFO "Postman user directory not found: ${postman_user_dir}"
                fi
            else
                print_message FAIL "Invalid user name detected, cannot safely remove user files"
            fi
            ;;
        11) clear
            validate_manifest_apps firefox chrome brave postman
            ;;
        12) clear
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
