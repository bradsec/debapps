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
        tmp_template_file="$(mktemp)"
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

function install_discord() {
	print_message INFO "Installing Discord..."
	local from_url="https://discord.com/api/download?platform=linux&format=deb"
	local save_file="/tmp/discord.deb"
	download_file "${save_file}" "${from_url}"
	pkgmgr install "${save_file}"
	pkgmgr fix
}

function install_zoom() {
	print_message INFO "Installing Zoom..."
	local from_url="https://zoom.us/client/latest/zoom_amd64.deb"
	local save_file="/tmp/zoom.deb"
	download_file "${save_file}" "${from_url}"
	pkgmgr install "${save_file}"
	pkgmgr fix
}

function install_slack() {
	print_message INFO "Installing Slack..."
	# Fetch latest Slack version
	print_message INFO "Fetching latest Slack .deb package..."
	local slack_version
	slack_version="$(curl -sL https://slack.com/downloads/linux | sed -n 's/.*<span class="page-downloads__hero__meta-text__version">Version \([^<]\+\)<\/span>.*/\1/p')"
	local from_url="https://downloads.slack-edge.com/releases/linux/${slack_version}/prod/x64/slack-desktop-${slack_version}-amd64.deb"
	local save_file="/tmp/slack.deb"
	download_file "${save_file}" "${from_url}"
	pkgmgr install "${save_file}"
	pkgmgr fix
}

# Display a list of menu items for selection
function display_menu () {
	echo
    echo -e " =============="                         
    echo -e "  Menu Options "
    echo -e " ==============\n"
    echo -e " 1. Install Discord"
	echo -e " 2. Install Slack"
	echo -e " 3. Install Zoom\n"
    echo -e " 4. Remove Discord"
    echo -e " 5. Remove Slack"
    echo -e " 6. Remove Zoom\n"
    echo -e " 7. Exit\n"
    echo -n "    Enter option [1-7]: "

    while :
    do
		read -r choice </dev/tty
		case "${choice}" in
		1)  clear
			pkgmgr remove discord
			install_discord
			;;
		2)  clear
			pkgmgr remove slack-desktop
			install_slack
			;;
		3)  clear
			pkgmgr remove zoom
			install_zoom
			;;
		4)  clear
			pkgmgr remove discord
			;;
		5)  clear
			pkgmgr remove slack-desktop
			;;
		6)  clear
			pkgmgr remove zoom
			;;
		7)  clear
			exit
			;;
		*)  clear
			print_message WARN "Invalid option. Please select 1-7."
			continue
            ;;
		esac
		pkgchk
		print_message DONE "\nSelection [${choice}] completed."
		wait_for user_anykey
		clear
		return
    done
}

# Main function
function main() {
    about
    display_menu
}

main "${@}"
