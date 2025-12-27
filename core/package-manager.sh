#!/usr/bin/env bash

# Package manager functions for Debian-based systems
# Refactored from src/templates/debian.tmpl.sh
# Requires: core/common.sh to be loaded first

set -euo pipefail

# Debian apt package management
# Usage: pkgmgr install curl wget | pkgmgr remove package | pkgmgr find package
pkgmgr() {
    local action="${1:-}"

    if [[ -z "$action" ]]; then
        print_message FAIL "pkgmgr requires an action (install/remove/purge/find/size/fix)"
        return 1
    fi

    shift

    for pkg in "$@"; do
        local snapinstalled=false
        local aptinstalled=false

        print_message TASK "Checking for package: ${pkg}..."

        # Check if snap package exists
        if command -v snap &>/dev/null; then
            if sudo snap list 2>/dev/null | grep -q "^${pkg} "; then
                print_message INFO "Found snap installation of package: ${pkg}"
                snapinstalled=true
            fi
        fi

        # Check if apt package exists (any installed state: ii, iU, iF, iH, etc.)
        if dpkg -l "${pkg}" 2>/dev/null | grep -q "^i"; then
            print_message INFO "Found apt installation of package: ${pkg}"
            aptinstalled=true
        fi

        if [[ ${snapinstalled} == false ]] && [[ ${aptinstalled} == false ]]; then
            print_message INFO "No installed snap or apt package for: ${pkg}"
        fi

        case "${action}" in
            install)
                if [[ ${snapinstalled} == false ]] && [[ ${aptinstalled} == false ]]; then
                    print_message INFO "Attempting to install ${pkg}..."

                    if [[ "${pkg}" == *.deb ]]; then
                        run_command_verbose sudo dpkg -i "${pkg}"
                    else
                        # Don't quote $pkg to allow multiple space-separated packages
                        run_command_verbose sudo apt-get -y install ${pkg}
                    fi

                    local command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message PASS "Successfully installed package: ${pkg}."
                    else
                        print_message FAIL "Failed to install package: ${pkg}."
                        return 1
                    fi
                else
                    print_message PASS "Package ${pkg} is already installed."
                    return 0
                fi
                ;;

            remove)
                if [[ ${snapinstalled} == true ]]; then
                    run_command sudo snap remove "${pkg}"
                    local command_result_code=$?

                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message PASS "Successfully removed snap package: ${pkg}."
                    else
                        print_message FAIL "Failed to remove snap package: ${pkg}."
                        return 1
                    fi

                elif [[ ${aptinstalled} == true ]]; then
                    # Check if package is in broken state (iU, iF, iH)
                    local pkg_state
                    pkg_state=$(dpkg -l "${pkg}" 2>/dev/null | grep "^i" | awk '{print $1}')

                    if [[ "$pkg_state" != "ii" ]]; then
                        print_message WARN "Package ${pkg} is in broken state: ${pkg_state}. Using dpkg --force-remove-reinstreq..."
                        run_command sudo dpkg --remove --force-remove-reinstreq "${pkg}"
                        command_result_code=$?

                        if [[ "${command_result_code}" -eq 0 ]]; then
                            print_message PASS "Successfully force-removed broken package: ${pkg}."
                        else
                            print_message FAIL "Failed to force-remove package: ${pkg}."
                            return 1
                        fi
                    else
                        run_command sudo apt-get -y remove "${pkg}"
                        local command_result_code=$?

                        if [[ "${command_result_code}" -eq 0 ]]; then
                            print_message PASS "Successfully removed package: ${pkg}."
                        else
                            print_message WARN "Failed to remove, attempting purge..."
                            run_command sudo apt-get -y purge "${pkg}"
                            command_result_code=$?

                            if [[ "${command_result_code}" -eq 0 ]]; then
                                print_message PASS "Successfully removed and purged package: ${pkg}."
                            else
                                print_message FAIL "Failed to remove package: ${pkg}."
                                return 1
                            fi
                        fi
                    fi
                else
                    print_message INFO "Package ${pkg} is not installed."
                fi
                ;;

            purge)
                if [[ ${aptinstalled} == true ]]; then
                    run_command sudo apt-get -y purge "${pkg}"
                    local command_result_code=$?

                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message PASS "Successfully purged package: ${pkg}."
                    else
                        print_message FAIL "Failed to purge package: ${pkg}."
                        return 1
                    fi
                else
                    print_message INFO "Package ${pkg} is not installed."
                fi
                ;;

            find)
                if apt-cache search --names-only "^${pkg}$" 2>/dev/null | grep -q "^${pkg} "; then
                    local pkg_match
                    pkg_match=$(dpkg --get-selections 2>/dev/null | grep "^${pkg}" | awk '{print $1}')
                    echo -n "${pkg_match}"
                fi
                ;;

            size)
                if apt-cache --no-all-versions show "${pkg}" 2>/dev/null | grep -q '^Size: '; then
                    local pkg_raw_size
                    pkg_raw_size=$(apt-cache --no-all-versions show "${pkg}" | grep '^Size: ' | awk '{print $2}')
                    local pkg_size
                    pkg_size="$(echo "${pkg_raw_size}" | numfmt --to=iec)"
                    print_message INFO "The installation size of package ${pkg} is ${pkg_size}."
                else
                    print_message WARN "Unable to determine size for package: ${pkg}"
                fi
                ;;

            fix)
                print_message INFO "Attempting to fix broken dependencies..."
                run_command_verbose sudo apt-get -y --fix-broken install
                ;;

            *)
                print_message FAIL "Invalid pkgmgr() action: ${action}"
                print_message INFO "Valid actions: install, remove, purge, find, size, fix"
                return 1
                ;;
        esac
    done
}

# Perform all package updates, upgrades, fixes and cleaning
pkgchk() {
    print_message INFO "Conducting Debian package updates, upgrades, fixes, and clean-up..."

    run_command sudo apt-get -y update || {
        print_message WARN "apt update failed, continuing anyway..."
    }

    # Fix any broken dependencies BEFORE attempting upgrade
    run_command_verbose sudo apt-get -y --fix-broken install

    run_command_verbose sudo apt-get -y upgrade

    run_command sudo apt-get -y autoclean

    run_command sudo apt-get -y autoremove
}

# Check if a systemd service is active
# Usage: is_active servicename
is_active() {
    local service="${1:-}"

    if [[ -z "$service" ]]; then
        print_message FAIL "is_active requires a service name"
        return 1
    fi

    if systemctl is-active "$service" &>/dev/null; then
        print_message INFO "The service for ${service} is active."
        return 0
    else
        print_message WARN "The service for ${service} is not active."
        return 1
    fi
}

# Add apt source with signing key to /etc/apt/sources.list.d/
# Usage: add_apt_source "repo_key_name" "repo_list_file.list" "https://repo.com stable main" ["custom_arch"]
add_apt_source() {
    local repo_key="${1:-}"
    local repo_list_file="${2:-}"
    local repo_source="${3:-}"
    local repo_arch="${4:-}"

    # Validate inputs
    if [[ -z "$repo_key" ]] || [[ -z "$repo_list_file" ]] || [[ -z "$repo_source" ]]; then
        print_message FAIL "add_apt_source requires: repo_key, repo_list_file, repo_source"
        return 1
    fi

    # If custom repo_arch is not set, get system arch using dpkg --print-architecture
    local os_arch
    if [[ -z "${repo_arch}" ]]; then
        os_arch="$(dpkg --print-architecture 2>/dev/null || echo "amd64")"
    else
        os_arch="${repo_arch}"
    fi

    print_message INFO "Adding repo apt source..."
    print_message INFO "SRC-FILE: /etc/apt/sources.list.d/${repo_list_file}"
    print_message INFO "SRC-TEXT: deb [arch=${os_arch} signed-by=/usr/share/keyrings/${repo_key}-keyring.gpg] ${repo_source}"

    echo "deb [arch=${os_arch} signed-by=/usr/share/keyrings/${repo_key}-keyring.gpg] ${repo_source}" \
        | sudo tee "/etc/apt/sources.list.d/${repo_list_file}" &>/dev/null

    if [[ $? -eq 0 ]]; then
        print_message PASS "Successfully added apt source."
    else
        print_message FAIL "Failed to add apt source."
        return 1
    fi
}

# Fetch repo signing key, determine if ascii-armored, write to /usr/share/keyrings/
# Usage: fetch_signing_key "new_key_name" "https://validkeyurl.com/keyname-pub.gpg"
fetch_signing_key() {
    local key_name="${1:-}"
    local key_src="${2:-}"

    # Validate inputs
    if [[ -z "$key_name" ]] || [[ -z "$key_src" ]]; then
        print_message FAIL "fetch_signing_key requires: key_name, key_src"
        return 1
    fi

    # Ensure gpg is installed
    if ! command -v gpg &>/dev/null; then
        pkgmgr install gpg
    fi

    # Create and secure gnupg directory
    sudo mkdir -p /root/.gnupg &>/dev/null
    sudo chmod -R 600 /root/.gnupg &>/dev/null

    # Check if key URL is accessible
    print_message TASK "Checking apt source signing key link available..."
    if wget -S --spider "${key_src}" 2>&1 | grep -q 'HTTP/1.1 200 OK'; then
        print_message PASS "Key URL is accessible."
    else
        print_message FAIL "There is a problem with the key source. Check URL link: ${key_src}"
        return 1
    fi

    print_message INFO "Fetching package signing key..."
    print_message INFO "SRC: ${key_src}"

    # Download key to temporary location
    local tmp_key="/tmp/${key_name}-$$.key"
    wget -qO "${tmp_key}" "${key_src}" || {
        print_message FAIL "Failed to download key from: ${key_src}"
        return 1
    }

    # If key is ascii-armored, use gpg --dearmor
    if file "${tmp_key}" 2>/dev/null | grep -q "Public-Key (old)"; then
        print_message INFO "Running gpg --dearmor and adding to keyrings..."
        print_message INFO "DEST: /usr/share/keyrings/${key_name}-keyring.gpg"
        sudo gpg --dearmor < "${tmp_key}" | sudo tee "/usr/share/keyrings/${key_name}-keyring.gpg" &>/dev/null
    else
        print_message INFO "No dearmor required. Adding to keyrings..."
        print_message INFO "DEST: /usr/share/keyrings/${key_name}-keyring.gpg"
        sudo cp "${tmp_key}" "/usr/share/keyrings/${key_name}-keyring.gpg" &>/dev/null
    fi

    # Cleanup
    rm -f "${tmp_key}" &>/dev/null

    print_message PASS "Successfully added signing key."
}

# Fetch repo signing key from keyserver
# Usage: fetch_keyserver_signing_key "customkeyname" "hkp://validkeyserver.com" "keyfingerprint"
fetch_keyserver_signing_key() {
    local key_name="${1:-}"
    local key_server="${2:-}"
    local key_fingerprint="${3:-}"

    # Validate inputs
    if [[ -z "$key_name" ]] || [[ -z "$key_server" ]] || [[ -z "$key_fingerprint" ]]; then
        print_message FAIL "fetch_keyserver_signing_key requires: key_name, key_server, key_fingerprint"
        return 1
    fi

    # Ensure gpg is installed
    if ! command -v gpg &>/dev/null; then
        pkgmgr install gpg
    fi

    # Create and secure gnupg directory
    sudo mkdir -p /root/.gnupg &>/dev/null
    sudo chmod -R 600 /root/.gnupg &>/dev/null

    print_message INFO "Fetching package signing key from keyserver..."
    print_message INFO "Server: ${key_server}"
    print_message INFO "Fingerprint: ${key_fingerprint}"

    sudo gpg --no-default-keyring --keyring "/usr/share/keyrings/${key_name}-keyring.gpg" \
        --keyserver "${key_server}" --recv-keys "${key_fingerprint}"

    if [[ $? -eq 0 ]]; then
        print_message PASS "Successfully fetched signing key from keyserver."
    else
        print_message FAIL "Failed to fetch signing key from keyserver."
        return 1
    fi
}
