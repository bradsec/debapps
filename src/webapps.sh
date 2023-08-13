#!/usr/bin/env bash

SCRIPT_SOURCE="webapps.sh"
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

function install_firefox() {
	print_message INFOFULL "This will install the latest Firefox browser version."
	print_message WARN "This script will attempt to remove any existing installations of Firefox including Firefox ESR."
	print_message WARN "Existing Firefox settings and preferences will be lost."
	wait_for user_continue
    # Remove any previous firefox packages
    pkgmgr remove firefox-esr
    pkgmgr remove firefox
	# Add fix for missing XPCOM error libdbus-glib-1.so.2 cannot open shared object
	apt-get -y install libdbus-glib-1-2 || true
	# Download latest linux 64 version
	local from_url="https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US"
	local save_file="/tmp/firefox.tar.bz2"
	download_file ${save_file} ${from_url}
    # Extract files to /opt/
    run_command tar -xvf ${save_file} --directory /opt/
    run_command sudo ln -sf /opt/firefox/firefox /usr/sbin/firefox
    # Write desktop icon configuration file
	local firefox_config="[Desktop Entry]
	Name=Firefox
	Comment=Browse the World Wide Web
	GenericName=Web Browser
	X-GNOME-FullName=Firefox Web Browser
	Exec=/opt/firefox/firefox %u
	Terminal=false
	X-MultipleArgs=false
	Type=Application
	Icon=/opt/firefox/browser/chrome/icons/default/default48.png
	Categories=Network;WebBrowser;
	MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
	StartupWMClass=Firefox
	StartupNotify=true"
    write_config_file "${firefox_config}" "/usr/share/applications/firefox.desktop"
    run_command rm ${save_file}
	print_message DONE "Firefox installed."
}

function install_brave() {
	print_message INFOFULL "This will install the latest Brave browser version."
	print_message WARN "This script will attempt to remove any existing installations of Brave."
	print_message WARN "Existing Brave settings and preferences will be lost."
	wait_for user_continue
	# Check requirements
	pkgmgr install apt-transport-https curl
	# Fetch signing keys and add apt source
	fetch_signing_key "brave-browser-archive" "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
	add_apt_source "brave-browser-archive" "brave-browser.list" "https://brave-browser-apt-release.s3.brave.com/ stable main"
	# Update packages and install
	run_command sudo apt -y update
	pkgmgr install brave-browser
	print_message DONE "Brave installed."
}

function install_tor_browser(){
	print_message INFOFULL "This will install the latest Tor-Browser version."
	pkgmgr install curl
	tor_link="https://www.torproject.org$(curl -s https://www.torproject.org/download/ | \
	grep linux | sed -r 's/.*href="([^"]+).*/\1/g' | awk 'NR==1')"
	local from_url="${tor_link}"
	local save_file="/tmp/torbrowser.tar.xz"
	download_file ${save_file} ${from_url}
	run_command tar -xvJf ${save_file} --directory /opt/
	pkg_path="/opt/$(ls /opt/ | grep tor-browser)"
	run_command chown -R $(get_user):$(get_user) ${pkg_path}
	run_command chmod 755 ${pkg_path}/start-tor-browser.desktop
	run_command ln -sf ${pkg_path}/start-tor-browser.desktop /usr/sbin/tor-browser
	run_command cd ${pkg_path}
	su -c './start-tor-browser.desktop --register-app' $(logname) >/dev/null 2>&1
	print_message DONE "Tor-Browser installed."
}

function install_chrome() {
	print_message INFO "Installing Google Chrome..."
	pkgmgr remove google-chrome-stable
	from_url="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
	save_file="/tmp/chrome.deb"
	download_file ${save_file} ${from_url}
	pkgmgr install ${save_file}
	print_message DONE "Chrome installed."
}

function install_postman() {
	print_message INFO "Installing Postman..."
	# Download latest linux 64 version
	local from_url="https://dl.pstmn.io/download/latest/linux64"
	local save_file="/tmp/postman.tar.gz"
	download_file ${save_file} ${from_url}
    # Extract files to /opt/
    run_command tar -xvf ${save_file} --directory /opt/
    run_command sudo ln -sf /opt/Postman/Postman /usr/sbin/postman
    # Write desktop icon configuration file
	local postman_config="[Desktop Entry]
	Name=Postman
	Comment=Postman is an API platform for building and using APIs
	GenericName=Postman
	X-GNOME-FullName=Postman
	Exec=/opt/Postman/Postman %u
	Terminal=false
	X-MultipleArgs=false
	Type=Application
	Icon=/opt/Postman/app/resources/app/assets/icon.png
	Categories=Network;WebBrowser;
	StartupWMClass=Postman
	StartupNotify=true"
    write_config_file "${postman_config}" "/usr/share/applications/postman.desktop"
    run_command rm ${save_file}
	print_message DONE "Postman installed."
}


function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e "  1. Install Firefox"
	echo -e "  2. Install Google Chrome"
    echo -e "  3. Install Brave"
	echo -e "  4. Install TOR Browser"
	echo -e "  5. Install Postman API Tool\n"
    echo -e "  6. Remove Firefox"
	echo -e "  7. Remove Google Chrome"
    echo -e "  8. Remove Brave"
	echo -e "  9. Remove TOR Browser"
	echo -e " 10. Remove Postman API Tool\n"
    echo -e " 11. Exit\n"
    echo -n "     Enter option [1-11]: "

    while :
    do
        read choice </dev/tty
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
            remove_opt_app firefox
            ;;
        7)  clear
            pkgmgr remove google-chrome-stable
			run_command sudo apt -y update
			pkgmgr cleanup
            ;;
        8)  clear
            pkgmgr remove brave-browser
			run_command rm -f /etc/apt/sources.list.d/brave-browser*
			run_command sudo apt -y update
			pkgmgr cleanup
            ;;
		9)  clear
            remove_opt_app tor-browser
            ;;
		10)  clear
            remove_opt_app Postman
			message USER "Remove local user Postman files /$(get_user)/Postman"
			wait_for user_continue
			run_command rm -rf /$(get_user)/Postman
            ;;
        11) clear
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
