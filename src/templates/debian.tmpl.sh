#!/usr/bin/env bash

# Functions/commands specific to Debian based systems.
# Requires: generic.sh template to be loaded first.

TEMPLATE_NAME="templates/debian.tmpl.sh"

# Debian apt package related functions
# Example usage: pkgmgr install curl wget htop nmap
function pkgmgr() {
	for pkg in "${@:2}"; do
        local snapinstalled=false
        local aptinstalled=false

        print_message TASK "Checking for package: ${pkg}..."
        if command -v snap >/dev/null 2>&1; then
            if sudo snap list | grep -q "^${pkg} "; then
                print_message INFO "Found snap installation of package: ${pkg}"
                snapinstalled=true
            fi
        fi

        if dpkg -s "${pkg}" >/dev/null 2>&1; then
            print_message INFO "Found apt installation of package: ${pkg}"
            aptinstalled=true
        fi

        if [[ ${snapinstalled} == false && ${aptinstalled} == false ]]; then
            print_message INFO "No installed snap or apt package for: ${pkg}"
        fi

        case ${1} in
            install)
                if [[ ${snapinstalled} == false && ${aptinstalled} == false ]]; then
                    print_message INFO "Attempting to install ${pkg}..."
                    if [[ "${pkg}" == *.deb ]]; then
                        run_command_verbose sudo dpkg -i "${pkg}"
                    else
                        run_command_verbose sudo apt -y install "${pkg}"
                    fi

                    command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message PASS "Successfully installed package: ${pkg}."
                    else
                        print_message FAIL "Failed to install package: ${pkg}."
                    fi

                fi
            ;;
            remove)
                if [[ ${snapinstalled} == true ]]; then
                    run_command sudo snap remove "${pkg}"
                    command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message PASS "Successfully removed snap package: ${pkg}."
                    else
                        print_message FAIL "Failed to remove snap package: ${pkg}."
                    fi
                elif [[ ${aptinstalled} == true ]]; then
                    run_command sudo apt -y remove "${pkg}"
                    command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message PASS "Successfully removed package: ${pkg}."
                    else
                        run_command sudo apt -y purge "${pkg}"
                        command_result_code=$?
                        if [[ "${command_result_code}" -eq 0 ]]; then
                            print_message PASS "Successfully removed and purged package: ${pkg}."
                        else
                            print_message FAIL "Failed to removed package: ${pkg}."
                        fi
                    fi
                fi
            ;;
            purge)
                if [[ ${aptinstalled} == true ]]; then
                    run_command sudo apt -y purge "${pkg}"
                    command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message FAIL "Failed to purge package: ${pkg}."
                    else
                        print_message PASS "Successfully removed package: ${pkg}."
                    fi
                fi
            ;;
            find)
                if [[ $(sudo apt-cache search --names-only "^${pkg}$" | wc -l) == "1" ]]; then
                    pkg_match=$(sudo dpkg --get-selections | grep "^${pkg}" | awk '{print $1}')
                    echo -ne ${pkg_match}
                fi
            ;;
            size)
                if [[ $(sudo apt-cache --no-all-versions show ${pkg} | grep '^Size: ' | wc -l) == "1" ]]; then
                    pkg_raw_size=$(sudo apt-cache --no-all-versions show ${pkg} | grep '^Size: ' | awk '{print $2}')
                    pkg_size="$(echo ${pkg_raw_size} | numfmt --to=iec)"
                    print_message INFO "The installation size of package ${pkg} is ${pkg_size}."
                fi
            ;;
            *) 
                print_message FAIL "Invalid pkgmgr() function usage."
            ;;
        esac
	done
}

# Function performs all package updates, upgrades, fixes and cleaning.
function pkgchk() {
    print_message INFOFULL "Updating, upgrading, fixing system packages..."
    run_command sudo apt -y update
    run_command_verbose sudo apt -y upgrade
    run_command sudo apt -y --fix-broken install
    run_command sudo apt -y autoclean
    run_command sudo apt -y autoremove
}

# Function to check if a service is active will return green tick or red cross.
function is_active() {
    if [[ $(systemctl is-active "$1") == "active" ]] &>/dev/null; then
        print_message INFO "The service for ${1} is active."
    else
        print_message WARN "The service for ${1} is not active."
    fi
}

# Add apt source with signing key to /etc/apt/source.list.d/${repo_name}.list
# Usage 1: add_apt_source "repo_key_name" "repo_list_file.list" "https://validsourceforepo.com stable main"
# Usage 2: add_apt_source "repo_key_name" "repo_list_file.list" "https://validsourceforepo.com stable main" "arm64"
function add_apt_source() {
	repo_key=${1}
	repo_list_file=${2}
	repo_source=${3}
    repo_arch=${4}
    # If custom repo_arch is not set get system arch using dpkg --print-architecture
    [[ -z "${repo_arch}" ]] && os_arch="$(dpkg --print-architecture)" || os_arch="${4}"
	print_message INFO "Adding repo apt source..."
    print_message INFO "SRC-FILE: /etc/apt/sources.list.d/${repo_list_file}"
    print_message INFO "SRC-TEXT: deb [arch=${os_arch} signed-by=/usr/share/keyrings/${repo_key}-keyring.gpg] ${repo_source}"
	echo "deb [arch=${os_arch} signed-by=/usr/share/keyrings/${repo_key}-keyring.gpg] ${repo_source}" \
	| sudo tee /etc/apt/sources.list.d/${repo_list_file} &>/dev/null
}

# Fetch repo signing key, determine if ascii-armored, write key to /usr/share/keyrings/${key_name}-archive-keyring.gpg
# Usage: fetch_signing_key  "new_key_name" "https://validkeyurl.com/keyname-pub.gpg"
function fetch_signing_key() {
    pkgmgr install gpg
	mkdir -p /root/.gnupg &>/dev/null
    chmod -R 600 /root/.gnupg &>/dev/null
	key_name=${1}
	key_src=${2}
    # Check if key exists
    print_message TASK "Checking apt source signing key link available..."
    if [[ $(wget -S --spider ${key_src} 2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
        print_message PASS
    else
        print_message FAIL
        print_message FAIL "There is a problem with the key source. Check URL link."
        exit 1
    fi
	print_message INFO "Fetching package signing key..."
    print_message INFO "SRC: ${key_src}"
	# Must be run without run_command or supressing output.
    wget -qO- ${key_src} > /tmp/${key_name}
	# If key is ascii-armored use gpg --deamor.
	if [[ $(file "/tmp/${key_name}") == *"Public-Key (old)"* ]] &>/dev/null; then
        print_message INFO "Running gpg --dearmor and adding to keyrings..."
        print_message INFO "DEST: /usr/share/keyrings/${key_name}-keyring.gpg"
		cat /tmp/${key_name} | gpg --dearmor | tee /usr/share/keyrings/${key_name}-keyring.gpg &>/dev/null
	else
        print_message INFO "No dearmor required. Adding to keyrings..."
        print_message INFO "DEST: /usr/share/keyrings/${key_name}-keyring.gpg"
		cp /tmp/${key_name} /usr/share/keyrings/${key_name}-keyring.gpg &>/dev/null
	fi
	rm /tmp/${key_name} &>/dev/null
}

# Fetch repo signing key from keyserver
# Usage: fetch_keyserver_signing_key "customkeyname" "hkp://validkeyserver.com" "keyfingerprint"
function fetch_keyserver_signing_key() {
	mkdir -p /root/.gnupg &>/dev/null
    chmod -R 600 /root/.gnupg &>/dev/null
	key_name=${1}
	key_server=${2}
	key_fingerprint=${3}
	print_message INFO "Fetching package signing key from keyserver..."
	gpg --no-default-keyring --keyring /usr/share/keyrings/${key_name}-keyring.gpg \
	--keyserver ${key_server} --recv-keys ${key_fingerprint}
}

print_message PASS "${TEMPLATE_NAME} imported."
